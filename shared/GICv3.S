		.global GIC_enable_SPI_ASM
		.type GIC_enable_SPI_ASM, %function

	// Define GIC Distributor Base Address
	// CHANGE THIS to match your specific SoC memory map
		.equ GICD_BASE, 0xAF000000

	// GICv3 Offsets
		.equ GICD_IGROUPR0,   0x0080
		.equ GICD_ISENABLER0, 0x0100
		.equ GICD_IPRIORITYR, 0x0400
		.equ GICD_ICFGR0,     0x0C00
		.equ GICD_IROUTER,    0x6000

// Arguments (AAPCS)
// R0: INTn
// R1: pri
// R2: fiq
// R3: edge_trigger
// stack: affinity - aff[0], aff[1], aff[2]

// void GIC_enable_SPI_ASM(uint32_t, uint32_t, uint32_t, uint32_t, uint32_t *);
GIC_enable_SPI_ASM:
    // Prologue: Save callee-saved registers and Link Register
    // We strictly need to save R4-R8 if we use them.
    // Pushing 6 registers (4 bytes each) moves SP down by 24 bytes.
    	PUSH {R4-R8, LR}

    // Load GIC Distributor Base Address into R4
    	LDR R4, =GICD_BASE

    // ---------------------------------------------------------
    // 1. SET PRIORITY (GICD_IPRIORITYR)
    // Offset = 0x400 + 32 + INTn
    // ---------------------------------------------------------
	    ADD R5, R4, #GICD_IPRIORITYR // R5 = Base + 0x400
	    ADD R5, R5, #32              // R5 = Base + 0x400 + 32 (Start of SPIs)
	    STRB R1, [R5, R0]            // Store byte: Mem[R5 + INTn] = Priority (R1)

    // ---------------------------------------------------------
    // 2. SET GROUP / SECURITY (GICD_IGROUPR)
    // We target IGROUPR[1] (Offset 0x084) which covers SPIs 0-31
    // ---------------------------------------------------------
	    ADD R5, R4, #GICD_IGROUPR0
	    ADD R5, R5, #4               // Offset 0x084 (IGROUPR[1])

	    LDR R6, [R5]                 // Load current IGROUPR[1] value
	    MOV R7, #1
	    LSL R7, R7, R0               // R7 = 1 << INTn

	    CMP R2, #0                   // Check 'fiq' argument (R2)
	    BNE set_fiq_group

    // Set to Group 1 (IRQ)
	    ORR R6, R6, R7               // Set bit
	    B write_group

set_fiq_group_SPI:
    // Set to Group 0 (FIQ)
    	BIC R6, R6, R7               // Clear bit

write_group_SPI:
    	STR R6, [R5]                 // Write back to IGROUPR[1]

    // ---------------------------------------------------------
    // 3. SET CONFIGURATION (Edge vs Level) (GICD_ICFGR)
    // Logic: INTn 0-15 is in ICFGR[2], INTn 16-31 is in ICFGR[3]
    // ---------------------------------------------------------
	    ADD R5, R4, #GICD_ICFGR0
	    ADD R5, R5, #8               // Start at ICFGR[2] (Offset 0xC08)

	    MOV R6, R0                   // Copy INTn to R6
	    CMP R6, #16
	    BLT calc_cfg_bit             // If INTn < 16, we are in ICFGR[2]

	    // If INTn >= 16, move to ICFGR[3] and adjust index
	    ADD R5, R5, #4               // Move pointer to ICFGR[3]
	    SUB R6, R6, #16              // Adjust index to be 0-15 relative to register

calc_cfg_bit:
    	LDR R8, [R5]                 // Load current ICFGR value

    // Calculate 2-bit position: (index * 2)
    	ADD R6, R6, R6               // R6 = index * 2

    // Create Mask (0x3 << position) to clear old value
	    MOV R7, #3
	    LSL R7, R7, R6
	    BIC R8, R8, R7               // Clear both bits for this interrupt

	    CMP R3, #1                   // Check 'edge_trigger' (R3)
	    BNE write_cfg                // If 0 (Level), leave bits cleared (00 is Level)

    // Set Edge (0x2 << position)
	    MOV R7, #2
	    LSL R7, R7, R6
	    ORR R8, R8, R7

write_cfg:
	    STR R8, [R5]

    // ---------------------------------------------------------
    // 4. ROUTE INTERRUPT (GICD_IROUTER)
    // Format: Aff3:Aff2:Aff1:Aff0 (64-bit register)
    // Offset = 0x6000 + (ID * 8). ID = INTn + 32.
    // ---------------------------------------------------------
	    LDR R5, =GICD_IROUTER
	    ADD R5, R4, R5               // R5 = Base + 0x6000
	    ADD R5, R5, #256             // Skip first 32 IDs (SGI/PPI) -> (32 * 8 = 256)
	    ADD R5, R5, R0, LSL #3       // Add INTn * 8

    // Retrieve 'aff' pointer from stack.
    // Argument 5 is at [SP_original].
    // We pushed 6 regs (R4-R8, LR), so SP moved down 24 bytes.
    // aff pointer is at [SP + 24]
	    LDR R6, [SP, #24]            // R6 now holds address of aff array

    // Read affinities from array (assuming uint32 array)
	    LDR R7, [R6]                 // R7 = aff[0] (Aff0)
	    LDR R8, [R6, #4]             // R8 = aff[1] (Aff1)
	    LDR R12, [R6, #8]            // R12= aff[2] (Aff2)

    // Pack into 32-bit Low Word: (Aff2 << 16) | (Aff1 << 8) | Aff0
	    LSL R8, R8, #8
	    ORR R7, R7, R8
	    LSL R12, R12, #16
	    ORR R7, R7, R12              // R7 contains packed Aff2:Aff1:Aff0

	    MOV R6, R7
	    MOV R7, #0                   // High Word (Aff3 = 0, Mode = 0 for SPI)

    // Store 64-bit IROUTER (R7=Low, R8=High)
    	STRD R6, R7, [R5]

    // ---------------------------------------------------------
    // 5. ENABLE INTERRUPT (GICD_ISENABLER)
    // Target: ISENABLER[1] (Offset 0x104)
    // ---------------------------------------------------------
	    ADD R5, R4, #GICD_ISENABLER0
	    ADD R5, R5, #4               // Offset 0x104

	    MOV R6, #1
	    LSL R6, R6, R0               // 1 << INTn
	    STR R6, [R5]                 // Write-1-to-Enable (No read-modify-write needed)

    // Epilogue: Restore registers and return
    	POP {R4-R8, PC}

		.global GIC_enable_SGI_PPI_ASM
		.type GIC_enable_SGI_PPI_ASM, %function

// ------------------------------------------------------------------
// MEMORY MAP CONSTANTS (ADJUST FOR YOUR SOC)
// ------------------------------------------------------------------
// The Redistributor typically has two 64KB frames per core:
// Frame 0: RD_base (Control)
// Frame 1: SGI_base (Interrupts) -> WE NEED THIS ONE
// ------------------------------------------------------------------

	// Base address of Core 0's Redistributor SGI Frame
		.equ GICR_SGI_BASE_C0,  0xAF110000

	// Base address of Core 1's Redistributor SGI Frame
	// (Usually offset by 0x20000 or 0x40000 from Core 0, depending on implementation)
		.equ GICR_SGI_BASE_C1,  0xAF130000

    // Base address of Core 10's Redistributor SGI Frame
        .equ GICR_SGI_BASE_C10, 0xAF150000

    // Base address of Core 11's Redistributor SGI Frame
        .equ GICR_SGI_BASE_C11, 0xAF170000

	// Register Offsets within SGI Frame
		.equ GICR_IGROUPR0,     0x0080
		.equ GICR_ISENABLER0,   0x0100
		.equ GICR_IPRIORITYR,   0x0400
		.equ GICR_ICFGR0,       0x0C00  // SGIs (0-15)
		.equ GICR_ICFGR1,       0x0C04  // PPIs (16-31)

// Arguments (AAPCS)
// R0: INTn
// R1: pri
// R2: fiq
// R3: core_id

//void GIC_enable_SGI_PPI_ASM(uint32_t, uint32_t, uint32_t, uint32_t);
GIC_enable_SGI_PPI_ASM:
    	PUSH {R4-R8, LR}

    // ---------------------------------------------------------
    // 1. SELECT REDISTRIBUTOR BASE ADDRESS
    // ---------------------------------------------------------
	    CMP R3, #1
	    BEQ load_core1_base
        CMP R3, #2
        BEQ load_core10_base
        CMP R3, #3
        BEQ load_core11_base

    // Default to Core 0 (or current core)
	    LDR R4, =GICR_SGI_BASE_C0
	    B base_loaded

load_core1_base:
    	LDR R4, =GICR_SGI_BASE_C1
        B base_loaded

load_core10_base:
        LDR R4, =GICR_SGI_BASE_C10
        B base_loaded

load_core11_base:
        LDR R4, =GICR_SGI_BASE_C11

base_loaded:
    // R4 now holds the SGI_Base address for the target core

    // ---------------------------------------------------------
    // 2. SET PRIORITY (GICR_IPRIORITYR)
    // Offset 0x400. Byte accessible.
    // ---------------------------------------------------------
	    ADD R5, R4, #GICR_IPRIORITYR
	    STRB R1, [R5, R0]           // Mem[Base + 0x400 + INTn] = Priority

    // ---------------------------------------------------------
    // 3. SET GROUP (FIQ vs IRQ) (GICR_IGROUPR0)
    // Offset 0x0080.
    // ---------------------------------------------------------
	    ADD R5, R4, #GICR_IGROUPR0
	    LDR R6, [R5]                // Load current value

	    MOV R7, #1
	    LSL R7, R7, R0              // Create mask: 1 << INTn

	    CMP R2, #0                  // Check 'fiq' arg
	    BNE set_fiq_group

    // Set Group 1 (IRQ)
	    ORR R6, R6, R7
	    B write_group

set_fiq_group:
    // Set Group 0 (FIQ)
    	BIC R6, R6, R7              // Clear bit

write_group:
    	STR R6, [R5]

    // ---------------------------------------------------------
    // 4. CONFIGURATION (Edge/Level)
    // SGIs (0-15) are Read-Only (Always Edge). We only config PPIs (16-31).
    // ---------------------------------------------------------
	    CMP R0, #16
	    BLT skip_config             // If INTn < 16, skip config (SGI)

    // Target: GICR_ICFGR1 (Offset 0xC04)
    	MOV R12, #GICR_ICFGR1
	    ADD R5, R4, R12
	    LDR R6, [R5]                // Load current ICFGR1

    // Logic Fix: Shift must be relative to start of register (INTn - 16)
	    SUB R7, R0, #16             // R7 = Index within register (0-15)
	    LSL R7, R7, #1              // R7 = Bit position (Index * 2)

    // Clear old bits (Mask 0x3 << Shift)
	    MOV R8, #3
	    LSL R8, R8, R7
	    BIC R6, R6, R8

    // We implement the C code's logic: Hardcoded Edge Trigger (0x2)
	    MOV R8, #2                  // 0x2 = Edge Sensitive
	    LSL R8, R8, R7
	    ORR R6, R6, R8              // Apply new config

	    STR R6, [R5]                // Write back

skip_config:
    // ---------------------------------------------------------
    // 5. ENABLE INTERRUPT (GICR_ISENABLER0)
    // Offset 0x0100. Write-1-to-enable.
    // ---------------------------------------------------------
	    ADD R5, R4, #GICR_ISENABLER0

	    MOV R6, #1
	    LSL R6, R6, R0              // 1 << INTn
	    STR R6, [R5]

    // Epilogue
    	POP {R4-R8, PC}
