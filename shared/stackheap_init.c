#include <stdint.h>
#include <rt_misc.h> /* for __value_in_regs */
#include "common_defs.h"

/* Per-core symbols coming from stackheap.s */
extern unsigned int APP_STACK_BASE, APP_STACK_TOP;
extern unsigned int __heap_base_com, __heap_limit_com;
/*
extern unsigned int __stack_base_c00, __stack_top_c00;
extern unsigned int __stack_base_c01, __stack_top_c01;
extern unsigned int __stack_base_c10, __stack_top_c10;
extern unsigned int __stack_base_c11, __stack_top_c11;
*/
/* Prototype required by Arm C Library */
struct __initial_stackheap __user_initial_stackheap(
        unsigned R0, unsigned SP, unsigned R2, unsigned R3)
{
    struct __initial_stackheap config;

    config.heap_base  = (uint32_t)&__heap_base_com;
    config.stack_base = (uint32_t)&APP_STACK_TOP;
    config.heap_limit = (uint32_t)&__heap_limit_com;
    config.stack_limit = (uint32_t)&APP_STACK_BASE;

/*    
    uint32_t mpidr;

    // Read MPIDR Affinity Level 0
    __asm volatile("MRC p15, 0, %0, c0, c0, 5" : "=r" (mpidr));
    uint32_t core_id = mpidr & 0xFF;

    if (core_id == CPU_ID_00)
    {
        // Core 0 stack & heap (ATCM_C00 or wherever scatter places them)
        config.heap_base  = (uint32_t)&__heap_base_com;
        config.stack_base = (uint32_t)&__stack_top_c00;
        config.heap_limit = (uint32_t)&__heap_limit_com;
        config.stack_limit = (uint32_t)&__stack_base_c00;
    }
    else if (core_id == CPU_ID_01)
    {
        // Core 01 stack & heap (ATCM_C01 or wherever scatter places them)
        config.heap_base  = (uint32_t)&__heap_base_com;
        config.stack_base = (uint32_t)&__stack_top_c01;
        config.heap_limit = (uint32_t)&__heap_limit_com;
        config.stack_limit = (uint32_t)&__stack_base_c01;
    }
    else if (core_id == CPU_ID_10)
    {
        // Core 10 stack & heap (ATCM_C10 or wherever scatter places them)
        config.heap_base  = (uint32_t)&__heap_base_com;
        config.stack_base = (uint32_t)&__stack_top_c10;
        config.heap_limit = (uint32_t)&__heap_limit_com;
        config.stack_limit = (uint32_t)&__stack_base_c10;
    }
    else if (core_id == CPU_ID_11)
    {
        // Core 11 stack & heap (ATCM_C11 or wherever scatter places them)
        config.heap_base  = (uint32_t)&__heap_base_com;
        config.stack_base = (uint32_t)&__stack_top_c11;
        config.heap_limit = (uint32_t)&__heap_limit_com;
        config.stack_limit = (uint32_t)&__stack_base_c11;
    }
*/    
    return config;
}
