/*
 * common_defs.h
 *
 *  Created on: Nov 11, 2025
 *  Description: #defines and typdefs that are used globally
 *
 *  Copyright (c) C2i Semiconductors.
 *  All rights reserved. This file is part of proprietary firmware and
 *  internal development at C2i Semiconductors. Unauthorized copying,
 *  redistribution, or use of this file in source or binary forms, with or
 *  without modification, is strictly prohibited unless explicit written
 *  permission is granted by C2i Semiconductors.
 *
 * ---------------------------------------------------------------------------*/

#ifndef COMMON_DEFS_H_
#define COMMON_DEFS_H_

// #define DISABLE_PRINTF
// #ifdef DISABLE_PRINTF
// // Redefine printf after including its prototype to avoid macro clashes
// #include <stdio.h>
// #undef printf
// #define printf(...) ((void)0)
// #endif

// MPU region defines

// Protection Region Base Address Register
#define Execute_Never 0b1         // Bit 0
#define RW_Access 0b01            // AP[2:1]
#define RO_Access 0b11
#define Non_Shareable 0b00        // SH[1:0]
#define Outer_Shareable 0b10
#define Inner_Shareable 0b11

// Protection Region Limit Address Register
#define ENable 0b1                // Bit 0
#define AttrIndx0 0b000           // AttrIndx[2:0]
#define AttrIndx1 0b001
#define AttrIndx2 0b010
#define AttrIndx3 0b011
#define AttrIndx4 0b100
#define AttrIndx5 0b101
#define AttrIndx6 0b110
#define AttrIndx7 0b111

//----------------------------------------------------------------

// Standard definitions of mode bits and interrupt (I & F) flags in PSRs
#define Mode_USR 0x10
#define Mode_FIQ 0x11
#define Mode_IRQ 0x12
#define Mode_SVC 0x13
#define Mode_MON 0x16
#define Mode_ABT 0x17
#define Mode_UND 0x1B
#define Mode_SYS 0x1F
#define Mode_HYP 0x1A

#define I_Bit 0x80 // when I bit is set, IRQ is disabled
#define F_Bit 0x40 // when F bit is set, FIQ is disabled
#define SPURIOUSID 0x3FF

// Constants
#define ONESECOND 0xF4240       //assuming 1MHz SP804 clock
#define MILLISECOND 0x186A0 //0x2DC6C0		//100000 assuming 100MHz
#ifdef FVP_FAST_MODEL
#define SYSTEM_COUNTER_FREQUENCY 0x5F5E100      // = 100MHz
#else
#define SYSTEM_COUNTER_FREQUENCY 0x493E0      	// = 300KHz
#endif

// CPU IDs
#define CPU_ID_00   0x0
#define CPU_ID_01   0x1
#define CPU_ID_10   0x2
#define CPU_ID_11   0x3
//----------------------------------------------------------------

#define    MB             1048576                         	// One megabyte
#define    KB             1024                            	// One kilobyte
#define    MAX_CORES      1
#define    CONTEXTS       8								// Exception modes

#ifndef STACK_HEAP_ALIGN
#define    STACK_HEAP_ALIGN     (1 * KB)                   // 0x00001000
#endif

#ifndef HEAP_SIZE
#define    HEAP_SIZE      (0x10 * KB)                      // 16KB for Shared Heap
#endif

#ifndef STACK_SIZE
#define    STACK_SIZE (1 * KB)                        		// 1KB per Stack
#endif

#define    CORE_STACK_SIZE     (STACK_SIZE * CONTEXTS)  	// Total for all Stacks on a core

#define TCMSIZECODE 0x5 // 16KB // 2^(TCMSIZECODE+9)
#define TCMSIZEBITS (TCMSIZECODE+9)
#define CTCMSIZECODE 0x4 //8KB
#define CTCMSIZEBITS (CTCMSIZECODE+9)

#define EXT_IP_BASE 0x9A000000
#define EXT_IP_SIZE 0x05FFFFC0
#define EXT_IP_LIMIT (EXT_IP_BASE + EXT_IP_SIZE)

#define GIC_TIMERS_BASE 0xAA000000
#define GIC_TIMERS_SIZE 0x05FFFFC0
#define GIC_TIMERS_LIMIT (GIC_TIMERS_BASE + GIC_TIMERS_SIZE)

#define CNTCONTROLBASE 0xAA430000

#define USE_EL1_MPU
//#define USE_EL2_MPU
//#define SINGLE_CORE_BOOT
#define FVP_FAST_MODEL
#define ENABLE_R52_SPECIFIC_CONFIG
#define TCM
#define DISABLE_APPLICATION_INTERRUPT

#ifdef DISABLE_APPLICATION_INTERRUPT
#define PPI_STOP_SEC 500
#define SPI_STOP_SEC PPI_STOP_SEC/2
#endif //DISABLE_APPLICATION_INTERRUPT

#endif /* COMMON_DEFS_H_ */
