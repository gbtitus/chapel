All
---
* moved strided bulk transfer from comm layers to shared, common code
  #11197
  #11206
* moved communication diagnostics from comm layers to shared, common code
  #11212
  #11976
  #12228
* added an Open Fabrics Interfaces libfabric-based 'ofi' communication layer
  (see https://chapel-lang.org/docs/1.19/platforms/libfabric.html)
  #11232
  #11297
  #11325
  #11337
  #11542
  #11548
  #11649
  #11715
  #11821
  #11841
  #11855
  #11881
  #11962
  #12049
  #12052
  #12098
  #12122
  #12229
  #12230
  #12255
  #12275
  #12335
  #12365
  #12384
  #12463
* improved comm=ugni fixed heap behavior near the registration limit
  (see https://chapel-lang.org/docs/1.19/platforms/cray.html)
  #11242
* added tasking layer interface queries for fixed-thread-count implementations
  #11290
* added message size to verbose communication diagnostics
  (see https://chapel-lang.org/docs/1.19/modules/standard/CommDiagnostics.html)
  #11041
* added support for urxvt terminal emulator with CHPL_COMM_USE_(G|LL)DB.
  (see https://chapel-lang.org/docs/1.19/usingchapel/debugging.html)
  #11048
* allowed specifying fixed heap size as a percentage of physical memory size
  (see https://chapel-lang.org/docs/1.19/platforms/cray.html)
  #11761
* restructured array memory allocation interfaces
  #11908
* reorganized test output to contain first all stdout, then all stderr
  #12236



Semantic Changes / Changes to Chapel Language
---------------------------------------------

New Features
------------

Feature Improvements
--------------------

Removed Features
----------------

Standard Modules / Library
--------------------------
* added message size to verbose communication diagnostics
  (see https://chapel-lang.org/docs/1.19/modules/standard/CommDiagnostics.html)

Package Modules
---------------

Standard Domain Maps (Layouts and Distributions)
------------------------------------------------

New Tools / Tool Changes
------------------------

Interoperability Improvements
-----------------------------

Performance Optimizations/Improvements
--------------------------------------

Cray-specific Performance Optimizations/Improvements
----------------------------------------------------

Memory Improvements
-------------------

Compiler Flags
--------------

Documentation
-------------

Example Codes
-------------

Portability
-----------
* added an Open Fabrics Interfaces libfabric-based 'ofi' communication layer
  (see https://chapel-lang.org/docs/1.19/platforms/libfabric.html)
* added support for urxvt terminal emulator with CHPL_COMM_USE_(G|LL)DB.
  (see https://chapel-lang.org/docs/1.19/usingchapel/debugging.html)

Cray-specific Changes
---------------------
* improved comm=ugni fixed heap behavior near the registration limit
  (see https://chapel-lang.org/docs/1.19/platforms/cray.html)
* allowed specifying fixed heap size as a percentage of physical memory size
  (see https://chapel-lang.org/docs/1.19/platforms/cray.html)

Error Messages / Semantic Checks
--------------------------------

Execution-time Checks
---------------------

Bug Fixes
---------

Compiler Performance
--------------------

Packaging / Configuration Changes
---------------------------------

Third-Party Software Changes
----------------------------

Testing System
--------------
* reorganized test output to contain first all stdout, then all stderr

Developer-oriented changes: Configuration changes
-------------------------------------------------

Developer-oriented changes: Module changes
------------------------------------------

Developer-oriented changes: Makefile improvements
-------------------------------------------------

Developer-oriented changes: Compiler Flags
------------------------------------------

Developer-oriented changes: Compiler improvements/changes
---------------------------------------------------------

Developer-oriented changes: Documentation improvements
------------------------------------------------------

Developer-oriented changes: Module improvements
-----------------------------------------------

Developer-oriented changes: Runtime improvements
------------------------------------------------
* moved strided bulk transfer from comm layers to shared, common code
* moved communication diagnostics from comm layers to shared, common code
* added tasking layer interface queries for fixed-thread-count implementations
* restructured array memory allocation interfaces

Developer-oriented changes: Testing System
------------------------------------------

Developer-oriented changes: Third-party improvements
----------------------------------------------------

Developer-oriented changes: Tool improvements
---------------------------------------------
