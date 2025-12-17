#!/bin/bash

# This script builds, runs, and cleans the project by invoking Make in each sub-directory.
#
# Usage:
#   ./build.sh        - Builds all targets.
#   ./build.sh run    - Builds all targets, then runs the FVP on a fixed port and connects a debugger.
#   ./build.sh clean  - Cleans all build artifacts.

set -e # Exit immediately if a command exits with a non-zero status.

# --- CONFIGURATION ---
# List all project subdirectories.
# The LAST project in this list is passed last to the FVP, setting the entry point.
PROJECTS="app app_core1 boot"
IRIS_PORT=7100

# The base FVP and debugger commands
FVP_BASE_CMD="FVP_BaseR_Cortex-R52 -I -p --iris-port $IRIS_PORT"
DBG_BASE_CMD='armdbg --cdb-entry "Arm FVP::BaseR_R52x2::Bare Metal Debug::Bare Metal Debug::Cortex-R52x2 SMP" --cdb-entry-param "connect_existing_model=true"'


# --- SCRIPT LOGIC ---
ACTION=${1:-all}

# Function to build the FVP's --application flags dynamically
build_app_flags() {
    local flags=""
    for proj in $PROJECTS; do
        flags="$flags --application ${proj}.elf"
    done
    echo "$flags"
}

# Function to get the name of the last ELF for the debugger --image flag
get_last_elf_name() {
    local last_proj=""
    for proj in $PROJECTS;
    do
        last_proj="$proj"
    done
    echo "${last_proj}.elf"
}

# --- Main Logic ---
if [ "$ACTION" = "run" ]; then
    echo "### Building all targets before running... ###"
    ./build.sh all
    echo

    APP_FLAGS=$(build_app_flags)
    LAST_ELF_NAME=$(get_last_elf_name)
    
    FVP_COMMAND="$FVP_BASE_CMD $APP_FLAGS"
    DBG_COMMAND="$DBG_BASE_CMD --image \"$LAST_ELF_NAME\""

    echo "### Launching FVP and Debugger... ###"
    FVP_LOG=$(mktemp /tmp/fvp_log.XXXXXX)
    echo "FVP log file: $FVP_LOG"

    # Set a trap to kill the entire FVP process group and the tail process on exit.
    # The '--' is important to signify that we are killing a negative PGID, not a signal number.
    # trap 'echo; echo "Shutting down background processes... FVP_PID: $FVP_PID and TAIL_PID: $TAIL_PID"; kill -- -$FVP_PID &> /dev/null; kill $TAIL_PID &> /dev/null; rm -f "$FVP_LOG"' EXIT
    trap 'echo; echo "Shutting down background processes... FVP_PID: $FVP_PID and TAIL_PID: $TAIL_PID"; kill $FVP_PID &> /dev/null; kill $TAIL_PID &> /dev/null; rm -f "$FVP_LOG"' EXIT

    echo "Starting FVP in background..."
    # Launch the FVP. The shell will assign it a new process group.
    eval $FVP_COMMAND > "$FVP_LOG" 2>&1 &
    FVP_PID=$! # Capture the PID, which is also the PGID for this job.
    echo "FVP started with PID $FVP_PID"

    echo "Waiting for FVP's Iris server on port $IRIS_PORT..."
    # Wait up to 10 seconds for the "listening to port" message from the FVP
    if ! timeout 10s grep -q "listening to port $IRIS_PORT" <(tail -f "$FVP_LOG" 2>/dev/null); then
        echo "ERROR: FVP failed to start or Iris server timed out."
        echo "--- FVP Log ---"
        cat "$FVP_LOG"
        exit 1
    fi
    
    # Start tailing the log file to show FVP printf output live
    tail -f "$FVP_LOG" &
    TAIL_PID=$! # Capture the PID of the tail process
    echo "FVP Iris server is up. Log tailing started with PID $TAIL_PID."

    echo "Starting debugger..."
    eval $DBG_COMMAND
    
    echo "Debugger session ended."

elif [ "$ACTION" = "clean" ]; then
    for proj in $PROJECTS; do
        if [ -f "$proj/Makefile" ]; then
            echo "--- Cleaning $proj ---"
            (cd "$proj" && make clean)
        fi
    done
    echo "--- Clean complete ---"

else # This handles 'all'
    for proj in $PROJECTS; do
        if [ -f "$proj/Makefile" ]; then
            echo "--- Building $proj ---"
            (cd "$proj" && make $ACTION)
        fi
    done
    echo "--- Build complete ---"
fi