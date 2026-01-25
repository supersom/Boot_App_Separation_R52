#include "common_defs.h"

    .syntax unified
    .arm
#ifdef __THUMB__
    .thumb
#endif
    .eabi_attribute 25, 1

.if 0
    .section .text.bootloader, "ax"

    .global app_bootloader
    .type app_bootloader, "function"
app_bootloader:
    // The FVP starts in EL2/Hyp mode. Switch to EL1/SVC and set up a stack.
    mrs r0, cpsr
    and r0, r0, #0x1F  // Isolate mode bits
    cmp r0, #0x1A      // Compare with Hyp mode (0b11010)
    bne setup_stack_secondary  // If not Hyp, just set up stack for current (privileged) mode

    // Switch to SVC via shared routine; pass setup stack address in r0.
    ldr r0, =setup_stack_secondary
    b switch_to_svc_common
.endif

    .section .app_vector_table, "a"
    .align 2
    .global __app_vector_table
__app_vector_table:
    .word APP_STACK_TOP
    .word EL2_Vectors
