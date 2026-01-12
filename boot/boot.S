//# include "../shared/r52.h"    

    .syntax unified
    .arm

    .section RESET, "ax"

    .global _start
    .type _start, "function"
_start:
    mrc p15, 0, r0, c0, c0, 5   // Read MPIDR into r0
    AND r0, r0, #0x3            // Mask to get CPU ID (bits [1:0])

    ////////////////////////////////////////////////////////////////////////
    // Store the core ID into a known memory location for the application to read. Using address 0x10000000 in a RAM region accessible by all cores at startup.

    // LDR r1, =0x10000000         // Load the address of our shared structure:
                                // boot_args_t
    // LDR r2, =0x4                // Size of boot_args_t 
                                // structure                                
    // MUL r2, r0, r2              // Each core's structure is 8 bytes             
                                // apart                                
    // STR r0, [r1, r2]            // Store the core ID (from r0) into the 
                                // structure
    ////////////////////////////////////////////////////////////////////////

    CMP r0, #0                  // Compare with 0 (CPU0)
    BEQ .L_core0_start          // If CPU0, branch to core0 start
    // Non-zero CPU ID, so this is a secondary core.
    B .L_secondary_core_start // Branch to secondary core start

.L_core0_start:
    // The FVP starts in EL2/Hyp mode. We must switch to EL1/SVC mode
    // and set up a stack before branching to any C library code.

    mrs r0, cpsr
    and r0, r0, #0x1F  // Isolate mode bits
    cmp r0, #0x1A      // Compare with Hyp mode (0b11010)
    bne L_setup_stack // If not Hyp, just set up stack for current (privileged) mode

.L_switch_to_svc:
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

    .global L_setup_stack
    .type L_setup_stack, "function"
L_setup_stack:
    // We are now in a privileged EL1 mode (e.g., SVC).
    // Set up the stack pointer for this mode before calling any C code.
    // The stack top is 0x20008000 as defined in boot.scat.
    ldr sp, =Image$$ARM_LIB_STACK$$Base //0x20008000

   // 2. Jump to the main application's C runtime entry point.
   // The application's base address is 0x00020000.
   // Its vector table is at the start of that address.
   // The second entry in the vector table (at offset +4) is the address of the Reset Handler,
   // which in our case will be the C library's __main function for the app.
    
   ldr r0, =0x00020000     // Load the application's base address into R0
   ldr r0, [r0, #4]        // Read the Reset Handler address (the second word in the vector table)
                           // The value read is the entry point (e.g., __main) of the application.
   bx r0                   // Branch and Exchange to the address in R0.
                           // 'bx' ensures the correct instruction set (ARM or Thumb) is used based on the LSB of R0.

    // Now that the mode is correct and the stack is valid, we can branch
    // to the C library's entry point, which will eventually call our main().
    //b __main

.L_secondary_core_start:
    // Identify if this is a valid secondary core (CPU1/CPU2/CPU3)
    mrc p15, 0, r0, c0, c0, 5 // Read MPIDR into r0
    AND r0, r0, #0x3         // Mask to get CPU ID (bits [1:0])
    CMP r0, #4               // Compare with 4 (only cores 0-3 expected)
    BHS .L_secondary_hold_up // If not 0-3, stay here (infinite loop)

    // The FVP starts in EL2/Hyp mode. We must switch to EL1/SVC mode
    // and set up a stack before branching to any C library code.

    mrs r0, cpsr
    and r0, r0, #0x1F  // Isolate mode bits
    cmp r0, #0x1A      // Compare with Hyp mode (0b11010)
    bne L_setup_secondary_stack // If not Hyp, just set up stack for current (privileged) mode

.L_secondary_switch_to_svc:
    // Init HSCTLR
    LDR r0, =0x30C5180C             // See TRM for decoding
    MCR p15, 4, r0, c1, c0, 0       // Write to HSCTLR

    // Enable EL1 access to all IMP DEF registers
    LDR r0, =0x7F81
    MCR p15, 4, r0, c1, c0, 1       // Write to HACTLR

    // Change EL1 exception base address
    LDR r0, =L_setup_secondary_stack
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
    adr r0, L_setup_secondary_stack
    msr elr_hyp, r0

    eret // Execute exception return to drop from EL2 to EL1

    .global L_setup_secondary_stack
    .type L_setup_secondary_stack, "function"
L_setup_secondary_stack:
    mrc p15, 0, r0, c0, c0, 5 // Read MPIDR into r0
    AND r0, r0, #0x3         // Mask to get CPU ID (bits [1:0])

    // We are now in a privileged EL1 mode (e.g., SVC).
    // Set up the stack pointer for this mode before calling any C code.
    // The stack top is 0x20008000 as defined in boot.scat.
    ldr sp, =Image$$ARM_LIB_STACK$$Base //0x20008000
    ldr r1, =0x1000            // Size of stack space per core
    mul r1, r0, r1        // Each core gets its own 0x1000 byte stack space
    sub sp, sp, r1             // Adjust SP for this core; r1 = core_id * 0x1000

   // 2. Jump to the main application's C runtime entry point.
   // The application's base address is 0x00020000.
   // Its vector table is at the start of that address.
   // The second entry in the vector table (at offset +4) is the address of the Reset Handler,
   // which in our case will be the C library's __main function for the app.
    
   ////////////////////////////////////////////////////////////////////////
   // Read the Reset Handler address (the second word in the vector table of core_id i.e. base + core_id * 0x8)
    // ldr r1, =0x8            // Offset multiplier (8 bytes of app vector table
                            // per core)
    // sub r2, r0, #0x1        // [core_id (r0) - 1] in r2
    // mul r2, r2, r1          // core_id * 8
    // add r0, r0, r2          // base + offset (0x4) + (core_id * 8)
    sub r0, r0, #1           // Index 0..2 for core1/core10/core11
    ldr r1, =secondary_app_bases
    ldr r0, [r1, r0, lsl #2] // Load base address for this core
    ldr r0, [r0, #4]         // Read the Reset Handler address (second word)
   ////////////////////////////////////////////////////////////////////////
                            // The value read is the entry point (e.g., __main) of the application.
   bx r0                    // Branch and Exchange to the address in R0.
                            // 'bx' ensures the correct instruction set (ARM or Thumb) is used based on the LSB of R0.

.L_secondary_hold_up:
    // Infinite loop for non-CPU1/2/3 secondary cores
    b .L_secondary_hold_up

secondary_app_bases:
    .word 0x00040000         // core1
    .word 0x00060000         // core10 (core id 2)
    .word 0x00080000         // core11 (core id 3)
