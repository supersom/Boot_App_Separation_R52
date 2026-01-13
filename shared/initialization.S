/*
 * initialization.S
 *
 *  Created on: Nov 12, 2025
 *
 *	Description: This file has:
 *		Initialization procedures for the GIC, Flash, TCMs & EL2 HYP stack
 *		Init procedures for System counter and "All_Cores_Except_0_To_Sleep"
 *			are not used right now
 *
 *
 *  Copyright (c) C2i Semiconductors.
 *  All rights reserved. This file is part of proprietary firmware and
 *  internal development at C2i Semiconductors. Unauthorized copying,
 *  redistribution, or use of this file in source or binary forms, with or
 *  without modification, is strictly prohibited unless explicit written
 *  permission is granted by C2i Semiconductors.
 *
 * ---------------------------------------------------------------------------*/

#include "common_defs.h"

#ifdef FVP_FAST_MODEL
@.equ SYSTEM_COUNTER_FREQUENCY, 0x5F5E100      // = 100MHz
.equ FAST_MODELS_COUNTER_CONTROL,   0xAA430000
#else
@.equ SYSTEM_COUNTER_FREQUENCY, 0x493E0        // = 300KHz
#endif

//----------------------------------------------------------------
//	GICD config base and register offsets
//----------------------------------------------------------------

// The base address of the Distributor registers.
.equ DISTRIBUTOR_BASE_ADDRESS,          0xAF000000

// Distributor register offsets
.equ GICD_CTLR_OFFSET,                  0x0

//----------------------------------------------------------------
//	GICR config base (multi-core) and register offsets
//----------------------------------------------------------------

// The base address of Core 0 & 1 Redistributor registers.
.equ CORE0_REDISTRIBUTOR_BASE_ADDRESS,      0xAF100000
.equ CORE1_REDISTRIBUTOR_BASE_ADDRESS,      0xAF120000
.equ CORE10_REDISTRIBUTOR_BASE_ADDRESS,     0xAF140000
.equ CORE11_REDISTRIBUTOR_BASE_ADDRESS,     0xAF160000

// Redistributor register offsets
.equ GICR_CTLR_OFFSET,                  0x0
.equ GICR_WAKER_OFFSET,                 0x14

//----------------------------------------------------------------
//	GICR SGI/PPI base (multi-core) and register offsets
//----------------------------------------------------------------

// The base address of core 0 and core 1 Redistributor SGI/PPI registers.
.equ CORE0_REDISTRIBUTOR_SGI_PPI_BASE_ADDRESS,  0xAF110000
.equ CORE1_REDISTRIBUTOR_SGI_PPI_BASE_ADDRESS,  0xAF130000
.equ CORE10_REDISTRIBUTOR_SGI_PPI_BASE_ADDRESS, 0xAF150000
.equ CORE11_REDISTRIBUTOR_SGI_PPI_BASE_ADDRESS, 0xAF170000

// Redistributor SGI/PPI register offsets.
.equ GICR_IGROUPR0_OFFSET,                      0x80
.equ GICR_ISENABLER0_OFFSET,                    0x100
.equ GICR_IPRIORITYR_OFFSET,                    0x400 // The base address of eight
                                                      // registers holding the
                                                      // priority for 32 interrupts.
.equ GICR_ICFGR1_OFFSET,                        0xC04

.global All_Cores_Except_0_To_Sleep
.type All_Cores_Except_0_To_Sleep, "function"
All_Cores_Except_0_To_Sleep:
    // Put any Core other than 0 to sleep.
    // It is possible to find out which Core is currently in use by checking the
    // Multiprocessor Affinity Register (MPIDR). At affinity level 0, the cores are
    // identified numerically from 0 to 3.
    MRC p15, 0, r0, c0, c0, 5            // Read MPIDR into r0.
    AND r0, r0, #0xFF                    // Isolate bits used for affinity level 0.
    // Core ID now in r0.
    CMP r0, #0x0
    BEQ boot                             // If bits 0-7 are set to 0 this is Core 0.
    // If run on a multi-core system, put any secondary cores to sleep
    // TODO: in phase 3 [multi-core bootloader] loop_wfi will be replaced
    // by secondary_boot that will take secondary core to secondary_main
    // through second stage bootloader.
loop_wfi:
    // For Cores other than 0.
    DSB SY      // Clear all pending data accesses
    WFI			// Go to sleep
    B loop_wfi
boot:
    MOV pc, lr

.global Hyp_Init_Regs_and_Set_Stack_Pointer
.type Hyp_Init_Regs_and_Set_Stack_Pointer, "function"
Hyp_Init_Regs_and_Set_Stack_Pointer:
    // This function assumes the following:
    // r0: the upper limit of the memory assigned to the EL2 stack.

    // Set HYP stack pointer for the core.
    MRC  p15, 0, r1, c0, c0, 5           // Read MPIDR into r1.
    AND r1, r1, #0xFF                    // Isolate bits used for affinity level 0.
    // Core ID now in r1.

    SUB  r0, r0, r1, lsl #14             // Adjust position on stack heap according to core
                                         // before writing to sp_hyp.
    MSR sp_hyp, r0
    MOV pc, lr

.global Enable_Flash
.type Enable_Flash, "function"
Enable_Flash:
    LDR r1,=0x3C                    // SIZE field mask

    MRC p15, 0, r0, c15, c0, 1      // Read from FLASHIFREGIONR
    ANDS r2, r0, r1                 // Extract SIZE and set flags
    BEQ 1f
    ORR r0, r0, #0x1                // Set enable bit if SIZE=!0x0
    MCR p15, 0, r0, c15, c0, 1      // Write r0 to FLASHIFREGIONR if SIZE=!0x0
	BL markFlashInitialized
1:
	MOV pc, lr

.global Enable_ATCM
.type Enable_ATCM, "function"
Enable_ATCM:
	MRS r5, SP_hyp
	CMP r5, 0x0 //r5 has SP
	BEQ 1f // Don't use stack if not init
	PUSH {lr}
	// r0: arg 0 passed from caller, contains ATCM base address
	// r1: arg 1 passed from caller, kept reserved for TCM size
1:
    MRC p15, 0, r2, c9, c1, 0       // Read ATCM Region Register
    // r2 now contains ATCM size in bits [5:2]
    AND r3, r2, #(0xF << 2)
    CMP r3, #(TCMSIZECODE << 2)       	// SIZE = 8 (128KB) i.e log2(128KB)-9
    BNE 2f 						// Size mismatch. Leave ATCM disabled
    ORR r2, r0, #(TCMSIZECODE << 2)       	// SIZE = 8 (128KB) i.e log2(128KB)-9
    ORR r2, r2, #3                  // Enable it
    MCR p15, 0, r2, c9, c1, 0       // Write ATCM Region Register

	CMP r5, 0x0 //r5 has SP
	BEQ 2f // Don't use stack if not init
	BL markATCMInitialized
	B 3f
2:								// marking core specific init flag
    MRC p15, 0, r0, c0, c0, 5   // Read MPIDR into R0
    ANDS r0, r0, 0xFF
    LDR r2, =ATCM_initialized
    ADD r2, r2, r0, LSL #2
    MOV r3, #0x1
    STR r3, [r2]
3:
	CMP r5, 0x0 //r5 has SP
	BEQ 4f // Don't use stack if not init
	POP {lr}
4:
	MOV pc, lr

.global Enable_BTCM
.type Enable_BTCM, "function"
Enable_BTCM:
	PUSH {lr}
	// r0: arg 0 passed from caller, contains BTCM base address
	// r1: arg 1 passed from caller, kept reserved for TCM size
    MRC p15, 0, r2, c9, c1, 1       // Read BTCM Region Register
    // r2 now contains BTCM size in bits [5:2]
    AND r3, r2, #(0xF << 2)
    CMP r3, #(TCMSIZECODE << 2)       	// SIZE = 8 (128KB) i.e log2(128KB)-9
    BNE 1f 						// Size mismatch. Leave BTCM disabled
    ORR r2, r0, #(TCMSIZECODE << 2)       	// SIZE = 8 (128KB) i.e log2(128KB)-9
    ORR r2, r2, #1                  // Enable it
    MCR p15, 0, r2, c9, c1, 1       // Write BTCM Region Register
	BL markBTCMInitialized
1:
	POP {lr}
	MOV pc, lr

.global Enable_CTCM
.type Enable_CTCM, "function"
Enable_CTCM:
	PUSH {lr}
	// r0: arg 0 passed from caller, contains CTCM base address
	// r1: arg 1 passed from caller, kept reserved for TCM size
    MRC p15, 0, r2, c9, c1, 2       // Read ATCM Region Register
    // r2 now contains CTCM size in bits [5:2]
    AND r3, r2, #(0xF << 2)
    CMP r3, #(CTCMSIZECODE << 2)       	// SIZE = 8 (128KB) i.e log2(128KB)-9
    BNE 1f 						// Size mismatch. Leave CTCM disabled
    ORR r2, r0, #(CTCMSIZECODE << 2)       	// SIZE = 8 (128KB) i.e log2(128KB)-9
    ORR r2, r2, #1                  // Enable it
    MCR p15, 0, r2, c9, c1, 2       // Write CTCM Region Register
	BL markCTCMInitialized
1:
	POP {lr}
	MOV pc, lr

.global Set_CNTFRQ_And_Enable_Fast_Models_Counter
.type Set_CNTFRQ_And_Enable_Fast_Models_Counter, "function"
Set_CNTFRQ_And_Enable_Fast_Models_Counter:
    // Set the Counter-timer Frequency register (CNTFRQ) to the frequency
    // that the system counter is running at. CNTFRQ is not used by the
    // hardware, but it is available for software to use to discover the frequency.
    LDR r0, =SYSTEM_COUNTER_FREQUENCY
    MCR p15, 0, r0, c14, c0, 0  // Write r0 to CNTFRQ

#ifdef FVP_FAST_MODEL
    // Enable Fast Models Counter. If timers are being used, it is essential to
    // enable this when we are using Fast Models.
    LDR r0, =FAST_MODELS_COUNTER_CONTROL
    LDR r1, [r0]
    ORR r1, r1, 0x3
    STR r1, [r0]
#endif
    MOV pc, lr

.global Enable_Floating_Point_Functionality
.type Enable_Floating_Point_Functionality, "function"
Enable_Floating_Point_Functionality:
    // ** Floating point functionality must be enabled to use standard C library: 

	//----------------------------------------------------------------
	// Enable access to VFP by enabling access to Coprocessors 10 and 11.
	// Enables Full Access i.e. in both privileged and non privileged modes
	//
    // Set bits 20-23 on the CP Architectural Feature Access Control Register
    // (CPACR) to permit full access to Advanced SIMD and floating-point
    // functionality from EL1 and EL0.
	//----------------------------------------------------------------

    MRC     p15, 0, r0, c1, c0, 2      // Read Coprocessor Access Control Register (CPACR)
    ORR     r0, r0, #(0xF << 20)       // Enable access to CP 10 & 11
    MCR     p15, 0, r0, c1, c0, 2      // Write Coprocessor Access Control Register (CPACR)
    ISB

	//----------------------------------------------------------------
	// Switch on the VFP hardware
	//
    // Set bit 30 on the Floating-Point Exception Control Register to globally
    // enable Advanced SIMD and floating-point support.
	//----------------------------------------------------------------

    MOV     r0, #0x40000000
    VMSR    FPEXC, r0                   // Write FPEXC register, EN bit set

    MOV pc, lr

.global Primary_GIC_Setup
.type Primary_GIC_Setup, "function"
Primary_GIC_Setup:
    // ** The Generic Interrupt Controller  (GIC) is used to manage the
    // timer exceptions:
    PUSH {lr}
    BL init_GICD
    BL init_GICR
    BL init_GICC
    POP {lr}
    BX lr

.global Corewise_GIC_Setup
.type Corewise_GIC_Setup, "function"
Corewise_GIC_Setup:
    // ** The Generic Interrupt Controller  (GIC) is used to manage the
    // timer exceptions:
    PUSH {lr}
    BL init_GICR
    BL init_GICC
    POP {lr}
    BX lr

.global init_GICD
.type init_GICD, "function"
init_GICD:
	PUSH {lr}
    // Use GIC Distributor Control Register (GICD_CTLR) to enable interrupts
    // and affinity routing. If interrupts are not switched on nothing can happen.
    // Note that ARMv8-R processors only support a single security state
    // and this is reflected in the limited settings for this register.
    LDR      r0, =DISTRIBUTOR_BASE_ADDRESS
    ADD      r1, r0, #GICD_CTLR_OFFSET            // Load address of GICD_CTLR into
                                                  // r1. ADD just for completeness
                                                  // as offset for GICD_CTLR is 0.
    MOV      r2, #0x1                             // Enable Group 0 interrupts.
    ORR      r2, #0x2                             // Enable Group 1 interrupts.
    ORR      r2, #0x10                            // Enable affinity routing (in NS mode).
    STR      r2, [r1]                             // Store value in GICD_CTLR.
    DSB      SY

    // Keep looping until bit 31 is not set on the GICD_CTLR. When bit 31 is not
    // set, it means the previous settings are now visible to all GIC components.
    MOV r3, #0x80000000
GICD_CTLR_wait:
    LDR r2, [r1]
    AND r2, r2, r3                       // Test whether bit 31 is set.
    CMP r2, r3
    BEQ GICD_CTLR_wait                   // Continue polling until it is not set.

    BL markGICDInitialized
    POP {lr}
    BX lr

.global init_GICR
.type init_GICR, "function"
init_GICR:
    // Mark core 0 as awake in the Core 0 Redistributor and (if required)
    // mark core 1 as awake in the Core 1 Redistributor.
	PUSH {lr}
	BL getCPUID
    // Core ID now in r0.
    CMP r0, #0x1
    BEQ core1                     // If bits 0-7 are set to 1 this is core 1.
    CMP r0, #0x2
    BEQ core10                    // If bits 0-7 are set to 2 this is core 10.
    CMP r0, #0x3
    BEQ core11                    // If bits 0-7 are set to 3 this is core 11.
    // Assume core 0 if here - good enough for these examples.
    LDR      r0, =CORE0_REDISTRIBUTOR_BASE_ADDRESS
    B all
core1:
    LDR      r0, =CORE1_REDISTRIBUTOR_BASE_ADDRESS
    B all
core10:
    LDR      r0, =CORE10_REDISTRIBUTOR_BASE_ADDRESS
    B all
core11:
    LDR      r0, =CORE11_REDISTRIBUTOR_BASE_ADDRESS
all:
    // Use the GIC Redistributor Wake Register (GICR_WAKER) to do this.
    // Set bit 1 to 0 to indicate the core is not in (or entering) low power state.
    ADD      r1, r0, #GICR_WAKER_OFFSET
    LDR      r2, [r1]
    AND      r2, r2, #0xFFFFFFFD
    STR      r2, [r1]
    DSB      SY

    // Now wait until bit 2 is set to 0, which indicates that the CPU interface
    // (and therefore core) connected to the Resdistributor is awake.
    MOV      r3, #0x4
GICR_WAKER_wait:
    LDR      r2, [r1]
    AND      r2, r2, r3                   // Test whether bit 2 is set.
    CMP      r2, r3
    BEQ      GICR_WAKER_wait              // Continue polling until it is not set.
    POP {lr}
    BX lr

.global init_GICC
.type init_GICC, "function"
init_GICC:
	PUSH {lr}
    // Turn Group 0 and Group 1 interrupts on in the physical GIC CPU interface
    // system registers. Use the following two registers:
    // 1. Interrupt Controller Interrupt Group 0 Enable register (ICC_IGRPEN0)
    // 2. Interrupt Controller Interrupt Group 1 Enable register (ICC_IGRPEN1)
	BL enableGroup0Ints
	BL enableGroup1Ints

    // Set priority filter for Core 0. Only interrupts with a higher priority
    // than this value are signaled to the core.
    // Set bits 3:7 on the Interrupt Controller Interrupt Priority Mask Register
    // (ICC_PMR) to specify the minimum priority handled by the core.
    // A value of 31 indicates the lowest possible priority and a value of 0
    // indicates the highest.

    MOV r0, #0xFF           // Set priority filter so the core handles everything.
                            // Set all 8 priority filter bits even though the
                            // Cortex-R52 only use the most significant 5 bits.
	BL setPriorityMask

    // Specify which bits from the priority bits are used as the group priority
    // field. The group priority field is used to determine preemption. Preemption
    // is when a lower priority interrupt already being handled by the core gets
    // put on hold while a higher priority interrupt is handled. The point at which
    // the more significant bits are used for the group priority field is known as
    // the binary point.
    // The following registers are used to set the binary point:
    // 1. Interrupt Controller Binary Point Register 0 (ICC_BPR0)
    // 2. Interrupt Controller Binary Point Register 1 (ICC_BPR1)
    MOV r0, #0x7                // Set to no preemeption (.sssss).
                                // No bits used for preemeption.
	BL setBinaryPoint
	BL setAliasedBinaryPoint

	POP {lr}
    MOV pc, lr

//----------------------------------------------------------------
// Enable Instruction and Data Caching
//----------------------------------------------------------------

    .global enable_caches
    .type enable_caches, "function"
    .cfi_startproc
enable_caches:
        MRC     p15, 0, r0, c1, c0, 0       // read System Control Register
        ORR     r0, r0, #(0x1 << 12)        // enable I Cache
        ORR     r0, r0, #(0x1 << 2)         // enable D Cache
        MCR     p15, 0, r0, c1, c0, 0       // write System Control Register
        ISB

        BX    lr
    .cfi_endproc
