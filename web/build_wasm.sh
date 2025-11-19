#!/usr/bin/env bash
# Build script for Emscripten -> WebAssembly module of the GNUBG evaluation core.
# Adjust EMCC if your emsdk installs it elsewhere (e.g. /opt/emsdk/upstream/emscripten/emcc).
# This script expects the weights file to be provided at runtime (we pass paths to init_engine).

set -euo pipefail

EMCC=${EMCC:-emcc}
OUT_DIR=web
OUT_JS=${OUT_DIR}/gnubg_engine.js
OUT_WASM=${OUT_DIR}/gnubg_engine.wasm

# Minimal source list for the evaluation core (first-pass). Exclude SIMD SSE file.
SOURCES=( \
  web/web_bridge.c \
  web/stubs.c \
  web/glib_stubs.c \
  eval.c \
  positionid.c \
  web/neuralnet_stub.c \
  lib/cache.c \
  lib/SFMT.c \
)

# Include paths
INCLUDES=( -I. -Ilib -Iweb )

# Use config override to disable multithreading for Wasm
INCLUDES+=( -include web/config_override.h )
INCLUDES+=( -include web/glib.h )

# Emscripten flags: optimize and allow memory growth
EMFLAGS=( -O3 -s WASM=1 -s ALLOW_MEMORY_GROWTH=1 -s MODULARIZE=1 -s EXPORT_ES6=0 )

# Exported functions: init_engine, get_best_move, and ensure _free is available
EXPORTED=( -s EXPORTED_FUNCTIONS="['_init_engine','_get_best_move','_malloc','_free']" )

# Runtime methods needed by the TypeScript worker (UTF8ToString, cwrap, getValue)
EXTRA=( -s EXPORTED_RUNTIME_METHODS='["cwrap","UTF8ToString","getValue"]' )

# Preload any data files if desired (example: preload a weights file into the filesystem)
# --preload-file path_on_host@/path/in/wasmfs
if [ -f pkgdata/gnubg.weights ]; then
  PRELOAD=( --preload-file pkgdata/gnubg.weights@/gnubg.weights )
else
  PRELOAD=()
fi

mkdir -p ${OUT_DIR}

echo "Compiling sources: ${SOURCES[*]}"

"${EMCC}" "${INCLUDES[@]}" "${SOURCES[@]}" "${EMFLAGS[@]}" "${EXPORTED[@]}" "${EXTRA[@]}" "${PRELOAD[@]}" -o "${OUT_JS}"

echo
echo "WASM build finished: ${OUT_JS} (and ${OUT_WASM})"

echo "Usage notes:"
echo "  - In JS, load the generated ${OUT_JS} module and call Module.cwrap('init_engine','void',['string','string'])"
echo "    to initialize the engine, e.g. Module.cwrap('init_engine','void',['string','string'])('/gnubg.weights', NULL)"
echo "  - Then call the wrapped get_best_move function via ccall/cwrap. get_best_move currently returns a malloc'd char*;"
echo "    you should cwrap it and then copy and free the C string with Module._free()."

# End of script
