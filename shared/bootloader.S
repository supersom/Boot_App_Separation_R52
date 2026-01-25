#include "common_defs.h"
    .syntax unified
    .arm
#ifdef __THUMB__
    .thumb
#endif
	.eabi_attribute 25, 1   // Tag_ABI_align_needed    = 8-byte
.if 0
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

    // Enable TCMs for Core 0 before __scatterload runs.
    ldr r0, =0x01000000             // Core 0 ATCM base
    ldr r1, =0x02000000             // Core 0 BTCM base
    ldr r2, =0x03000000             // Core 0 CTCM base
    push {r1, r2}
    bl Enable_ATCM
    pop {r0, r2}
    push {r2}
    bl Enable_BTCM
    pop {r0}
    bl Enable_CTCM

    // Enable FP/NEON before any C code uses floating point.
    bl enable_fpu

    // Primary core initializes GIC Distributor and core interface.
    bl init_GICD
    bl Corewise_GIC_Setup

    // Wait for secondaries to enable SGI0 and enter WFI.
wait_secondaries:
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
    bl enable_fpu

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
.endif

//----------------------------------------------------------------
//----------------------------------------------------------------
// BOOT INIT FUNCTIONS FOR PRIMARY AND SECONDARY CORES
//----------------------------------------------------------------
//----------------------------------------------------------------

    .section PRIMARY_BOOT,"ax"
    .align 3
//----------------------------------------------------------------
// Cortex-R52 boot init - primary core
//----------------------------------------------------------------
.global primary_boot
.type primary_boot, "function"
primary_boot:
		BL init_pmu_cctr
@		LDR r0, =pmccntr_start_val
		BL profile_start_asm

		//----------------------------------------------------------------
		// Enable ATCM - if disabled at reset
		//----------------------------------------------------------------
#ifdef TCM
		//TODO: Figure out if this is the TCM type register
		//TODO: Decode sizes of the TCMs and pass into Enable_TCM
	    MRC p15, 0, r0, c0, c0, 2       // Read TCM Type Register
	    // r0 now contains TCM availability

	    LDR r0, =APP_ATCM_BASE              // Set ATCM base address
		BL Enable_ATCM
		BL awaitATCMInit
#endif		// TCM

		//----------------------------------------------------------------
		// Setup HYP stack
		//----------------------------------------------------------------
		LDR r0, =APP_STACK_TOP
		MSR sp_hyp, r0

		//----------------------------------------------------------------
		// Enable Flash i/f
		//----------------------------------------------------------------
#ifdef ENABLE_R52_SPECIFIC_CONFIG
		BL Enable_Flash
		//uncomment below line if flash is mandatory, say, for patched boot
		// BL awaitFlashInit
#endif

		//----------------------------------------------------------------
		// TODO: Insert code to:
		//			Enable debug
		//			Write flash programming code to ATCM
		//			Program application or boot loader patch into flash
		//		This could also be handled as an abort or interrupt
		//----------------------------------------------------------------

		//----------------------------------------------------------------
		// Branch to first stage boot loader (FSBL)
		// FSBL can be patched to the flash if there are issues running
		// it from the ROM
		//----------------------------------------------------------------
		B FSBL_main


    .section SECONDARY_BOOT,"ax"
    .align 3
//----------------------------------------------------------------
// Cortex-R52 boot init - primary core
//----------------------------------------------------------------
.global secondary_boot
.type secondary_boot, "function"
secondary_boot:
		BL init_pmu_cctr
@		LDR r0, =pmccntr_c01_start_val
		BL profile_start_asm

	    // For Cores other than 0.
		//----------------------------------------------------------------
		// Enable ATCM - if disabled at reset
		//----------------------------------------------------------------
		//TODO: Figure out if this is the TCM type register
		//TODO: Decode sizes of the TCMs and pass into Enable_TCM
	    MRC p15, 0, r0, c0, c0, 2       // Read TCM Type Register
	    // r0 now contains TCM availability
	    LDR r0, =APP_ATCM_BASE          // Set ATCM base address
		BL Enable_ATCM
		BL awaitATCMInit

		//----------------------------------------------------------------
		// Setup HYP stack 
		//----------------------------------------------------------------
.if 0        
	    BL getCPUID
	    CMP r0, #CPU_ID_01
	    BEQ 1f
	    CMP r0, #CPU_ID_10
	    BEQ 2f
	    BNE 3f
1:
	    LDR r0, =__stack_top_c01      // Set stack top address
	    B 4f
2:
	    LDR r0, =__stack_top_c10      // Set stack top address
	    B 4f
3:
	    LDR r0, =__stack_top_c11      // Set stack top address
4:
	    LDR r0, =__stack_top_c01      // Set stack top address
.else
	    LDR r0, =APP_STACK_TOP      // Set stack top address
.endif
		MSR sp_hyp, r0

    	B FSBL_secondary

#ifdef SINGLE_CORE_BOOT
	    DSB SY      // Clear all pending data accesses
	    WFI			// Go to sleep
    	B secondary_boot
#endif 		// SINGLE_CORE_BOOT

//----------------------------------------------------------------
//----------------------------------------------------------------
// FSBL FUNCTIONS FOR PRIMARY AND SECONDARY CORES
// FSBL RUNS IN EL2 AND IS THE EARLIEST PATCHABLE CODE
//----------------------------------------------------------------
//----------------------------------------------------------------

	.section FSBL,"ax"
	.align 3

.global FSBL_main
.type FSBL_main, "function"
FSBL_main:
		BL init_GICD
		B FSBL_secondary

.global FSBL_secondary
.type FSBL_secondary, "function"
FSBL_secondary:
		// Ensure EL2 ABT/IRQ/FIQ vectors are active before WFI
                LDR r0, =EL2_Vectors
                MCR p15, 4, r0, c12, c0, 0      // Write to HVBAR

		BL getCPUID
		CMP R0, #0x0
		BEQ FSBL_Primary_Core

		BL awaitGICDInit
		BL Corewise_GIC_Setup

//----------------------------------------------------------------
// Secondary cores (1, 10, 11) logic:
// 		enable abort, irq & fiq
//		mark core initialized
// 		goes into WFI
//----------------------------------------------------------------
.if 0        
		// Enable SGI for this core before waiting.
        BL getCPUID
		MOV R3, R0          // target core_id
		ADD R0, R0, #1      // SGI ID for cores 1/2/3 are 2/3/4
		MOV R1, #0x3F
		MOV R2, #1
		BL GIC_enable_SGI_PPI_ASM

		BL markCoreInitialized
		BL markCoreWaiting
		cpsie aif
		DSB SY
		BL wait
.else
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
.endif
		B FSBL_Post_Wakeup

FSBL_Primary_Core:
        BL Corewise_GIC_Setup
        
//----------------------------------------------------------------
// Primary core (0) logic:
// Loop through secondary cores (1, 2, 3), wait for each to init,
// enable SGI for them, and trigger it.
//----------------------------------------------------------------
        PUSH {R4, LR}
.if 0        
        MOV R4, #1
FSBL_Primary_Wait_Loop:
        CMP R4, #4
        BEQ FSBL_Primary_Done

        MOV R0, R4
        BL awaitSpecificCoreInit
FSBL_Primary_Wait_Core_Ready:
        MOV R0, R4
        BL isCoreWaiting
        CMP R0, #0x1
        BNE FSBL_Primary_Wait_Core_Ready

        // sendGroup0SGI(uint32_t ID, uint32_t mode, uint32_t target_list)
        MOV R0, R4
		ADD R0, R0, #1		// SGI ID for the 3 secondary cores are 2, 3, 4
        LSL R0, R0, #24     // INTID in [31:24]
		MOV R1, #0x0        // Rt2
		MOV R2, #1
		LSL R2, R2, R4      // target_list: bit R4
		BL sendGroup0SGI
		DSB SY

        ADD R4, R4, #1
        B FSBL_Primary_Wait_Loop

FSBL_Primary_Done:

.else

    // Wait for secondaries to enable SGI0 and enter WFI.
wait_secondaries:
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

    // Wake secondary cores after per-core GIC setup.
    // SGI ID = 0, Group 1, target list: core 1/2/3.
    mov r0, #0
    mov r1, #0
    mov r2, #0
    orr r2, r2, #0x2      // core 1
    orr r2, r2, #0x4      // core 2
    orr r2, r2, #0x8      // core 3
    bl sendGroup1SGI
.endif

        POP {R4, LR}

FSBL_Post_Wakeup:
	/* ---------------------------------------------------------------------------*
	 * Copying ATCM contents - exception handlers, vector tables and GIC CPU i/fs
	 * ---------------------------------------------------------------------------*/
        LDR     r0, =APP_ATCM_LOAD         // src (ROM)
        LDR     r1, =APP_ATCM_BASE         // dst (TCM)
        LDR     r2, =APP_ATCM_LEN          // total bytes
		BL Copy_ROM_to_TCM

    // Change EL2 exception base address
        LDR r0, =EL2_Vectors
        MCR p15, 4, r0, c12, c0, 0      // Write to HVBAR

    // Init HSCTLR
        LDR r0, =0x30C5180C             // See TRM for decoding
        MCR p15, 4, r0, c1, c0, 0       // Write to HSCTLR

    // Enable EL1 access to all IMP DEF registers
        LDR r0, =0x7F81
        MCR p15, 4, r0, c1, c0, 1       // Write to HACTLR

    /* CNTHCTL_EL2: allow EL1 access to phys counter/timer */
        mrc   p15, 4, r0, c14, c1, 0      /* CNTHCTL_EL2 */
        orr   r0, r0, #0x3                /* set EL1PCTEN|EL1PCEN */
        mcr   p15, 4, r0, c14, c1, 0

        LDR r0, =APP_EL1_VECTORS
FSBL_VBAR_Set:
        MCR p15, 0, r0, c12, c0, 0      // Write to VBAR

	// Disable execution of HVC instructions
        MRC p15, 4, r0, c1, c1, 0       // Read HCR
        ORR r0, r0, #0x20000000
        MCR p15, 4, r0, c1, c1, 0       // Write to HCR

#ifdef USE_EL2_MPU
        BL EL2_MPU_Setup
#endif // USE_EL2_MPU

    // Go to SVC mode
        MRS r0, cpsr
        MOV r1, #Mode_SVC
        BFI r0, r1, #0, #5
#ifdef __THUMB__
        ORR r0, r0, #(0x1 << 5)         // Set T bit
#endif
        MSR spsr_cxsf, r0
@        LDR r0, =EL1_Reset_Handler
        LDR r0, =APP_EL1_RESET_HANDLER
FSBL_Reset_Set:
        MSR elr_hyp, r0
        DSB
        ISB
        ERET

//----------------------------------------------------------------
//----------------------------------------------------------------
// SSBL FUNCTIONS - COMMON FOR PRIMARY AND SECONDARY CORES
// SSBL RUNS IN EL1
//----------------------------------------------------------------
//----------------------------------------------------------------

	.section SSBL,"ax"
	.align 3

.global SSBL_common
.type SSBL_common, "function"
SSBL_common:
//----------------------------------------------------------------
// Disable MPU and caches
//----------------------------------------------------------------

    // Disable MPU and caches in case they were left enabled from an earlier run
    // This does not need to be done from a cold reset

        MRC p15, 0, r0, c1, c0, 0       // Read System Control Register

        BIC r0, r0, #0x05               // Disable MPU (M bit) and data cache (C bit)

        BIC r0, r0, #0x1000             // Disable instruction cache (I bit)
        DSB                             // Ensure all previous loads/stores have completed
        MCR p15, 0, r0, c1, c0, 0       // Write System Control Register
        ISB                             // Ensure subsequent insts execute wrt new MPU settings


//----------------------------------------------------------------
// Enable high performance peripheral i/f
//----------------------------------------------------------------
#ifdef ENABLE_R52_SPECIFIC_CONFIG
        LDR r1,=0x3C                    // SIZE field mask
        MRC p15, 0, r0, c15, c0, 0      // Read from PERIPHPREGIONR
        ANDS r2, r0, r1                 // Extract SIZE and set flags
        BEQ 1f
        ORR r0, r0, #0x1                // Set enable bit if SIZE=!0x0
        MCR p15, 0, r0, c15, c0, 0      // Write r0 to PERIPHPREGIONR if SIZE=!0x0
1:
#endif

//----------------------------------------------------------------
// Initialize stacks using linker symbol from scatter file.
// ABT, IRQ, FIQ, UNDEF size = STACK_SIZE, SVC the rest.
// Stacks must be 8 byte aligned.
//----------------------------------------------------------------
        //
        // Setup the stack(s) for this CPU
        // Allocate 2^14 (=0x4000) bytes for the application stack per core
        //
.if 0        
        MRC  p15, 0, r1, c0, c0, 5      // Read CPU ID register
        AND  r1, r1, #0x03              // Mask off, leaving the CPU ID field
		CMP r1, #0x0
		BEQ stack_c00
		CMP r1, #0x1
		BEQ stack_c01
		CMP r1, #0x2
		BEQ stack_c10
		// C11
        LDR  r0, =__stack_top_c11
        B stack_selected
stack_c00:
        LDR  r0, =__stack_top_c00
        B stack_selected
stack_c01:
        LDR  r0, =__stack_top_c01
        B stack_selected
stack_c10:
        LDR  r0, =__stack_top_c10
stack_selected:
.else
	    LDR r0, =APP_STACK_TOP      // Set stack top address
.endif
		//-0 offset is the EL2 stack - HYP (sp_hyp), ABT, IRQ, FIQ
        CPS #Mode_ABT
        SUB r0, r0, #(CONTEXTS/2 * STACK_SIZE)
        MOV SP, r0

        CPS #Mode_IRQ
        SUB r0, r0, #STACK_SIZE
        MOV SP, r0

        CPS #Mode_FIQ
        SUB r0, r0, #STACK_SIZE
        MOV SP, r0

        CPS #Mode_SVC
        SUB r0, r0, #STACK_SIZE
        MOV SP, r0

//----------------------------------------------------------------
// Cache invalidation. However Cortex-R52 provides CFG signals to
// invalidate cache automatically out of reset (CFGL1CACHEINVDISx)
//----------------------------------------------------------------

        DSB             // Complete all outstanding explicit memory operations

        MOV r0, #0

        MCR p15, 0, r0, c7, c5, 0       // Invalidate entire instruction cache

        // Invalidate Data/Unified Caches

        MRC     p15, 1, r0, c0, c0, 1      // Read CLIDR
        ANDS    r3, r0, #0x07000000        // Extract coherency level
        MOV     r3, r3, LSR #23            // Total cache levels << 1
        BEQ     Finished                   // If 0, no need to clean

        MOV     r10, #0                    // R10 holds current cache level << 1
Loop1:  ADD     r2, r10, r10, LSR #1       // R2 holds cache "Set" position
        MOV     r1, r0, LSR r2             // Bottom 3 bits are the Cache-type for this level
        AND     r1, r1, #7                 // Isolate those lower 3 bits
        CMP     r1, #2
        BLT     Skip                       // No cache or only instruction cache at this level

        MCR     p15, 2, r10, c0, c0, 0     // Write the Cache Size selection register
        ISB                                // ISB to sync the change to the CacheSizeID reg
        MRC     p15, 1, r1, c0, c0, 0      // Reads current Cache Size ID register
        AND     r2, r1, #7                 // Extract the line length field
        ADD     r2, r2, #4                 // Add 4 for the line length offset (log2 16 bytes)
        LDR     r4, =0x3FF
        ANDS    r4, r4, r1, LSR #3         // R4 is the max number on the way size (right aligned)
        CLZ     r5, r4                     // R5 is the bit position of the way size increment
        LDR     r7, =0x7FFF
        ANDS    r7, r7, r1, LSR #13        // R7 is the max number of the index size (right aligned)

Loop2:  MOV     r9, r4                     // R9 working copy of the max way size (right aligned)

#ifdef __THUMB__
Loop3:	LSL     r12, r9, r5
        ORR     r11, r10, r12              // Factor in the Way number and cache number into R11
        LSL     r12, r7, r2
        ORR     r11, r11, r12              // Factor in the Set number
#else
Loop3:	ORR     r11, r10, r9, LSL r5       // Factor in the Way number and cache number into R11
        ORR     r11, r11, r7, LSL r2       // Factor in the Set number
#endif
        MCR     p15, 0, r11, c7, c6, 2     // Invalidate by Set/Way
        SUBS    r9, r9, #1                 // Decrement the Way number
        BGE     Loop3
        SUBS    r7, r7, #1                 // Decrement the Set number
        BGE     Loop2
Skip:   ADD     r10, r10, #2               // Increment the cache number
        CMP     r3, r10
        BGT     Loop1

Finished:

//----------------------------------------------------------------
// B/CTCM Configuration - ATCM initialized in boot code
//----------------------------------------------------------------

#ifdef TCM

	    //Check which CPU I am
	    MRC p15, 0, r1, c0, c0, 5   // Read MPIDR into Rt
	    AND r1, r1, 0xFF

        MRC p15, 0, r0, c0, c0, 2       // Read TCM Type Register
        // r0 now contains TCM availability

		BL isATCMInitialized
		CMP r0, 0x1
		BEQ ATCM_Init_Skip

        LDR r0, =APP_ATCM_BASE             // Set ATCM base address
		BL Enable_ATCM
		BL awaitATCMInit
ATCM_Init_Skip:
		BL isBTCMInitialized
		CMP r0, 0x1
		BEQ BTCM_Init_Skip

        LDR r0, =APP_BTCM_BASE             // Set BTCM base address
        BL Enable_BTCM
		BL awaitBTCMInit
BTCM_Init_Skip:
		BL isCTCMInitialized
		CMP r0, 0x1
		BEQ CTCM_Init_Skip

        LDR r0, =APP_CTCM_BASE             // Set CTCM base address
        BL Enable_CTCM
		BL awaitCTCMInit
CTCM_Init_Skip:
#endif

        LDR     r0, =APP_BTCM_LOAD         // src (ROM)
        LDR     r1, =APP_BTCM_BASE         // dst (TCM)
        LDR     r2, =APP_BTCM_LEN          // total bytes
	BL Copy_ROM_to_TCM

        LDR     r0, =APP_CTCM_LOAD         // src (ROM)
        LDR     r1, =APP_CTCM_BASE         // dst (TCM)
        LDR     r2, =APP_CTCM_LEN          // total bytes
	BL Copy_ROM_to_TCM

        BL EL1_MPU_Setup

#ifdef __ARM_FP
		BL Enable_Floating_Point_Functionality
#endif

//----------------------------------------------------------------
// Enable MPU and branch to C library init
// Leaving the caches disabled until after scatter loading.
//----------------------------------------------------------------

        MRC     p15, 0, r0, c1, c0, 0       // Read System Control Register

        ORR     r0, r0, #0x01               // Set M bit to enable MPU

        DSB                                 // Ensure all previous loads/stores have completed
        MCR     p15, 0, r0, c1, c0, 0       // Write System Control Register
        ISB                                 // Ensure subsequent insts execute wrt new MPU settings

// TODO: All go to respective __main. Branching is not needed. Remove.

		BL getCPUID
		CMP r0, #CPU_ID_00
		BEQ Boot_Core00
		CMP r0, #CPU_ID_01
		BEQ Boot_Core01
		CMP r0, #CPU_ID_10
		BEQ Boot_Core10
		// Core 11
		// LDR r0, =APP_BASE_C11
		B Boot_App_Entry

	Boot_Core00:
		// LDR r0, =APP_BASE_C00
		B Boot_App_Entry
	Boot_Core01:
		// LDR r0, =APP_BASE_C01
		B Boot_App_Entry
	Boot_Core10:
		// LDR r0, =APP_BASE_C10
		B Boot_App_Entry

Boot_App_Entry:
		B __main
