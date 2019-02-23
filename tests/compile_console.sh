#!/bin/bash
set -euo pipefail

# Compile the auto-tests.
# In debug mode, with text runner.
# One optional additional parameter possible, like -dXXX.

castle-engine --mode=debug --compiler-option="$@" compile
