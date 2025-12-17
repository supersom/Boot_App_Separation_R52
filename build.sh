#!/bin/bash

# This script builds all components of the project.
# It can be run with 'clean' as an argument to clean all artifacts.

set -e # Exit immediately if a command exits with a non-zero status.

# The action is the first argument ('clean' or defaults to 'all')
ACTION=${1:-all}

echo "--- Building boot ---"
(cd boot && make $ACTION)

echo "--- Building app (core 0) ---"
(cd app && make $ACTION)

echo "--- Building app_core1 (core 1) ---"
(cd app_core1 && make $ACTION)

echo "--- Done ---"
