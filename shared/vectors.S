#include "common_defs.h"
    .syntax unified
    .arm
#ifdef __THUMB__
    .thumb
#endif
    .eabi_attribute 25,1   // Tag_ABI_align_needed
    .eabi_attribute 24,1   // Tag_ABI_align_preserved

    .section EL1_VECTORS, "ax"
    .align 5

    .global el1_vector_table
    .type el1_vector_table, %function
el1_vector_table:
    b el1_vector_reset
    b el1_vector_undef
    b el1_vector_svc
    b el1_vector_pabort
    b el1_vector_dabort
    b el1_vector_hyp
    b el1_vector_irq
    b el1_vector_fiq

    .global el1_vector_reset
    .type el1_vector_reset, %function
el1_vector_reset:
//    b el1_vector_reset
    LDR PC, =SSBL_common

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

    .extern readIntAck_C00
    .extern writeEOI_C00
    .extern GICIsrVectorTable_C00

.type el1_vector_fiq, %function
el1_vector_fiq:
.if 0
    push {r0-r3, r12, lr}
    bl readIntAck_C00
    mov r1, r0
    ldr r4, =0x3FF
    and r0, r0, r4
    ldr r2, =GICIsrVectorTable
    ldr r3, [r2, r0, lsl #2]
    blx r3
    mov r0, r1
    bl writeEOI_C00
    pop {r0-r3, r12, lr}
    subs pc, lr, #4
.else
	mrs r5, SPSR
	push {r0-r4, r5, r12, lr}
	and r1, sp, #4						// Check if the sp is 8-byte aligned, if not r1 = 4. AAPCS mandates 8-byte alignment at all external boundaries (i.e. separately compiled or assembled files).
	sub sp, sp, r1						// Sub 0 (already aligned) or 4 (misaligned)
	push {r1}							// Push r1 (adjustment info) and lr_HYP onto the stack. lr_HYP is used in the subroutine call, so it must be stacked (here) and restored (before returning).
	bl readIntAck_C00					// r0 will contain the FIQ source number, source identified, interrupt active
1:	mov r4, r0							// Use r4 to store the FIQ source number, to be used later
	cpsie f								// Re-enable interrupts (FIQ)
	//TODO: optimize by branch-and-link to the ISR directly, without IVT addr calc
	ldr r1, =GICIsrVectorTable		// Load in r1 base of the FIQ vector table
	ldr r1, [r1, r0, lsl #2]			// Load in r1 = r1 + r0*4. Multiply by 4: offset from the base of the vector table
	blx r1								// Branch to the C Interrupt Service Routine
	cpsid f								// Disable interrupts (FIQ)
	mov r0, r4							// Move FIQ source number (stored in r4) to r0
	bl writeEOI_C00						// Write r0 to ICC_EOIR: End of interrupt, priority drop and deactivation
	bl readIntAck_C00					// Before restoring the context, check if any other interrupt is pending
	mov r1, #SPURIOUSID					// 1023: spurious interrupt, meaning no interrupt pending
	cmp r0, r1							// Compare with what was read
	bne 1b								// If there is another interrupt pending, handle it
	pop {r1}						// Pop r1 (adjustment info) from the stack
	add sp, sp, r1						// Unadjust sp as per previous state
	pop {r0-r4, r5, r12, lr}
	msr SPSR_cxsf, r5
	subs pc, lr, #4
.endif

    .extern readAliasedIntAck
    .extern writeAliasedEOI
    .extern GICIsrVectorTable_COM

.type el1_vector_irq, %function
el1_vector_irq:
.if 0
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
.else
	mrs r5, SPSR
	push {r0-r4, r5, r12, lr}
	and r1, sp, #4						// Check if the sp is 8-byte aligned, if not r1 = 4. AAPCS mandates 8-byte alignment at all external boundaries (i.e. separately compiled or assembled files).
	sub sp, sp, r1						// Sub 0 (already aligned) or 4 (misaligned)
	push {r1}							// Push r1 (adjustment info) and lr_HYP onto the stack. lr_HYP is used in the subroutine call, so it must be stacked (here) and restored (before returning).
	bl readAliasedIntAck_C00					// r0 will contain the FIQ source number, source identified, interrupt active
1:	mov r4, r0							// Use r4 to store the FIQ source number, to be used later
	cpsie f								// Re-enable interrupts (FIQ)
	//TODO: optimize by branch-and-link to the ISR directly, without IVT addr calc
	ldr r1, =GICIsrVectorTable		// Load in r1 base of the FIQ vector table
	ldr r1, [r1, r0, lsl #2]			// Load in r1 = r1 + r0*4. Multiply by 4: offset from the base of the vector table
	blx r1								// Branch to the C Interrupt Service Routine
	cpsid f								// Disable interrupts (FIQ)
	mov r0, r4							// Move FIQ source number (stored in r4) to r0
	bl writeAliasedEOI_C00						// Write r0 to ICC_EOIR: End of interrupt, priority drop and deactivation
	bl readAliasedIntAck_C00					// Before restoring the context, check if any other interrupt is pending
	mov r1, #SPURIOUSID					// 1023: spurious interrupt, meaning no interrupt pending
	cmp r0, r1							// Compare with what was read
	bne 1b								// If there is another interrupt pending, handle it
	pop {r1}						// Pop r1 (adjustment info) from the stack
	add sp, sp, r1						// Unadjust sp as per previous state
	pop {r0-r4, r5, r12, lr}
	msr SPSR_cxsf, r5
	subs pc, lr, #4
.endif
