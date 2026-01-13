    .syntax unified
    .arm

    .section .text.bootloader, "ax"

    .global app_bootloader
    .type app_bootloader, "function"
app_bootloader:
    // The FVP starts in EL2/Hyp mode. Switch to EL1/SVC and set up a stack.
    mrs r0, cpsr
    and r0, r0, #0x1F  // Isolate mode bits
    cmp r0, #0x1A      // Compare with Hyp mode (0b11010)
    bne L_setup_stack  // If not Hyp, just set up stack for current (privileged) mode

L_switch_to_svc:
    // Init HSCTLR
    LDR r0, =0x30C5180C             // See TRM for decoding
    MCR p15, 4, r0, c1, c0, 0       // Write to HSCTLR

    // Enable EL1 access to all IMP DEF registers
    LDR r0, =0x7F81
    MCR p15, 4, r0, c1, c0, 1       // Write to HACTLR

    // Change EL1 exception base address
    LDR r0, =L_setup_stack
    MCR p15, 0, r0, c12, c0, 0      // Write to VBAR

    // Disable execution of HVC instructions
    MRC p15, 4, r0, c1, c1, 0       // Read HCR
    ORR r0, r0, #0x20000000
    MCR p15, 4, r0, c1, c1, 0       // Write to HCR

    // In Hyp mode, so prepare to switch to SVC mode
    mrs r0, cpsr
    bic r0, r0, #0x1F  // Clear mode bits
    orr r0, r0, #0xD3  // Set SVC mode (0x13), and disable FIQ/IRQ interrupts (0xC0)
    msr spsr_cxsf, r0

    // Set return address to the stack setup code
    adr r0, L_setup_stack
    msr elr_hyp, r0

    eret // Execute exception return to drop from EL2 to EL1

L_setup_stack:
    // We are now in a privileged EL1 mode (e.g., SVC).
    // Set up the stack pointer for this mode before calling any C code.
    ldr sp, =Image$$ARM_LIB_STACK$$Base

    // Primary core initializes GIC Distributor and core interface.
    // bl Primary_GIC_Setup
    bl init_GICD
    bl Corewise_GIC_Setup

    // Jump to the C runtime entry point for this app.
    b __main
