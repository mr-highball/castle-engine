#!/bin/bash
set -eu

# Call this script from this directory,
# or from base castle_game_engine directory.
# Or just do "make examples" in base castle_game_engine directory.

# Allow calling this script from it's dir.
if [ -f code/castle-engine.lpr ]; then cd ../../; fi

fpc -dRELEASE @castle-fpc.cfg \
  -Futools/build-tool/embedded_images/ \
  tools/build-tool/code/castle-engine.lpr

# move binaries up
if [ -f tools/build-tool/code/castle-engine.exe ]; then
  mv -f tools/build-tool/code/castle-engine.exe tools/build-tool/
fi
if [ -f tools/build-tool/code/castle-engine ]; then
  mv -f tools/build-tool/code/castle-engine tools/build-tool/
fi
