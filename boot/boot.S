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
    // Store the core ID into a known memory location for the application to read. Using address 0x00400000 in a RAM region accessible by all cores at startup.

    // LDR r1, =0x00400000         // Load the address of our shared structure:
                                // boot_args_t
    // LDR r2, =0x4                // Size of boot_args_t 
                                // structure                                
    // MUL r2, r0, r2              // Each core's structure is 8 bytes             
                                // apart                                
    // STR r0, [r1, r2]            // Store the core ID (from r0) into the 
                                // structure
    ////////////////////////////////////////////////////////////////////////

    CMP r0, #4                  // Compare with 4 (only cores 0-3 expected)
    BHS .L_secondary_hold_up    // If not 0-3, stay here (infinite loop)
    CMP r0, #0                  // Compare with 0 (CPU0)
    BEQ .L_core0_start          // If CPU0, branch to core0 start
    // Non-zero CPU ID, so this is a secondary core.
    B .L_secondary_core_start   // Branch to secondary core start

.L_core0_start:
   // Jump to the core0 application's Reset Handler.
   // The application's base address is 0x00020000.
   // Its vector table is at the start of that address.
   // The second entry in the vector table (at offset +4) is the address of the Reset Handler.
   ldr r0, =0x00020000     // Load the application's base address into R0
   ldr r0, [r0, #4]        // Read the Reset Handler address (second word)
   bx r0                   // Branch and Exchange to the address in R0.
                           // 'bx' ensures the correct instruction set (ARM or Thumb) is used based on the LSB of R0.

.L_secondary_core_start:
    // Jump to the secondary core application's Reset Handler.
    // The application's base address is core-specific.
    sub r0, r0, #1           // Index 0..2 for core1/core10/core11
    ldr r1, =secondary_app_bases
    ldr r0, [r1, r0, lsl #2] // Load base address for this core
    ldr r0, [r0, #4]         // Read the Reset Handler address (second word)
    bx r0                    // Branch and Exchange to the address in R0.
                            // 'bx' ensures the correct instruction set (ARM or Thumb) is used based on the LSB of R0.

.L_secondary_hold_up:
    // Infinite loop for non-CPU1/2/3 secondary cores
    b .L_secondary_hold_up

secondary_app_bases:
    .word 0x00040000         // core1
    .word 0x00060000         // core10 (core id 2)
    .word 0x00080000         // core11 (core id 3)
