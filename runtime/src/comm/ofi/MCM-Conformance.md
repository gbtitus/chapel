## MCM Conformance in CHPL_COMM=ofi

This describes how the libfabric-based comm layer arranges to conform to
the Chapel Memory Consistency Model (MCM).  In outline form it follows
the structure of the *Program Order* and *Memory Order* sections of the
**Memory Consistency Model** chapter of the Chapel spec.

Caveat: the comm layer currently does not make any purposeful attempt to
conform to the MCM when atomic operations are done natively, using RMA.
It only does so when atomic operations are done using Active Messages
(AMs).

### Program Order

Task creation and task waiting create a conceptual tree of program
statements.  The task bodies, task creation, and task wait operations
create a partial order _<<sub>p</sub>_ of program statements.  For the
purposes of this section, the statements in the body of each Chapel task
will be implemented in terms of *load*, *store*, and *atomic
operations*.

-  If we have a program snippet without tasks, such as `X; Y;`, where
   _X_ and _Y_ are memory operations, then _X <<sub>p</sub> Y_.

-  The program `X; begin{Y}; Z;` implies _X <<sub>p</sub> Y_.
   However, there is no particular relationship between _Y_ and _Z_ in
   program order.

-  The program `t = begin{Y}; waitFor(t); Z;` implies _Y <<sub>p</sub>
   Z_.

-  _X <<sub>p</sub> Y_ and _Y <<sub>p</sub> Z_ imply _X <<sub>p</sub>
   Z_.

### Memory Order

The memory order _<<sub>m</sub>_ of SC atomic operations in a given
task respects program order as follows:

-  If _A<sub>sc</sub>(a) <<sub>p</sub> A<sub>sc</sub>(b)_ then _A<sub>sc</sub>(a) <<sub>m</sub> A<sub>sc</sub>(b)_

Every SC atomic operation gets its value from the last SC atomic
operation before it to the same address in the total order
_<<sub>m</sub>_:

-  Value of _A<sub>sc</sub>(a)_ = Value of
   _max<sub><<sub>m</sub></sub> (A<sub>sc</sub>'(a)|A<sub>sc</sub>'(a) <<sub>m</sub> A<sub>sc</sub>(a))_

For data-race-free programs, every load gets its value from the last
store before it to the same address in the total order _<<sub>m</sub>_:

-  Value of _L(a)_ = Value of _max<sub><<sub>m</sub></sub> (S(a)|S(a) <<sub>m</sub> L(a)_ or _S(a) <<sub>p</sub> L(a))_

For data-race-free programs, loads and stores are ordered with SC
atomics.  That is, loads and stores for a given task are in total order
_<<sub>m</sub>_ respecting the following rules which preserve the order
of loads and stores relative to SC atomic operations:

-  If _L(a) <<sub>p</sub> A<sub>sc</sub>(b)_ then _L(a) <<sub>m</sub> A<sub>sc</sub>(b)_

-  If _S(a) <<sub>p</sub> A<sub>sc</sub>(b)_ then _S(a) <<sub>m</sub> A<sub>sc</sub>(b)_

-  If _A<sub>sc</sub>(a) <<sub>p</sub> L(b)_ then _A<sub>sc</sub>(a) <<sub>m</sub> L(b)_

-  If _A<sub>sc</sub>(a) <<sub>p</sub> S(b)_ then _A<sub>sc</sub>(a) <<sub>m</sub> S(b)_

For data-race-free programs, loads and stores preserve sequential
program behavior.  That is, loads and stores to the same address in a
given task are in the order _<<sub>m</sub>_ respecting the following rules
which preserve sequential program behavior:

-  If _L(a) <<sub>p</sub> L'(a)_ then _L(a) <<sub>m</sub> L'(a)_

-  If _L(a) <<sub>p</sub> S(a)_ then _L(a) <<sub>m</sub> S(a)_

-  If _S(a) <<sub>p</sub> S'(a)_ then _S(a) <<sub>m</sub> S'(a)_
