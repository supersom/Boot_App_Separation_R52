    .syntax unified
    .arm

    .section .text.bootloader_common, "ax"

    .global switch_to_svc_common
    .type switch_to_svc_common, "function"
switch_to_svc_common:
    // r0 = setup stack address for ELR
    // Init HSCTLR
    LDR r1, =0x30C5180C             // See TRM for decoding
    MCR p15, 4, r1, c1, c0, 0       // Write to HSCTLR

    // Enable EL1 access to all IMP DEF registers
    LDR r1, =0x7F81
    MCR p15, 4, r1, c1, c0, 1       // Write to HACTLR

    // Change EL1 exception base address
    LDR r1, =el1_vector_table
    MCR p15, 0, r1, c12, c0, 0      // Write to VBAR

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
    // Use a lower slice of ARM_LIB_STACK for IRQ mode.
    mrs r1, cpsr
    bic r1, r1, #0x1F
    orr r1, r1, #0xD2  // IRQ mode, IRQ/FIQ disabled
    msr cpsr_c, r1
    ldr sp, =Image$$ARM_LIB_STACK$$ZI$$Limit
    sub sp, sp, #0x1000
    mrs r1, cpsr
    bic r1, r1, #0x1F
    orr r1, r1, #0xD3  // Back to SVC mode
    msr cpsr_c, r1

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
    // Use a lower slice of ARM_LIB_STACK for IRQ mode.
    mrs r1, cpsr
    bic r1, r1, #0x1F
    orr r1, r1, #0xD2  // IRQ mode, IRQ/FIQ disabled
    msr cpsr_c, r1
    ldr sp, =Image$$ARM_LIB_STACK$$ZI$$Limit
    sub sp, sp, #0x1000
    mrs r1, cpsr
    bic r1, r1, #0x1F
    orr r1, r1, #0xD3  // Back to SVC mode
    msr cpsr_c, r1

    // Configure MPU early so shared flags are non-cacheable/shareable.
    bl init_mpu

    // Wait for primary core to initialize GICD before per-core setup.
    bl awaitGICDInit

    // Secondary core initializes its GIC Redistributor and core interface.
    bl Corewise_GIC_Setup

    // Jump to the C runtime entry point for this app.
    b __main

    .section .text.el1_vectors, "ax"
    .align 5
el1_vector_table:
    b el1_vector_reset
    b el1_vector_undef
    b el1_vector_svc
    b el1_vector_pabort
    b el1_vector_dabort
    b el1_vector_hyp
    b el1_vector_irq
    b el1_vector_fiq

el1_vector_reset:
    b el1_default_handler
el1_vector_undef:
    b el1_default_handler
el1_vector_svc:
    b el1_default_handler
el1_vector_pabort:
    b el1_default_handler
el1_vector_dabort:
    b el1_default_handler
el1_vector_hyp:
    b el1_default_handler
el1_vector_fiq:
    b el1_default_handler

el1_default_handler:
    b el1_default_handler

    .extern readAliasedIntAck
    .extern writeAliasedEOI
    .extern GICIsrVectorTable_COM

el1_vector_irq:
    push {r0-r3, r12, lr}
    bl readAliasedIntAck
    mov r1, r0
    ldr r4, =0x3FF
    and r0, r0, r4
    ldr r2, =GICIsrVectorTable_COM
    ldr r3, [r2, r0, lsl #2]
    blx r3
    mov r0, r1
    bl writeAliasedEOI
    pop {r0-r3, r12, lr}
    subs pc, lr, #4
