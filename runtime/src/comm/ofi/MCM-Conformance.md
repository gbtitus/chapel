## MCM Conformance in CHPL_COMM=ofi

This document describes how the libfabric-based comm layer helps arrange
for programs to conform to the Chapel Memory Consistency Model (MCM).
The compiler and module code produce an inherently MCM-conforming
program, but the imperfect match between the Chapel and libfabric
communication models and the desire to limit communication overheads and
overlap communication and computation all cause potentially MCM-breaking
behavior.

The document introduces some libfabric terms and concepts and describes
how the Chapel communication primitives are implemented in terms of
libfabric operations.  It then quotes the *Program Order* and *Memory
Order* sections of the **Memory Consistency Model** chapter of the
Chapel spec, adding text as needed to describe what the implementation
does to meet the clauses in those sections.

**_Note:_** the comm layer currently does not yet intentionally try to
  conform to the MCM with respect to atomic operations when those are
  implemented natively, using RMA.  It only does so when they are
  implemented using Active Messages (AMs).  There is code to handle the
  native case, but it has not yet been tested on a network that can
  actually do atomics natively.  (So for example, the sockets provider's
  support for "native" atomics over TCP/IP sockets doesn't count).

### Background

The comm layer can use three different kinds of libfabric operations for
its various transactions.  It uses the RMA (READ/WRITE) interface for
direct transfers between local and remote memory.  It uses the atomics
interface for native atomic operations on networks that support those.
And, it uses the message (SEND/RECV) interface for Active Messages (AMs)
for executeOn transactions for on-statement bodies, memory transfers
between unregistered memory, atomic operations which cannot be done
natively, and several other things.

The comm layer has two libfabric tools it can use to determine when
operations are in some sense "done" and to impose order on them with
respect to other operations:

- _Completion levels_ adjust what effects of an operation must be
  visible before libfabric delivers an event indicating its completion
  to the initiator.

- _Message ordering_ settings specify how operations may or may not be
  reordered with respect to each other by libfabric, the provider, or
  the network fabric.  Note that "message" here is a generic term and
  refers to all kinds of operations, not just those of the SEND/RECV
  message interface.

#### Completion Levels

Libfabric's completion level specifies what state an operation has to
reach before an event is placed in the transmit endpoint's associated
completion queue to indicate that the operation is "done".  The comm
layer can use either the provider's default completion level, which is
usually *transmit-complete*, or the *delivery-complete* level.

**_Note (Bug):_** The comm layer assumes that the default completion
  level is always transmit-complete.  This is a bug, because a provider
  could certainly choose some other default.

Transmit-complete, for the reliable endpoints used by comm=ofi, means
that the operation has arrived at the peer and is no longer dependent on
the network fabric or local (initiator-side) resources.  It does not say
anything about the state of the operation at the target node.  In
particular, it does not say that any of the intended effects of the
operation, such as memory updates, are visible.

Delivery-complete extends this to say that effects are visible.  For
messages this means that the message data has been placed in the user
buffer at the target node, although it does not say that anything on the
target node has attended to the message.  For RMA it means that the
receiving data location, on the target node for PUTs and native
non-fetching atomics, or on the local node for GETs and native fetching
atomics, has been updated.

For operations that return data to the initiator, such as RMA GETs and
native fetching atomics, the default completion level is to treat the
initiator as a target also and not generate the completion event until
the received data has been placed in the local buffer.  Thus for RMA
GETs and native fetching atomics, the default completion mode is really
delivery-complete.

#### Message Ordering

Message ordering limits how operations can be reordered between when
they are initiated and when they are handled on the target node.  It
only applies to operations across a fixed pair of initiating and target
endpoints (or contexts).  Libfabric does not provide any way to control
ordering between operations across different transmit/receive endpoint
pairs.

The message ordering settings differentiate between operations for
messages, RMA, and native atomics.  The most important of these for
Chapel's purposes are the following.

- SAS (send-after-send) ordering specifies that messages (AMs) must be
  transmitted in the order they are submitted relative to other
  messages.

- Various kinds of RAW (read-after-write) orderings specify that RMA
  read and/or fetching native atomic operations must be transmitted in
  the order they are submitted relative to RMA write and/or non-fetching
  native atomic operations.

Message ordering is more or less useful to the comm layer depending on
the tasking implementation and whether or not a task is using a "fixed"
endpoint.  If the tasking implementation has a fixed number of threads
and doesn't switch tasks across threads, and the comm layer can
permanently bind a transmit endpoint to the task's thread, then message
ordering affects all operations done throughout the life of a task,
against a given target node.  (For safety, when built for debug the comm
layer can "trust but verify" that there is no task switching, checking
each time it yields that it does indeed come back on the same thread.)
If tasks can move from thread to thread, then libfabric message ordering
can only affect the operations done while the task is holding a specific
transmit endpoint, during which it is not allowed to yield.

#### Store Operations May "Dangle"

In some circumstances, the effects of libfabric operations may not be
visible until after the runtime's last opportunity to directly interact
with those operations.  The comm layer always requests send-after-send
message ordering, so that AMs are not reordered in transit.  Beyond
that, it either requests the delivery-complete completion level or
read-after-write message ordering.  With either or both of these,
however, there are some operation effects that may not be complete at
the time libfabric provides the last interaction with them.  Here we
refer to these not-yet-complete effects as _dangling stores_, since they
are basically remote memory stores whose visibility state isn't known.

##### Dangling Non-fetching Atomics

The comm layer uses the libfabric messaging (SEND/RECV) interface for
Active Messages (AMs).  It defines a number of AM types, but there are
only MCM implications for those that implement executeOn (on-statement
bodies), RMA on unregistered remote addresses, and atomic operations
when we're using a provider that can't do those natively.  AMs can
either be blocking, where the initiator waits for the target to send
back a "done" response before continuing, or nonblocking ("fire and
forget").  All effects of a blocking AM are visible before the target
sends back the "done" response.  AMs for unregistered RMA are always
blocking.  AMs for Chapel on-statements are blocking, with a few
exceptions for internal special cases that needn't concern us here.  AMs
for fetching atomic operations are blocking.  However, the effect on the
target datum of a non-fetching atomic operation done using a nonblocking
AM may not be visible before the initiator receives the libfabric
completion and continues executing.  Without delivery-complete the AM
message may not have been delivered, but even with delivery-complete it
may not have been acted upon by the AM handler on the target node,
because "delivery" just means that the AM request has been put in the
target node's AM request buffer, not that the handler there has done
anything with it.

Incomplete AM-mediated non-fetching atomic operations at a given remote
node by a given transmit endpoint can be forced to finish and be visible
by sending any kind of blocking AM from the endpoint to the node.  With
send-after-send ordering the no-op will arrive after the atomic.  Since
it's a blocking AM the initiator will not continue until after the AM
handler on that node has dealt with it and responded.  At that point,
since the atomic arrived before the later blocking AM, the atomic must
have been handled as well.

##### Dangling Regular Stores

The comm layer uses the libfabric RMA (READ/WRITE/ATOMIC) interface for
GETs, PUTs, and native atomics.  Various forms of read-after-write
message ordering are always used for RMA MCM conformance.  (This is
actually overkill, because really we only need to ensure that reading
from a specific address after writing to it produces the result that was
written, but libfabric doesn't supply a way to say that directly.)  If
we're not using delivery-complete then the comm layer may see the
completions for regular PUTs and non-fetching native atomics before
their effects are visible in target memory.  And, similar to the
AM-mediated case, even with delivery-complete, for non-fetching atomic
operations we may see the completion event before the target datum has
been updated.

To force regular PUTs or native non-fetching atomics to a given remote
node from a given endpoint to be visible we can do a GET from that node
on the endpoint.  With read-after-write ordering and delivery-complete
semantics for GETs, once the completion for the GET is seen all previous
RMA and atomic effects must be visible.

(Even with delivery-complete it might be nice to delay waiting for the
completions for regular PUTs until such time as we know the results
might be needed, such as before initiating an executeOn for an
on-statement to the target node(s).  This is work for the future,
however.)

In summary, no matter what completion level we use, when the originator
sees the libfabric completion from a non-fetching atomic operation (done
either natively or by AM), the effect of that atomic on the target datum
may not yet be visible.  If we use the lighter weight transmit-complete
level, when the originator sees the libfabric completion from a regular
PUT, the effect of that PUT may not yet be visible either.  We have to
take further steps to forces dangling stores to be visible.  These are
documented below.

### Program Order

Task creation and task waiting create a conceptual tree of program
statements.  The task bodies, task creation, and task wait operations
create a partial order _<<sub>p</sub>_ of program statements.  For the
purposes of this section, the statements in the body of each Chapel task
will be implemented in terms of *load*, *store*, and *atomic
operations*.

---

- If we have a program snippet without tasks, such as `X; Y;`, where
  _X_ and _Y_ are memory operations, then _X <<sub>p</sub> Y_.

---

- The program `X; begin{Y}; Z;` implies _X <<sub>p</sub> Y_.  However,
  there is no particular relationship between _Y_ and _Z_ in program
  order.

  #### Implementation Notes

  Currently the comm layer doesn't do anything when parent tasks create
  children, although if it had the opportunity to do so it could be
  beneficial to delay some actions until that point.  The runtime memory
  consistency interface contains a `chpl_rmem_consist_release()` function
  which is currently called at that point, among others, but only when
  remote caching is enabled.  This could be enabled for comm=ofi also

  ---

---

- The program `t = begin{Y}; waitFor(t); Z;` implies _Y <<sub>p</sub>
  Z_.

---

- _X <<sub>p</sub> Y_ and _Y <<sub>p</sub> Z_ imply _X <<sub>p</sub>
  Z_.

### Memory Order

The memory order _<<sub>m</sub>_ of SC atomic operations in a given
task respects program order as follows:

- If _A<sub>sc</sub>(a) <<sub>p</sub> A<sub>sc</sub>(b)_ then
  _A<sub>sc</sub>(a) <<sub>m</sub> A<sub>sc</sub>(b)_

#### Implementation Notes

##### AM-Mediated Atomics

Tasks that do not have fixed transmit endpoints use blocking AMs for
atomic operations, as do tasks with fixed transmit endpoints when they
are doing fetching atomics.  Blocking AMs are complete in all respects
before the initiator continues from them, and thus strictly ordered.

When tasks with fixed transmit endpoints do non-fetching atomics, the
use of send-after-send (`FI_ORDER_SAS`) message ordering means that
atomics targeting a given node are transmitted, received, and handled in
order.  The current implementation starts out doing these using blocking
AMs, but switches to non-blocking AMs after three non-fetching atomics
in a row.  These may result in dangling stores, which then have to be
forced into visibility using blocking no-op AMs if no other blocking AM
occurs before an executeOn AM is initiated, the task terminates, or an
RMA is requested.

**_Note (Bug 1):_** Currently if we have a sequence of non-fetching
  atomic operations with nothing else intervening we simply initiate
  them, one after another, without doing any synchronization.  With a
  bound transmit endpoint our use of send-after-send message ordering
  will maintain the required MCM ordering for those targeting the same
  remote node, but the effects of two such atomics targeting different
  nodes could become visible in either order.  To fix this, we need to
  arrange for atomic operation effects to be visible before we proceed
  with anything else.  This will actually simplify a number of other
  things significantly.

**_Note (Bug 2):_** Currently the implementation doesn't differentiate
  between atomics to the same node or different nodes.  Send-after-send
  message ordering only imposes order on AMs to a given node, because it
  operates on a transmit/receive endpoint pair.  Fixing **_Bug 1_** will
  render this problem moot.

**_Note (Bug 3):_** Currently we don't force outstanding non-fetching
  atomics to be visible before we create a child task.  Fixing **_Bug
  1_** will render this problem moot.

##### Native Atomics

**_Note:_** Native atomic operations are not yet tested.

Atomic operations implemented natively in libfabric are ordered either
by using `FI_DELIVERY_COMPLETE` completion semantics, or through some
form of message ordering.  But as in the case of AM-mediated atomics,
this will not be sufficient to assure MCM conformance for non-fetching
atomics, and we will need to take similar actions as we do there to
ensure timely visibility.

---

Every SC atomic operation gets its value from the last SC atomic
operation before it to the same address in the total order
_<<sub>m</sub>_:

- Value of _A<sub>sc</sub>(a)_ = Value of _max<sub><<sub>m</sub></sub>
  (A<sub>sc</sub>'(a)|A<sub>sc</sub>'(a) <<sub>m</sub>
  A<sub>sc</sub>(a))_

#### Implementation Notes

The actions taken for the immediately preceding clause above are
sufficient here also.  (The **_Bugs_** there apply here as well.)

---

For data-race-free programs, every load gets its value from the last
store before it to the same address in the total order _<<sub>m</sub>_:

- Value of _L(a)_ = Value of _max<sub><<sub>m</sub></sub> (S(a)|S(a)
  <<sub>m</sub> L(a)_ or _S(a) <<sub>p</sub> L(a))_

#### Implementation Notes

The requirement here is just that if an earlier regular store can
dangle, it must be forced into visibility before the later regular load
is initiated.  A store can only dangle if it is done natively (not via
AM) in the absence of delivery-complete.

The comm layer could only fail this clause if a store dangled, and a
subsequent load from the same address ended up reordered before it.  For
tasks fixed to a transmit endpoint, our use of read-after-write message
ordering means that later loads remain ordered after earlier stores.

This leaves several cases outstanding: tasks not bound to transmit
endpoints, stores in parent tasks followed by loads in subsequently
created child tasks, stores in tasks followed by loads in tasks that
waited for them to terminate, and stores followed by loads in
on-statement bodies.  Currently we handle all but the last of these by
the simple yet costly expedient of doing a same-node dummy RMA GET after
every RMA PUT.  Stores followed by loads in on-statements are dealt with
by asserting send-after-write message ordering.

**_Note (improvements):_** For the case in which the store and load span
  task creation or termination, with bound transmit endpoints we could
  delay the dummy GETs, if they're needed at all, and do them in the
  `chpl_rmem_consist_release()` or `chpl_comm_task_end()` function,
  respectively.  But if we did this we would also need to do dummy GETs
  before later atomics (see the clause below), and that might be costly.
  Basically, if we delay dummy GETs for anything we have to delay them
  for everything, because at the time we initiate the dangling PUT we
  don't know what will come next.

---

For data-race-free programs, loads and stores are ordered with SC
atomics.  That is, loads and stores for a given task are in total order
_<<sub>m</sub>_ respecting the following rules which preserve the order
of loads and stores relative to SC atomic operations:

- If _L(a) <<sub>p</sub> A<sub>sc</sub>(b)_ then _L(a) <<sub>m</sub>
  A<sub>sc</sub>(b)_

- If _S(a) <<sub>p</sub> A<sub>sc</sub>(b)_ then _S(a) <<sub>m</sub>
  A<sub>sc</sub>(b)_

- If _A<sub>sc</sub>(a) <<sub>p</sub> L(b)_ then _A<sub>sc</sub>(a)
  <<sub>m</sub> L(b)_

- If _A<sub>sc</sub>(a) <<sub>p</sub> S(b)_ then _A<sub>sc</sub>(a)
  <<sub>m</sub> S(b)_

#### Implementation Notes

This clause is similar to the previous ones, but in terms of the
implementation it has to do with visibility at the boundaries between
regular memory references and atomic ones or vice-versa.  And like the
others, it is dangling stores that we have to be concerned with.

If a regular stores can dangle they must be forced into visibility
before any later atomic is initiated.  As described previously, the
current implementation achieves this by doing a dummy regular GET
immediately after every regular PUT.

It's actually unclear if this can be improved upon.  Functionally, we
could certainly delay doing the dummy GET until right before the
following atomic operation was initiated, but effectively the atomic's
latency would then include that of the GET.  This might be a net loss in
terms of total time, compared to initiating the dummy GET while the PUT
was in flight.

Conversely, if an atomic store can dangle it must be forced into
visibility before any later RMA is initiated.  The current
implementation does this using blocking no-op AMs to all nodes that
might have dangling atomic stores before initiating the RMA.

---

For data-race-free programs, loads and stores preserve sequential
program behavior.  That is, loads and stores to the same address in a
given task are in the order _<<sub>m</sub>_ respecting the following rules
which preserve sequential program behavior:

- If _L(a) <<sub>p</sub> L'(a)_ then _L(a) <<sub>m</sub> L'(a)_

- If _L(a) <<sub>p</sub> S(a)_ then _L(a) <<sub>m</sub> S(a)_

- If _S(a) <<sub>p</sub> S'(a)_ then _S(a) <<sub>m</sub> S'(a)_

#### Implementation Notes

This imposes the same requirements on the implementation, and has the
same solution(s), as clause before last, above.

