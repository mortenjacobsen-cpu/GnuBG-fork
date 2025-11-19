/* config_override.h
 * Force-disable multithreading for the Emscripten/web build.
 * This header will be injected via `-include web/config_override.h`
 * when calling `emcc` so that the autoconf-generated `config.h`
 * (which normally sets `USE_MULTITHREAD`) is immediately
 * undef'd for the compilation units we control.
 */

#include "config.h"

/* Undefine this so `#if defined(USE_MULTITHREAD)` becomes false. */
#ifdef USE_MULTITHREAD
#undef USE_MULTITHREAD
#endif

/* Also ensure single-thread fallback macros are sane. */
#ifndef MAX_NUMTHREADS
#define MAX_NUMTHREADS 1
#endif

/* End of config_override.h */
