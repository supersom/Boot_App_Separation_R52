# Example: Boot loader - Application Separation

Bare‑metal Cortex‑R52 example that boots a small assembly loader and hands off to two independent ELFs (core0 and core1) on Arm’s BaseR FVP. Scripts are provided to build, run, and debug via the Iris server and armdbg.

## Layout
- `boot/` – assembly bootloader linked at `0x00000000`; drops from EL2 to EL1, sets stack, and jumps into the app images.
- `app/` – core0 payload linked at `0x00020000`; simple “alive” loop.
- `app_core1/` – core1 payload linked at `0x00040000`; simple “alive” loop.
- `shared/` – MPU setup and shared boot args definitions.
- `build.sh` – orchestrates building, running the FVP, and attaching armdbg.

## Prerequisites
- Arm Compiler 6 tools in `PATH` (`armclang`, `armlink`).
- Arm FVP: `FVP_BaseR_Cortex-R52`.
- Arm Debugger CLI: `armdbg` (for optional debug).

## Build
```bash
./build.sh          # builds boot, app, and app_core1
./build.sh clean    # removes objects, maps, ELFs
```
Each subdir also has its own `Makefile` if you want to build individually.

## Run on FVP
Default config runs two cores and Iris on port 7100 (see `NUM_CORES`/`IRIS_PORT` in `build.sh`):
```bash
./build.sh run          # build, start FVP in background, tail log, launch armdbg (if installed)
./build.sh run fvp      # build then run only the FVP in the foreground
./build.sh run debug    # attach armdbg to an already-running FVP
```
The script passes all ELFs to the model; the last one (`boot.elf`) is the entry point.

## Memory / stack notes
- Boot ROM/scatter: `boot.scat`, entry `_start` at `0x0`, stack top `0x20008000`.
- Core0 app scatter: `app.scat`, vectors at `0x00020000`, stack top `0x20018000`.
- Core1 app scatter: `app_core1.scat`, vectors at `0x00040000`, stack top `0x20028000`.
- Secondary cores share `Image$$ARM_LIB_STACK$$Base` and offset their SP by `core_id * 0x1000` in `boot.S`. But for this example, non-core1 secondary cores are held in WFI
