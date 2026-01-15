/*
 * GIC.c
 *
 *  Created on: Nov 15, 2025
 *
 *	Description: This file contains GIC access interfaces for C00.
 *		These interfaces allow the C00 apps to:
 *		- enable & disable SPI, SGI & PPIs,
 *		- enable virtual and dual timer interrupts with using
 *		appropriate interrupt lines
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

#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include "GICv3.h"
#include "v8rgicv3cpuif.h"
#include "utils.h"

void GIC_configure(void);
//void GIC_enable_SPI_IRQ(uint32_t, uint32_t);
//void GIC_enable_SPI_FIQ(uint32_t, uint32_t);
void GIC_enable_SPI(uint32_t, uint32_t, uint32_t, uint32_t, uint32_t *);
void GIC_enable_SGI_PPI(uint32_t, uint32_t, uint32_t, uint32_t);
//void GIC_enable_PPI(uint32_t, uint32_t, uint32_t);

void GIC_enableVirtualTimerInterrupt(void);
void GIC_enableDualTimer0Interrupt(void);
void GIC_enableDualTimer1Interrupt(void);
//void getAffinity(uint32_t *,uint32_t *,uint32_t *);
void unhandled (void); // Dummy ISR for unhandled interrupts
void SGI0IRQHandler(void);

void GIC_configure(void)
{
	GICD.CTLR = 0x13;                          // Enable Group 0, Group 1 distribution and affinity routing
	while ((GICD.CTLR & 0x80000000) != 0x0);   // Poll until bit RWP is cleared
	GICR_RD.WAKER &= 0xFFFFFFFD;               // Clear ProcessorSleep
	// In Cortex-R52 SR interface is enabled by default (RAO, WI)
	//setICC_SRE(0x1);                         // Enable system register interface
	enableGroup0Ints();                        // Enable group 0 interrupts
	enableGroup1Ints();                        // Enable group 1 interrupts
	setPriorityMask(0xFF);                     // Set priority to 0xFF (lowest)
	setBinaryPoint(0x0);                       // Set Group0 binary point (preemption) to gggggggg
	setAliasedBinaryPoint(0x0);                // Set Group1 binary point (preemption) to gggggggg
}

void GIC_enable_SPI(uint32_t INTn, uint32_t pri, uint32_t fiq, uint32_t edge_trigger, uint32_t *aff)
{
	assert(INTn < 32 && "Function has to be modified if INTn >= 32");
	GICD.IPRIORITYR[INTn+32] = pri;             // priority
	if(fiq)
		GICD.IGROUPR[1]  		&= ~(0x1 << INTn);
	else
		GICD.IGROUPR[1]         |=  (0x1 << INTn);     // group 1 (first 32 SPIs configured in this register)

	if(edge_trigger == 1)
		GICD.ICFGR[2] |= 0x2 << (2*INTn);    	// SPI edge sensitive
	else
		GICD.ICFGR[2] &= ~(0x2 << (2*INTn));	// SPI level sensitive

	// Route INT to CPU at aff2.aff1.aff0
//	GICD.IROUTER[INTn+32]    = 0x00FFFFFF && aff[0] && (aff[1] << 8) && (aff[2] << 16);
	GICD.IROUTER[INTn+32] = 0x00FFFFFF && ((aff[0]) | (aff[1] << 8) | (aff[2] << 16));
	GICD.ISENABLER[1]       |= 0x1 << INTn;     // enable interrupt (first 32 SPIs configured in this register)
	printf("SPI: %d enabled on core: %d.%d.%d as %s with priority: %d\n", INTn, aff[2], aff[1], aff[0], fiq?"FIQ":"IRQ", pri);
}

void GIC_disable_SPI(uint32_t INTn)
{
	assert(INTn < 32 && "Function has to be modified if INTn >= 32");
	GICD.ICENABLER[1]        = 0x1 << INTn;     // disable interrupt (first 32 SPIs configured in this register)
	printf("SPI: %d disabled\n", INTn);
}

void GIC_enable_SGI_PPI(uint32_t INTn, uint32_t pri, uint32_t fiq, uint32_t core_id)
{
	assert(INTn < 32 && INTn >= 0 && "SGI/PPI: 0 <= INTn < 32");
	if(core_id == 1) {
		GICR_SGI_C01.IPRIORITYR[INTn] = pri;             // Set priority SGI[INTn]
		if(fiq)
			GICR_SGI_C01.IGROUPR0  &= ~(0x1 << INTn);
		else
			GICR_SGI_C01.IGROUPR0  |=  (0x1 << INTn);
		if(INTn<16)
			// All SGIs are edge triggered. Asserting that.
			assert(GICR_SGI_C01.ICFGR[0] == 0xAAAAAAAA && "enable SGI: Illegal ICFGR value");
		else {
			uint32_t PPI_trigger = 1;
			if(PPI_trigger == 1)
				GICR_SGI_C01.ICFGR[1] |= 0x2 << (2*INTn);    	// PPI edge sensitive
			else
				GICR_SGI_C01.ICFGR[1] &= ~(0x2 << (2*INTn));	// PPI level sensitive
		}
		GICR_SGI_C01.ISENABLER0 |= (0x1 << INTn);   // Enable SGI/PPI
	}
	else {
		GICR_SGI.IPRIORITYR[INTn] = pri;             // Set priority SGI/PPI[INTn]
		if(fiq)
			GICR_SGI.IGROUPR0  &= ~(0x1 << INTn);
		else
			GICR_SGI.IGROUPR0  |=  (0x1 << INTn);
		if(INTn<16)
			// All SGIs are edge triggered. Asserting that.
			assert(GICR_SGI.ICFGR[0] == 0xAAAAAAAA && "enable SGI: Illegal ICFGR value");
		else {
			uint32_t PPI_trigger = 1;
			if(PPI_trigger == 1)
				GICR_SGI.ICFGR[1] |= 0x2 << (2*INTn);    	// PPI edge sensitive
			else
				GICR_SGI.ICFGR[1] &= ~(0x2 << (2*INTn));	// PPI level sensitive
		}
		GICR_SGI.ISENABLER0 |= (0x1 << INTn);   // Enable SGI/PPI
	}
	printf("%s: %d enabled on core: %d as %s with priority: %d\n", INTn<16?"SGI":"PPI", INTn, core_id, fiq?"FIQ":"IRQ", pri);
}

void GIC_disable_SGI_PPI(uint32_t INTn, uint32_t core_id)
{
	if(core_id == 0)
		GICR_SGI.ICENABLER        	= 0x1 << INTn;     // disable interrupt
	else
		GICR_SGI_C01.ICENABLER		= 0x1 << INTn;     // disable interrupt
	printf("%s: %d disabled on core: %d\n", INTn<16?"SGI":"PPI", INTn, core_id);
}

void GIC_enableVirtualTimerInterrupt(void)
{
	GIC_enable_SGI_PPI(1, 0x3F, 0, 0); //(INTn, priority, FIQ, core_id)
	GIC_enable_SGI_PPI(27, 0x7F, 0, 0); //(INTn, priority, FIQ, core_id)
}

void GIC_enableDualTimer0Interrupt(void)
{
	uint32_t SPI_ID = 2;
	uint32_t aff[3] = {1, 0, 0}; // targeting core 0, but init to core 1 for robustness
	getAffinity(&aff[0],&aff[1],&aff[2]);
	printf("Setting up INT (DualTimer0) from and targeting Core %d.%d.%d\n",aff[2],aff[1],aff[0]);
	GIC_enable_SPI(SPI_ID, 0x1F, 0x1, 0x1, aff); // (INTn, priority, FIQ, edge_trigger, affinity)
}

void GIC_enableDualTimer1Interrupt(void)
{
	uint32_t SPI_ID = 3;
	uint32_t aff[3] = {1, 0, 0}; // targeting core 0, but init to core 1 for robustness
	getAffinity(&aff[0],&aff[1],&aff[2]);
	printf("Setting up INT (DualTimer1) from and targeting Core %d.%d.%d\n",aff[2],aff[1],aff[0]);
	GIC_enable_SPI(SPI_ID, 0x1F, 0, 1, aff); // (INTn, priority, FIQ, edge_trigger, affinity)
}

// Dummy function which is entered (ISR) if any non-used vector is called.
void unhandled (void) {
    while (1){};
}

void SGI0IRQHandler()
{
	uint32_t aff0 = 0;
	uint32_t aff1 = 0;
	uint32_t aff2 = 0;
    getAffinity(&aff0, &aff1, &aff2);
//    spinlock_printf("SGI0IRQHandler: SGI received on core with affinity: %d.%d.%d!\n\n",
//        aff2, aff1, aff0);
}
