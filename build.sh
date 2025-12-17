#!/bin/bash

# This script builds, runs, and cleans the project by invoking Make in each sub-directory.
#
# Usage:
#   ./build.sh        - Builds all targets.
#   ./build.sh run    - Builds all targets and then runs the FVP.
#   ./build.sh clean  - Cleans all build artifacts.

set -e # Exit immediately if a command exits with a non-zero status.

# --- CONFIGURATION ---
# List all project subdirectories to build.
# The LAST project in this list is passed last to the FVP, setting the entry point.
PROJECTS="app app_core1 boot"

# The base FVP command
FVP_BASE_CMD="FVP_BaseR_Cortex-R52 -I -p"

# --- SCRIPT LOGIC ---
ACTION=${1:-all}

# Function to build the FVP command line dynamically
build_fvp_command() {
    local cmd="$FVP_BASE_CMD"
    for proj in $PROJECTS; do
        cmd="$cmd --application ${proj}.elf"
    done
    echo "$cmd"
}

# --- Main Logic ---
if [ "$ACTION" = "run" ]; then
    echo "### Building all targets before running... ###"
    ./build.sh all
    echo
    echo "### Launching FVP... ###"
    FVP_COMMAND=$(build_fvp_command)
    echo "Executing: $FVP_COMMAND"
    eval $FVP_COMMAND

elif [ "$ACTION" = "clean" ]; then
    for proj in $PROJECTS; do
        if [ -f "$proj/Makefile" ]; then
            echo "--- Cleaning $proj ---"
            (cd "$proj" && make clean)
        fi
    done
    echo "--- Clean complete ---"

else # This handles 'all' or any other make target
    for proj in $PROJECTS; do
        if [ -f "$proj/Makefile" ]; then
            echo "--- Building $proj ---"
            (cd "$proj" && make $ACTION)
        fi
    done
    echo "--- Build complete ---"
fi