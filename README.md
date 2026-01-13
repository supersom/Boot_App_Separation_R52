# Example: Boot loader - Application Separation

Bare‑metal Cortex‑R52 example that boots a minimal assembly loader and hands off to four independent ELFs (core0, core1, core10, core11) on Arm’s BaseR FVP. Scripts are provided to build, run, and debug via the Iris server and armdbg.

## Layout
- `boot/` – minimal assembly dispatcher linked at `0x00000000`; jumps into each core’s app bootloader.
- `app/` – core0 payload linked at `0x00020000`; simple “alive” loop.
- `app_core1/` – core1 payload linked at `0x00040000`; simple “alive” loop.
- `app_core10/` – core10 payload (core id 2) linked at `0x00060000`; simple “alive” loop.
- `app_core11/` – core11 payload (core id 3) linked at `0x00080000`; simple “alive” loop.
- `shared/` – MPU setup and shared boot args definitions.
- `build.sh` – orchestrates building, running the FVP, and attaching armdbg.

## Prerequisites
- Arm Compiler 6 tools in `PATH` (`armclang`, `armlink`).
- Arm FVP: `FVP_BaseR_Cortex-R52`.
- Arm Debugger CLI: `armdbg` (for optional debug).

## Build
```bash
./build.sh          # builds boot, app, app_core1, app_core10, app_core11
./build.sh clean    # removes objects, maps, ELFs
```
Each subdir also has its own `Makefile` if you want to build individually.

## Run on FVP
Default config runs four cores and Iris on port 7100 (see `NUM_CORES`/`IRIS_PORT` in `build.sh`):
```bash
./build.sh run          # build, start FVP in background, tail log, launch armdbg (if installed)
./build.sh run fvp      # build then run only the FVP in the foreground
./build.sh run debug    # attach armdbg to an already-running FVP
```
The script passes all ELFs to the model; the last one (`boot.elf`) is the entry point.

## Memory / stack notes
- Boot ROM/scatter: `boot.scat`, entry `_start` at `0x0`.
- Core0 app scatter: `app.scat`, vectors at `0x00020000`, stack top `0x20018000`.
- Core1 app scatter: `app_core1.scat`, vectors at `0x00040000`, stack top `0x20028000`.
- Core10 app scatter: `app_core10.scat`, vectors at `0x00060000`, stack top `0x20038000`.
- Core11 app scatter: `app_core11.scat`, vectors at `0x00080000`, stack top `0x20048000`.
- Each app’s `bootloader.S` drops to EL1/SVC, sets its stack, and jumps to the C runtime for that core.
