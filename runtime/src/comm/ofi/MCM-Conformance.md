## MCM Conformance in CHPL_COMM=ofi

This document describes how the libfabric-based comm layer arranges for
programs to conform to the Chapel Memory Consistency Model (MCM).  It
introduces some libfabric terms and concepts and then quotes the
*Program Order* and *Memory Order* sections of the **Memory Consistency
Model** chapter of the Chapel spec, adding text as needed to describe
what the implementation does to meet the clauses in those sections.

*Note*: the comm layer currently does not yet make a purposeful attempt
to conform to the MCM with respect to atomic operations when those are
implemented natively, using RMA.  It only does so when atomic operations
are implemented using Active Messages (AMs).

### Background

The comm layer can use three different kinds of libfabric operations for
its various transactions.  It uses the RMA (READ/WRITE) interface for
direct transfers between local and remote memory.  It uses the atomics
interface for native atomic operations on networks that support those.
And, it uses the message (SEND/RECV) interface for Active Messages (AMs)
for executeOn transactions for on-stmt bodies, memory transfers between
unregistered memory, atomic operations which cannot be done natively,
and several other things.

The comm layer has two libfabric tools it can use to determine when
operations are in some sense "done" and to impose order on them with
respect to other operations:

- completion levels adjust what effects of operations must be visible
  before libfabric delivers an event indicating operation completion to
  the initiator, and

- message ordering settings specify how operations may or may not be
  reordered with respect to each other by libfabric, the provider, or
  the network fabric.  Note that "message" here is a generic term and
  refers not only to the libfabric message interface but also the RMA
  and atomics interfaces.

##### Completion Levels

Libfabric's completion level specifies what state an operation has to
reach before an event is placed in the transmit endpoint's associated
completion queue to indicate that the operation is "done".  The comm
layer can use either the provider's default completion level, which is
usually *transmit-complete*, or the *delivery-complete* level.

*Developer note: The comm layer assumes that the default completion
level is always transmit-complete.  This is a bug which needs to be
fixed, because a provider could certainly choose some other default.*

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
non-fetching atomics and on the local node for GETs and native fetching
atomics, has been updated.

For operations that return data to the initiator, such as RMA GETs and
native fetching atomics, the default completion level is to treat the
initiator as a target also and not generate the completion event until
the received data has been placed in the local buffer.  Thus for RMA
GETs and native fetching atomics, the default completion mode is really
delivery-complete.

##### Message Ordering

Message ordering limits how operations can be reordered between when
they are initiated and when they are handled on the target node.  It
only applies within a given pair of initiating and target endpoints (or
contexts).  Libfabric does not provide any way to control ordering
between operations on different endpoint pairs.

The message ordering settings differentiate between operations for
messages, RMA, and native atomics.  The most important message ordering
settings for Chapel's purposes are:

- send-after-send (SAS), which specifies that messages (AMs) must be
  transmitted in the order they are submitted relative to other
  messages, and

- read-after-write (RAW), which specifies that RMA read and/or fetching
  native atomic operations must be transmitted in the order they are
  submitted relative to RMA write and/or non-fetching native atomic
  operations.

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
Can only affect the operations done while the task is holding a specific
transmit endpoint, during which it is not allowed to yield.

I WAS HERE
Next, see if I like the header sizes.

##### Store Operations May "Dangle"

The compiler and module code do what is necessary for programs to
conform to the MCM at the Chapel level.  This document discusses what
the runtime comm layer does to avoid breaking that conformance despite
using libfabric operations whose effects may not be visible until
after the runtime's last opportunity to directly interact with them.

The comm layer always requests send-after-send operation ordering, so
that AMs are not reordered in transit.  Beyond that, it either requests
the delivery-complete completion level or read-after-write operation
ordering.  This avoids many of the ways that operations can end up
incomplete even after libfabric last interaction with them, but not
all.

The comm layer uses the libfabric messaging (SEND/RECV) interface for
Active Messages (AMs).  It defines a number of AM types, but there are
only MCM implications for those that implement executeOn (on-statement
bodies), RMA on unregistered remote addresses, and atomic operations
when we're using a provider that can't do those natively.  AMs can
either be blocking ones, where the initiator waits for the target to
send back a "done" response before continuing, or nonblocking ones
("fire and forget").  All the effects of a blocking AM are visible
before a task continues after initiating one.  RMA AMs are always
blocking.  AMs for Chapel on-statements are blocking, with a few
exceptions for internal special cases.  AMs for fetching atomic
operations are blocking.  The only AMs where the initiator can continue
despite that the result may not yet be visible are nonblocking ones for
non-fetching atomics.  This is true even with delivery-complete
completions, because "delivery" just means that the AM request has been
put in the AM request buffer at the target node, not that the AM handler
there has dealt with it.

The comm layer uses the libfabric RMA (READ/WRITE/ATOMIC) interface for
GETs, PUTs, and native atomics.  (Note that even if the provider can
support atomics natively, if the network cannot do so we typically won't
use that capability because the provider won't advertise it.)  Various
forms of read-after-write operation ordering are always used for RMA
MCM conformance.  Arguably this is overkill, however, because really we
only need to ensure that reading the same address after writing to it
produces the result that was written, but libfabric doesn't supply a way
to say that directly.

If we're not using delivery-complete then the comm layer may see the
completions for regular PUTs before their effects are visible in target
memory.  But even with delivery-complete it might be nice to delay
waiting for the completions for regular PUTs until such time as we know
the results might be needed, such as before initiating an executeOn for
an on-stmt to the target node(s).  This is work for the future, however.

In summary, no matter what completion level we use, when the originator
sees the libfabric completion from a non-fetching atomic operation (done
either natively or by AM), the effect of that atomic on the target datum
may not yet be visible.  Further, if we use the transmit-complete level,
when the originator sees the libfabric completion from a regular PUT,
the effect of that PUT may not yet be visible either.  These stores that
are not yet visible are referred to as _dangling_.

##### Forcing Dangling Stores to Be Visible

Our use of send-after-send and read-after-write operation orderings,
along with the fact that the default completion for a operation with
load semantics (regular GET or fetching atomic) is delivery-complete,
gives us the tools to force visibility when we need it.  To force
regular PUTs or native non-fetching atomics on a given endpoint to be
visible we can do a GET on the same endpoint.  When the completion of
the GET is reported, all previous RMA and atomic effects must be
visible.  Similarly, to force AM-mediated non-fetching atomic operations
on an endpoint to be visible we can do a blocking no-op AM to the same
endpoint.  When the 'done' indicator comes back we know that the AM
handler on the target node has performed not only that no-op AM but
also all AMs that were sent before it.

There are four cases in which MCM conformance requires forcing dangling
stores to be visible:

1. **The effects of all prior stores done by a task must be visible
   before any child task it creates starts running.**

   For regular stores this is only an issue with transmit-complete.  We
   currently achieve this by doing a regular GET after every PUT.  If
   tasks are bound to transmit endpoints we could instead record which
   target nodes we've done PUTs to and wait to do the GETs until just
   before the child task(s) is/are created.  We already have a hook for
   this via the `chpl_rmem_consist_*()` functions, but the compiler
   currently only adds calls to those only with remote caching enabled.

   For non-fetching atomic operations this is an issue independent of
   the completion level, as discussed.  With unbound endpoints we handle
   this by doing blocking AMs.  With bound endpoints we start out doing
   blocking AMs, but then switch to nonblocking AMs and record the
   target nodes.  We then do blocking no-op AMs to the affected nodes to
   force visibility later, but this support is believed to be incomplete
   at present.  In particular, while we force atomic visibility before
   on-stmts, we don't force it before local task creations.  This would
   benefit from support through `chpl_rmem_consist_*()`, similar to the
   regular PUT case.

   The remaining three cases generraly have the same form.  The only
   thing that differs among them is the point in comm layer processing
   at which the visibility action needs to be taken.

2. **The effects of all prior stores done by a task must be visible
   before that task ends.**

   The compiler inserts a call to `chpl_comm_task_end()` at the end of
   every task, just before the task decrements its `endCount`.  This
   case is handle there.

3. **When a sequence of regular PUTs is followed by a non-fetching
   atomic operation, the effects of all those PUTs must be visible
   before the effect of the atomic operation is visible.**

   This case is handled in the comm layer functions that initiate atomic
   operations.

4. **When a non-fetching atomic operation is followed by a regular RMA,
   the effect of the atomic operation must be visible before the RMA is
   initiated.**

   This case is handled in the comm layer functions that initiate RMA.

### Program Order

Task creation and task waiting create a conceptual tree of program
statements.  The task bodies, task creation, and task wait operations
create a partial order _<<sub>p</sub>_ of program statements.  For the
purposes of this section, the statements in the body of each Chapel task
will be implemented in terms of *load*, *store*, and *atomic
operations*.

- If we have a program snippet without tasks, such as `X; Y;`, where
  _X_ and _Y_ are memory operations, then _X <<sub>p</sub> Y_.

- The program `X; begin{Y}; Z;` implies _X <<sub>p</sub> Y_.  However,
  there is no particular relationship between _Y_ and _Z_ in program
  order.

- The program `t = begin{Y}; waitFor(t); Z;` implies _Y <<sub>p</sub>
  Z_.

- _X <<sub>p</sub> Y_ and _Y <<sub>p</sub> Z_ imply _X <<sub>p</sub>
  Z_.

### Memory Order

The memory order _<<sub>m</sub>_ of SC atomic operations in a given
task respects program order as follows:

- If _A<sub>sc</sub>(a) <<sub>p</sub> A<sub>sc</sub>(b)_ then
  _A<sub>sc</sub>(a) <<sub>m</sub> A<sub>sc</sub>(b)_

#### Implementation

`FI_ORDER_SAS` (send-after-send) is always asserted.  This ensures that
atomic operations implemented via AMs are transmitted in program order
within a task.  And because those are "fast" AMs which are executed
directly by the handled and each receiving node only runs a single AM
handler, if they arrive in program order they must be executed in
program order as well.

Program order involves not only intra-task execution but also task
creation and termination.  Any atomic operations done by a parent task
before it creates a child task must be visible in that child, and any
atomic operations done by a task must be visible in any other task which
has waited for that task to terminate.  For fetching atomic operations
this visibility automatic; since we don't return from the comm layer
until the result comes back to the initiating node, the target datum
surely must have been updated before the initiating task creates any
other task or terminates.

For non-fetching atomic operations the situation is more complicated.
Here we don't have to wait for a result and so would prefer to use
non-blocking AMs because they are quicker.  Operation ordering ensures
MCM conformance within a single task, but guaranteeing visibility means
we have to make sure those AMs are complete before parent tasks create
child tasks (including for on-statements) and before tasks terminate.
To achieve this, just before initiating AMs for on-statements and just
before tasks terminate we do an AM-mediated "fence": we send "fast"
blocking no-op AMs to every node we've targeted with a non-fetching
atomic operation AM since the last blocking AM to that same node.  With
send-after-send ordering and a single AM handler at each node, once we
see the response from that no-op AM we know all prior atomic operation
AMs must also be done.

We could choose to do any atomic operation AMs as either blocking or
non-blocking.  The latter are quicker but may require a following AM
"fence" to guarantee visibility.  It turns out that they are enough
quicker it's worth using them even if the task doesn't do very many
non-fetching atomic AMs between task creations or before terminating.
And of course nearly all tasks do at least one atomic operation, for the
`_downEndCount()` when they end.  In the current implementation after
each AM "fence" we do the next 3 non-fetching atomics with blocking AMs
and then switch to nonblocking ones after that.

Note that there is one potential hole here.  We currently only do the AM
"fence" described above before initiating `executeOn` AMs for
on-statements and before terminating a task.  We don't do it before
creating local tasks.  One can imagine a task initiating a non-fetching
atomic operation _A<sub>sc</sub>(a)_ using a nonblocking AM, then
starting a local child task, and the child task doing an atomic
operation _A<sub>sc</sub>'(a)_ through a different libfabric endpoint
pair.  Operation ordering only applies within an endpoint pair, not
across them.  It would then be possible for _A<sub>sc</sub>'(a)_ to
operate upon _a_ before _A<sub>sc</sub>(a)_ did rather than after it.
As far as we know this has never happened, but there isn't any code to
explicitly prevent it.  This needs to be fixed.

***I WAS HERE***

Atomic operations implemented natively in libfabric are ordered either
by using `FI_DELIVERY_COMPLETE` completion semantics, or by asserting
`FI_ORDER_ATOMIC_WAR` (write-after-read for atomics) and
`FI_ORDER_ATOMIC_WAW` (write-after-write for atomics).  We probably need
`FI_ORDER_ATOMIC_RAW` also, but we don't assert that yet.  Note that
***native atomic operations are not yet tested***.

---

Every SC atomic operation gets its value from the last SC atomic
operation before it to the same address in the total order
_<<sub>m</sub>_:

- Value of _A<sub>sc</sub>(a)_ = Value of _max<sub><<sub>m</sub></sub>
  (A<sub>sc</sub>'(a)|A<sub>sc</sub>'(a) <<sub>m</sub>
  A<sub>sc</sub>(a))_

#### Implementation

***Content needed here.***

---

For data-race-free programs, every load gets its value from the last
store before it to the same address in the total order _<<sub>m</sub>_:

- Value of _L(a)_ = Value of _max<sub><<sub>m</sub></sub> (S(a)|S(a)
  <<sub>m</sub> L(a)_ or _S(a) <<sub>p</sub> L(a))_

#### Implementation

***Content needed here.***

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

#### Implementation

***Content needed here.***

---

For data-race-free programs, loads and stores preserve sequential
program behavior.  That is, loads and stores to the same address in a
given task are in the order _<<sub>m</sub>_ respecting the following rules
which preserve sequential program behavior:

- If _L(a) <<sub>p</sub> L'(a)_ then _L(a) <<sub>m</sub> L'(a)_

- If _L(a) <<sub>p</sub> S(a)_ then _L(a) <<sub>m</sub> S(a)_

- If _S(a) <<sub>p</sub> S'(a)_ then _S(a) <<sub>m</sub> S'(a)_

#### Implementation

***Content needed here.***
