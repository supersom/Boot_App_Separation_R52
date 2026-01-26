//-----------------------------------------------------------------------------
// The confidential and proprietary information contained in this file may
// only be used by a person authorised under and to the extent permitted
// by a subsisting licensing agreement from Arm Limited or its affiliates.
//
//             (C) COPYRIGHT 2014 - 2022 Arm Limited or its affiliates.
//                 ALL RIGHTS RESERVED
//
// This entire notice must be reproduced on all copies of this file
// and copies of this file may only be made by a person if such person is
// permitted to do so under the terms of a subsisting license agreement
// from Arm Limited or its affiliates.
//
//     Release Information : Hirzer Processor MP044-r0p1-00rel0
//
//-----------------------------------------------------------------------------

// Load stack definitions
#include "common_defs.h"


                // Align stackheap section on a 4k boundary
                .syntax unified
                .global  __use_two_region_memory
__use_two_region_memory:
                .word   0

//-------------------------------------------------------------------------------
// Heap area
//-------------------------------------------------------------------------------
                .section heap, "aw", %nobits
                .balign STACK_HEAP_ALIGN

                .global  __heap_base_com
                .global  __heap_limit_com

__heap_base_com:
                .space  HEAP_SIZE
__heap_limit_com:

//-------------------------------------------------------------------------------
// Stack area
//-------------------------------------------------------------------------------
// Stack area - parametrized for each core
                .section stack, "aw", %nobits
                .balign STACK_HEAP_ALIGN

                .global  APP_STACK_BASE
                .global  APP_STACK_TOP

APP_STACK_BASE:
                .space  (CORE_STACK_SIZE)
APP_STACK_TOP:

                .global  __initial_sp
                .set     __initial_sp, APP_STACK_TOP

.if 0
// Stack C00 area
                .section stack0, "aw", %nobits
                .balign STACK_HEAP_ALIGN

                .global  __stack_base_c00
                .global  __stack_top_c00

__stack_base_c00:
                .space  (CORE_STACK_SIZE)
__stack_top_c00:

                .global  __initial_sp_c00
__initial_sp_c00:

                .global  __initial_sp
                .set     __initial_sp, __initial_sp_c00

// Stack C01 area
                .section stack1, "aw", %nobits
                .balign STACK_HEAP_ALIGN

                .global  __stack_base_c01
                .global  __stack_top_c01

__stack_base_c01:
                .space  (CORE_STACK_SIZE)
__stack_top_c01:

                .global  __initial_sp_c01
__initial_sp_c01:

// Stack C10 area
                .section stack10, "aw", %nobits
                .balign STACK_HEAP_ALIGN

                .global  __stack_base_c10
                .global  __stack_top_c10

__stack_base_c10:
                .space  (CORE_STACK_SIZE)
__stack_top_c10:

                .global  __initial_sp_c10
__initial_sp_c10:

// Stack C11 area
                .section stack11, "aw", %nobits
                .balign STACK_HEAP_ALIGN

                .global  __stack_base_c11
                .global  __stack_top_c11

__stack_base_c11:
                .space  (CORE_STACK_SIZE)
__stack_top_c11:

                .global  __initial_sp_c11
__initial_sp_c11:

//                .global  __user_thread_space
//__user_thread_space:
//                .space  TLS_SIZE
//
//                .end
.endif