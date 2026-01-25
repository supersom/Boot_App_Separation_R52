#include "common_defs.h"

    .section .Reset_Handler, "ax"
    .align 2
    
//----------------------------------------------------------------
// EL2 Exception Vector Table
//----------------------------------------------------------------
// Note: LDR PC instructions are used here, though branch (B) instructions
// could also be used, unless the exception handlers are >32MB away.
.global EL2_Vectors
EL2_Vectors:
        LDR PC, EL2_Reset_Addr
        LDR PC, EL2_HVC_Addr
        LDR PC, EL2_HypModeEntry_Addr
        LDR PC, EL2_Undefined_Addr
        LDR PC, EL2_Prefetch_Addr
        LDR PC, EL2_Abort_Addr
        LDR PC, EL2_IRQ_Addr
        LDR PC, EL2_FIQ_Addr


EL2_Reset_Addr:         .word    EL2_Reset_Handler
EL2_HVC_Addr:           .word    EL2_HVC_Handler
EL2_HypModeEntry_Addr:  .word    EL2_HypModeEntry_Handler
EL2_Undefined_Addr:     .word    EL2_Undefined_Handler
EL2_Prefetch_Addr:      .word    EL2_Prefetch_Handler
EL2_Abort_Addr:         .word    EL2_Abort_Handler
EL2_IRQ_Addr:           .word    EL2_IRQ_Handler
EL2_FIQ_Addr:           .word    EL2_FIQ_Handler

//----------------------------------------------------------------
// EL2 Exception Handlers
//----------------------------------------------------------------

.type EL2_HVC_Handler, "function"
EL2_HVC_Handler:
        B   EL2_HVC_Handler

.type EL2_HypModeEntry_Handler, "function"
EL2_HypModeEntry_Handler:
//        B   EL2_HypModeEntry_Handler
        subs    pc, lr, #4   // resume where it came from

//----------------------------------------------------------------
// TODO: EL2 Undefined Handler
//----------------------------------------------------------------

.type EL2_Undefined_Handler, "function"
EL2_Undefined_Handler:
        B   EL2_Undefined_Handler

//----------------------------------------------------------------
// TODO: EL2 Prefetch Handler
//----------------------------------------------------------------

.type EL2_Prefetch_Handler, "function"
EL2_Prefetch_Handler:
        B   EL2_Prefetch_Handler

//----------------------------------------------------------------
// EL2 IRQ Handler
//----------------------------------------------------------------

.type EL2_Abort_Handler, "function"
EL2_Abort_Handler:
        // Log fault info to shared RAM for post-mortem
        MRC p15, 0, r1, c6, c0, 0       // DFAR
        MRC p15, 0, r2, c5, c0, 0       // DFSR
        MRC p15, 0, r3, c6, c0, 2       // IFAR
        MRC p15, 0, r4, c5, c0, 1       // IFSR
        MRC p15, 0, r5, c0, c0, 5       // MPIDR
        MRS r6, SPSR
        MOV r7, lr
        LDR r0, =0x00401F00
        STR r1, [r0, #0]
        STR r2, [r0, #4]
        STR r3, [r0, #8]
        STR r4, [r0, #12]
        STR r5, [r0, #16]
        STR r6, [r0, #20]
        STR r7, [r0, #24]
1:      B   1b

//----------------------------------------------------------------
// EL2 IRQ Handler
//----------------------------------------------------------------

.type EL2_IRQ_Handler, "function"
EL2_IRQ_Handler:
//        B   EL2_IRQ_Handler
	mrs r5, SPSR
	// add 4 bytes to LR
	push {r0-r4, r5, r12, lr}
	and r1, sp, #4						// Check if the sp is 8-byte aligned, if not r1 = 4. AAPCS mandates 8-byte alignment at all external boundaries (i.e. separately compiled or assembled files).
	sub sp, sp, r1						// Sub 0 (already aligned) or 4 (misaligned)
	push {r1}							// Push r1 (adjustment info) and lr_HYP onto the stack. lr_HYP is used in the subroutine call, so it must be stacked (here) and restored (before returning).
	bl readAliasedIntAck					// r0 will contain the FIQ source number, source identified, interrupt active
1:	mov r4, r0							// Use r4 to store the FIQ source number, to be used later
	cpsie i								// Re-enable interrupts (FIQ)
	//TODO: optimize by branch-and-link to the ISR directly, without IVT addr calc
	ldr r1, =GICIsrVectorTable_COM		// Load in r1 base of the FIQ vector table
	ldr r1, [r1, r0, lsl #2]			// Load in r1 = r1 + r0*4. Multiply by 4: offset from the base of the vector table
	blx r1								// Branch to the C Interrupt Service Routine
	cpsid i								// Disable interrupts (FIQ)
	mov r0, r4							// Move FIQ source number (stored in r4) to r0
	bl writeAliasedEOI						// Write r0 to ICC_EOIR: End of interrupt, priority drop and deactivation
	bl readAliasedIntAck					// Before restoring the context, check if any other interrupt is pending
	mov r1, #SPURIOUSID					// 1023: spurious interrupt, meaning no interrupt pending
	cmp r0, r1							// Compare with what was read
	bne 1b								// If there is another interrupt pending, handle it
	pop {r1}						// Pop r1 (adjustment info) from the stack
	add sp, sp, r1						// Unadjust sp as per previous state
	pop {r0-r4, r5, r12, lr}
	msr SPSR, r5
	bx lr

//----------------------------------------------------------------
// EL2 FIQ Handler
//----------------------------------------------------------------
.type EL2_FIQ_Handler, "function"
EL2_FIQ_Handler:
	mrs r5, SPSR
	push {r0-r4, r5, r12, lr}
	and r1, sp, #4						// Check if the sp is 8-byte aligned, if not r1 = 4. AAPCS mandates 8-byte alignment at all external boundaries (i.e. separately compiled or assembled files).
	sub sp, sp, r1						// Sub 0 (already aligned) or 4 (misaligned)
	push {r1}							// Push r1 (adjustment info) and lr_HYP onto the stack. lr_HYP is used in the subroutine call, so it must be stacked (here) and restored (before returning).
	bl readIntAck					// r0 will contain the FIQ source number, source identified, interrupt active
1:	mov r4, r0							// Use r4 to store the FIQ source number, to be used later
	cpsie f								// Re-enable interrupts (FIQ)
	//TODO: optimize by branch-and-link to the ISR directly, without IVT addr calc
	ldr r1, =GICIsrVectorTable_COM		// Load in r1 base of the FIQ vector table
	ldr r1, [r1, r0, lsl #2]			// Load in r1 = r1 + r0*4. Multiply by 4: offset from the base of the vector table
	blx r1								// Branch to the C Interrupt Service Routine
	cpsid f								// Disable interrupts (FIQ)
	mov r0, r4							// Move FIQ source number (stored in r4) to r0
	bl writeEOI						// Write r0 to ICC_EOIR: End of interrupt, priority drop and deactivation
	bl readIntAck					// Before restoring the context, check if any other interrupt is pending
	mov r1, #SPURIOUSID					// 1023: spurious interrupt, meaning no interrupt pending
	cmp r0, r1							// Compare with what was read
	bne 1b								// If there is another interrupt pending, handle it
	pop {r1}						// Pop r1 (adjustment info) from the stack
	add sp, sp, r1						// Unadjust sp as per previous state
	pop {r0-r4, r5, r12, lr}
	msr SPSR, r5
	bx lr

//----------------------------------------------------------------
// EL2 Reset Handler
//----------------------------------------------------------------
.type EL2_Reset_Handler, "function"
EL2_Reset_Handler:
	    // Put any Core other than 0 to sleep.
	    // It is possible to find out which Core is currently in use by checking the
	    // Multiprocessor Affinity Register (MPIDR). At affinity level 0, the cores are
	    // identified numerically from 0 to 3.
		BL getCPUID //in r0
	    // Core ID now in r0.
	    CMP r0, #CPU_ID_00 					//0x0
	    BEQ primary_boot                    // If bits 0-7 are set to 0 this is Core 0.
	    B secondary_boot

