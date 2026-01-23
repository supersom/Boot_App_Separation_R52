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
    // Use a lower slice of ARM_LIB_STACK for FIQ mode.
    mrs r1, cpsr
    bic r1, r1, #0x1F
    orr r1, r1, #0xD1  // FIQ mode, IRQ/FIQ disabled
    msr cpsr_c, r1
    ldr sp, =Image$$ARM_LIB_STACK$$ZI$$Limit
    sub sp, sp, #0x2000
    // Use a lower slice of ARM_LIB_STACK for ABT mode.
    mrs r1, cpsr
    bic r1, r1, #0x1F
    orr r1, r1, #0xD7  // ABT mode, IRQ/FIQ disabled
    msr cpsr_c, r1
    ldr sp, =Image$$ARM_LIB_STACK$$ZI$$Limit
    sub sp, sp, #0x3000
    mrs r1, cpsr
    bic r1, r1, #0x1F
    orr r1, r1, #0xD3  // Back to SVC mode
    msr cpsr_c, r1

    // Configure MPU early so shared flags are non-cacheable/shareable.
    bl init_mpu

    // Enable FP/NEON before any C code uses floating point.
    bl enable_fpu

    // Primary core initializes GIC Distributor and core interface.
    bl init_GICD
    bl Corewise_GIC_Setup

    // Wait for secondaries to enable SGI0 and enter WFI.
wait_secondaries:
//.if 0
    mov r0, #1
    bl isCoreWaiting
    cmp r0, #0x1
    bne wait_secondaries
    mov r0, #2
    bl isCoreWaiting
    cmp r0, #0x1
    bne wait_secondaries
    mov r0, #3
    bl isCoreWaiting
    cmp r0, #0x1
    bne wait_secondaries
//.endif
    // Wake secondary cores after per-core GIC setup.
    // SGI ID = 0, Group 1, target list: core 1/2/3.
    mov r0, #0
    mov r1, #0
    mov r2, #0
    orr r2, r2, #0x2      // core 1
    orr r2, r2, #0x4      // core 2
    orr r2, r2, #0x8      // core 3
    bl sendGroup1SGI

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
    // Use a lower slice of ARM_LIB_STACK for FIQ mode.
    mrs r1, cpsr
    bic r1, r1, #0x1F
    orr r1, r1, #0xD1  // FIQ mode, IRQ/FIQ disabled
    msr cpsr_c, r1
    ldr sp, =Image$$ARM_LIB_STACK$$ZI$$Limit
    sub sp, sp, #0x2000
    // Use a lower slice of ARM_LIB_STACK for ABT mode.
    mrs r1, cpsr
    bic r1, r1, #0x1F
    orr r1, r1, #0xD7  // ABT mode, IRQ/FIQ disabled
    msr cpsr_c, r1
    ldr sp, =Image$$ARM_LIB_STACK$$ZI$$Limit
    sub sp, sp, #0x3000
    mrs r1, cpsr
    bic r1, r1, #0x1F
    orr r1, r1, #0xD3  // Back to SVC mode
    msr cpsr_c, r1

    // Configure MPU early so shared flags are non-cacheable/shareable.
    bl init_mpu

    // Enable TCMs for this core before __scatterload runs.
    // __scatterload will try to zero TCM .bss regions.
    mrc p15, 0, r4, c0, c0, 5       // Read MPIDR
    and r4, r4, #0x3                // Isolate core ID bits
    cmp r4, #0x1
    beq tcm_core1
    cmp r4, #0x2
    beq tcm_core2
    cmp r4, #0x3
    beq tcm_core3
    b tcm_done                      // Core 0 shouldn't reach here (uses setup_stack_primary)
tcm_core1:
    ldr r0, =0x05000000             // Core 1 ATCM base
    ldr r1, =0x06000000             // Core 1 BTCM base
    ldr r2, =0x07000000             // Core 1 CTCM base
    b tcm_enable
tcm_core2:
    ldr r0, =0x09000000             // Core 2 ATCM base
    ldr r1, =0x0A000000             // Core 2 BTCM base
    ldr r2, =0x0B000000             // Core 2 CTCM base
    b tcm_enable
tcm_core3:
    ldr r0, =0x0D000000             // Core 3 ATCM base
    ldr r1, =0x0E000000             // Core 3 BTCM base
    ldr r2, =0x0F000000             // Core 3 CTCM base
tcm_enable:
    // Save BTCM/CTCM bases before calling Enable_ATCM
    push {r1, r2}
    bl Enable_ATCM
    pop {r0, r2}
    push {r2}
    bl Enable_BTCM
    pop {r0}
    bl Enable_CTCM
tcm_done:

    // Enable FP/NEON before any C code uses floating point.
    // bl enable_fpu

    // Wait for primary core to initialize GICD before per-core setup.
    bl awaitGICDInit

    // Secondary core initializes its GIC Redistributor and core interface.
    bl Corewise_GIC_Setup

    // Enable SGI 0 for this core and wait for the primary to wake us.
    mov r0, #0            // SGI ID
    mov r1, #0x3F         // priority
    mov r2, #0            // IRQ (Group 1)
    mrc p15, 0, r3, c0, c0, 5
    and r3, r3, #0xFF
    bl GIC_enable_SGI_PPI_ASM
    // Signal readiness to the primary before entering WFI.
    bl markCoreWaiting
    cpsie i
    bl wait

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
    b el1_vector_reset
el1_vector_undef:
    b el1_vector_undef
el1_vector_svc:
    b el1_vector_svc
el1_vector_pabort:
    b el1_vector_pabort
el1_vector_dabort:
//    b el1_vector_dabort
    // Log fault info to shared RAM for post-mortem
    MRC p15, 0, r1, c6, c0, 0       // DFAR
    MRC p15, 0, r2, c5, c0, 0       // DFSR
    MRC p15, 0, r3, c6, c0, 2       // IFAR
    MRC p15, 0, r4, c5, c0, 1       // IFSR
    MRC p15, 0, r5, c0, c0, 5       // MPIDR
    MRS r6, SPSR
    MOV r7, lr
    LDR r0, =0x00400F00
    STR r1, [r0, #0]
    STR r2, [r0, #4]
    STR r3, [r0, #8]
    STR r4, [r0, #12]
    STR r5, [r0, #16]
    STR r6, [r0, #20]
    STR r7, [r0, #24]
1:      B   1b

el1_vector_hyp:
    b el1_vector_hyp

el1_default_handler:
    b el1_default_handler

    .extern readIntAck
    .extern writeEOI
    .extern GICIsrVectorTable

    el1_vector_fiq:
    push {r0-r3, r12, lr}
    bl readIntAck
    mov r1, r0
    ldr r4, =0x3FF
    and r0, r0, r4
    ldr r2, =GICIsrVectorTable
    ldr r3, [r2, r0, lsl #2]
    blx r3
    mov r0, r1
    bl writeEOI
    pop {r0-r3, r12, lr}
    subs pc, lr, #4

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
