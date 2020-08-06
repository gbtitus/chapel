## MCM Conformance in CHPL_COMM=ofi

This describes how the libfabric-based comm layer arranges to conform to
the Chapel Memory Consistency Model (MCM).  It quotes the *Program
Order* and *Memory Order* sections of the **Memory Consistency Model**
chapter of the Chapel spec, and after each clause in the *Memory Order*
section, add text describing what the implementation does to meet that
clause.

Caveat: the comm layer currently does not yet make a purposeful attempt
to conform to the MCM when atomic operations are done natively, using
RMA.  It only does so when atomic operations are implemented using
Active Messages (AMs).

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

For nonfetching atomic operations the situation is more complicated.
Here we don't have to wait for a result and so would prefer to use
non-blocking AMs because they are quicker.  Transaction ordering ensures
MCM conformance within a single task, but guaranteeing visibility means
we have to make sure those AMs are complete before parent tasks create
child tasks (including for on-statements) and before tasks terminate.
To achieve this, just before initiating AMs for on-statements and just
before tasks terminate we do an AM-mediated "fence": we send "fast"
blocking no-op AMs to every node we've targeted with a nonfetching
atomic operation AM since the last blocking AM to that same node.  With
send-after-send ordering and a single AM handler at each node, once we
see the response from that no-op AM we know all prior atomic operation
AMs must also be done.

We could choose to do any remote atomic operation AMs as either blocking
or non-blocking.  The latter are quicker but may require a following AM
"fence" to guarantee visibility.  It turns out that they are enough
quicker it's worth using them even if the task doesn't do very many
nonfetching AMO AMs between task creations or before terminating.  And
of course nearly all tasks do at least one atomic operation, for the
`_downEndCount()` when they end.  In the current implementation after
each AM "fence" we do the next 3 nonfetching AMOs with blocking AMs and
then switch to nonblocking ones after that.

Note that there is one potential hole here.  We currently only do the AM
"fence" described above before initiating `executeOn` AMs for
on-statements and before terminating a task.  We don't do it before
creating local tasks.  One can imagine a task initiating a nonfetching
atomic operation _A<sub>sc</sub>(a)_ using a nonblocking AM, then
starting a local child task, and the child task doing an atomic
operation _A<sub>sc</sub>'(a)_ through a different libfabric endpoint
pair.  Transaction ordering only applies within an endpoint pair, not
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
