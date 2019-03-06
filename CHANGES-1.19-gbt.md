Standard Modules / Library
--------------------------
* added message size to verbose communication diagnostics
  (see https://chapel-lang.org/docs/1.19/modules/standard/CommDiagnostics.html)

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

Testing System
--------------
* reorganized test output to contain first all stdout, then all stderr

Developer-oriented changes: Runtime improvements
------------------------------------------------
* moved strided bulk transfer from comm layers to shared, common code
* moved communication diagnostics from comm layers to shared, common code
* added tasking layer interface queries for fixed-thread-count implementations
* restructured array memory allocation interfaces
