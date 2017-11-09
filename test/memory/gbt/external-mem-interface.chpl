extern {
  #include "chpl-mem.h"
  static int64_t* mymalloc(void) {
    int64_t *ret = (int64_t*) chpl_malloc(1024);
    ret[0] = 5;
    return ret;
  }
  static void myfree(int64_t *x) {
    chpl_free(x);
  }
}

// This is the external interface.
extern proc chpl_calloc(nmemb: size_t, size: size_t): c_void_ptr;
extern proc chpl_malloc(size: size_t): c_void_ptr;
extern proc chpl_realloc(ptr: c_void_ptr, size: size_t): c_void_ptr;
extern proc chpl_posix_memalign(ref ptr: c_void_ptr,
                                alignment: size_t, size: size_t): c_int;
extern proc chpl_free(ptr: c_void_ptr);
extern proc chpl_memalign(boundary: size_t, size: size_t): c_void_ptr;
extern proc chpl_valloc(size: size_t): c_void_ptr;
extern proc chpl_pvalloc(size: size_t): c_void_ptr;


config const nmemb: size_t = 10;
config const size: size_t = 20;
config const alignment: size_t = 2**6;
config const boundary: size_t = 2**7;

// calloc()
{
  var p = chpl_calloc(nmemb, size);
  if p == c_nil {
    writeln('calloc(): fail');
  } else {
    chpl_free(p);
  }
  writeln('calloc(): pass');
}

// malloc()
{
  var p = chpl_malloc(size);
  if p == c_nil {
    writeln('malloc(): fail');
  } else {
    chpl_free(p);
  }
  writeln('malloc(): pass');
}

// realloc()
{
  var p = chpl_malloc(size);
  if p == c_nil {
    writeln('realloc(): malloc() fail');
  } else {
    p = chpl_realloc(p, nmemb * size);
    if p == c_nil {
      writeln('realloc(): fail');
    } else {
      chpl_free(p);
    }
    writeln('realloc(): pass');
  }
}

// posix_memalign()
{
  var p: c_void_ptr;
  var err = chpl_posix_memalign(p, alignment, size);
  if p == c_nil {
    writeln('posix_memalign(): fail alloc');
  } else {
    var p_ui = p:c_uintptr;
    if (p_ui & (alignment - 1)) != 0 {
      writeln('posix_memalign(): fail alignment');
    }
    chpl_free(p);
  }
  writeln('posix_memalign(): pass');
}

// memalign()
{
  var p = chpl_memalign(boundary, size);
  if p == c_nil {
    writeln('memalign(): fail alloc');
  } else {
    var p_ui = p:c_uintptr;
    if (p_ui & (boundary - 1)) != 0 {
      writeln('memalign(): fail alignment');
    }
  }
  writeln('memalign(): pass');
}

// valloc()
{
  var p = chpl_valloc(size);
  if p == c_nil {
    writeln('valloc(): fail alloc');
  } else {
    var p_ui = p:c_uintptr;
    extern proc chpl_getHeapPageSize(): size_t;
    if (p_ui & (chpl_getHeapPageSize() - 1)) != 0 {
      writeln('valloc(): fail alignment');
    }
  }
  writeln('valloc(): pass');
}

// pvalloc()
{
  var p = chpl_pvalloc(size);
  if p == c_nil {
    writeln('pvalloc(): fail alloc');
  } else {
    var p_ui = p:c_uintptr;
    extern proc chpl_getHeapPageSize(): size_t;
    if (p_ui & (chpl_getHeapPageSize() - 1)) != 0 {
      writeln('pvalloc(): fail alignment');
    }
  }
  writeln('pvalloc(): pass');
}
