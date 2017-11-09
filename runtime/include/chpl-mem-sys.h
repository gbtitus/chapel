/*
 * Copyright 2004-2017 Cray Inc.
 * Other additional copyright holders may be indicated within.
 *
 * The entirety of this work is licensed under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 *
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef _chpl_mem_sys_H_
#define _chpl_mem_sys_H_

#include <stdlib.h>

static inline void* sys_calloc(size_t n, size_t size) {
  return calloc(n, size);
}

static inline void* sys_malloc(size_t size) {
  return malloc(size);
}

static inline int sys_posix_memalign(void** memptr, size_t alignment,
                                     size_t size) {
  return posix_memalign(memptr, alignment, size);
}

static inline void* sys_realloc(void* ptr, size_t size) {
  return realloc(ptr, size);
}

static inline void sys_free(void* ptr) {
  free(ptr);
}

#endif
