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

//
// Shared code for different mem implementations in mem-*/chpl_*_mem.c
//
#include "chplrt.h"

#include "chpl-mem.h"
#include "chpltypes.h"
#include "error.h"
#include "chplsys.h"

static int heapInitialized = 0;


void chpl_mem_init(void) {
  chpl_mem_layerInit();
  heapInitialized = 1;
}


void chpl_mem_exit(void) {
  chpl_mem_layerExit();
}


int chpl_mem_inited(void) {
  return heapInitialized;
}


void* chpl_memalign(size_t boundary, size_t size) {
  void* memptr;
  if (chpl_posix_memalign(&memptr,
                          (boundary < sizeof(void*)) ? sizeof(void*) : boundary,
                          size) == 0)
    return memptr;
  return NULL;
}

void* chpl_valloc(size_t size)
{
  void* memptr;
  if (chpl_posix_memalign(&memptr, chpl_getHeapPageSize(), size) == 0)
    return memptr;
  return NULL;
}

void* chpl_pvalloc(size_t size)
{
  size_t page_size = chpl_getHeapPageSize();
  size_t num_pages = (size + page_size - 1) / page_size;
  size_t rounded_up = num_pages * page_size; 
  void* memptr;
  if (chpl_posix_memalign(&memptr, chpl_getHeapPageSize(), rounded_up) == 0)
    return memptr;
  return NULL;
}
