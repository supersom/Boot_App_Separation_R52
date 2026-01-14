    .syntax unified
    .arm

    .section .text.bootloader_common, "ax"

    .global switch_to_svc_common
    .type switch_to_svc_common, "function"
switch_to_svc_common:
    // r0 = setup stack address for VBAR and ELR
    // Init HSCTLR
    LDR r1, =0x30C5180C             // See TRM for decoding
    MCR p15, 4, r1, c1, c0, 0       // Write to HSCTLR

    // Enable EL1 access to all IMP DEF registers
    LDR r1, =0x7F81
    MCR p15, 4, r1, c1, c0, 1       // Write to HACTLR

    // Change EL1 exception base address
    MCR p15, 0, r0, c12, c0, 0      // Write to VBAR

    // Disable execution of HVC instructions
    MRC p15, 4, r1, c1, c1, 0       // Read HCR
    ORR r1, r1, #0x20000000
    MCR p15, 4, r1, c1, c1, 0       // Write to HCR

    // In Hyp mode, so prepare to switch to SVC mode
    mrs r1, cpsr
    bic r1, r1, #0x1F  // Clear mode bits
    orr r1, r1, #0xD3  // Set SVC mode (0x13), and disable FIQ/IRQ interrupts (0xC0)
    msr spsr_cxsf, r1

    // Set return address to the stack setup code
    msr elr_hyp, r0

    eret // Execute exception return to drop from EL2 to EL1

    .global setup_stack_primary
    .type setup_stack_primary, "function"
setup_stack_primary:
    // We are now in a privileged EL1 mode (e.g., SVC).
    // Set up the stack pointer for this mode before calling any C code.
    ldr sp, =Image$$ARM_LIB_STACK$$ZI$$Limit

    // Configure MPU early so shared flags are non-cacheable/shareable.
    bl init_mpu

    // Primary core initializes GIC Distributor and core interface.
    bl init_GICD
    bl Corewise_GIC_Setup

    // Jump to the C runtime entry point for this app.
    b __main

    .global setup_stack_secondary
    .type setup_stack_secondary, "function"
setup_stack_secondary:
    // We are now in a privileged EL1 mode (e.g., SVC).
    // Set up the stack pointer for this mode before calling any C code.
    ldr sp, =Image$$ARM_LIB_STACK$$ZI$$Limit

    // Configure MPU early so shared flags are non-cacheable/shareable.
    bl init_mpu

    // Wait for primary core to initialize GICD before per-core setup.
    bl awaitGICDInit

    // Secondary core initializes its GIC Redistributor and core interface.
    bl Corewise_GIC_Setup

    // Jump to the C runtime entry point for this app.
    b __main
