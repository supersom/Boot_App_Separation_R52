/*
** Copyright (C) Arm Limited, 2017. All rights reserved.
*/

#include "types.h"

#ifndef DUAL_TIMER_H_
#define DUAL_TIMER_H_

#define DUALTIMER0BASE 0x9C110000
#define DUALTIMER1BASE 0x9C120000
/*========================================================================*/
/*  Struct for Dual Timer (SP804) registers */
/*========================================================================*/

struct Dual_Timer_SP804
{
        v_uint32 Timer1Load;       // +0x00 - RW - Data register
  const v_uint32 Timer1Value;      // +0x04 - RO - Value register
        v_uint32 Timer1Control;    // +0x08 - RW - Load register
        v_uint32 Timer1IntClr;     // +0x0C - WO - Interrupt clear register
  const v_uint32 Timer1RIS;        // +0x10 - RO - Raw interrupt status register
  const v_uint32 Timer1MIS;        // +0x14 - RO - Masked interrupt status register
        v_uint32 Timer1BGLoad;     // +0x18 - RW - Background load register
        v_uint32 Timer2Load;       // +0x20 - RW - Data register
  const v_uint32 Timer2Value;      // +0x24 - RO - Value register
        v_uint32 Timer2Control;    // +0x28 - RW - Load register
        v_uint32 Timer2IntClr;     // +0x2C - WO - Interrupt clear register
  const v_uint32 Timer2RIS;        // +0x30 - RO - Raw interrupt status register
  const v_uint32 Timer2MIS;        // +0x34 - RO - Masked interrupt status register
        v_uint32 Timer2BGLoad;     // +0x38 - RW - Background load register
};

#define DT_SP804            (*(volatile struct Dual_Timer_SP804 *)     DUALTIMER0BASE)

#define DT_SP804_2            (*(volatile struct Dual_Timer_SP804 *)     DUALTIMER1BASE)

#endif /* DUAL_TIMER_H_ */
