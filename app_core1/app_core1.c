// app.c – second ELF, linked at 0x00800000

#include <stdint.h>
#include <stdio.h>
#include "common_defs.h"
#include "generictimer.h"
#include "spinlock.h"
// #include "../shared/boot_args.h"

// This is the application's entry point.
// void app_entry(void);
extern void app_bootloader(void);

// Define the stack top. This should align with the scatter file.
// RW_APP starts at 0x30020000 and is 0x8000 bytes long.
#define STACK_TOP 0x20028000

// Application's vector table.
// The first entry is the initial stack pointer, the second is the reset handler.
__attribute__((section(".app_vector_table"), used))
const volatile uint32_t app_vector_table[] = {
    STACK_TOP,
    (uint32_t)app_bootloader};

// __attribute__ ((section("BOOT_ARGS"), used))
// volatile boot_args_t* boot_args = (boot_args_t*)BOOT_ARGS_ADDR;

// #define ONESECOND 0xF424
// #define MILLISECOND 0x2DC6C
// #define CNTCONTROLBASE 0xAA430000
#define TIMER1

// extern unsigned int __heap_base_com;

extern void GIC_enableVirtualTimerInterrupt(void);
extern void GIC_enableDualTimer0Interrupt(void);
extern void GIC_enableDualTimer1Interrupt(void);
extern void (*GICIsrVectorTable[1024])(void);

static float calculate(float a, float b);
static void enableSystemCounter(void);
static void waitForEnableSystemCounter(void);
static void enableDualTimer0(unsigned int period);
static void enableDualTimer1(unsigned int period);

void SGI1IRQhandler(void);
void virtualTimerIRQhandler(void);
void DualTimer0INThandler(void);
void DualTimer1INThandler(void);
// void SGI0IRQHandler(void);

// Approximate sleep - highly dependent on CPU clock speed
void sleep_busy_wait(unsigned int iterations)
{
    volatile unsigned int i;
    for (i = 0; i < iterations; i++)
    {
        // Do nothing, just burn cycles
        __asm volatile("nop");
    }
}

// Application entry point.
// __attribute__((used))
// void app_entry(void)
int main(void)
{
    uint32_t mpidr;
    // volatile unsigned int *heap_probe = &__heap_base_com;
    // (void)heap_probe;

    __asm volatile("MRC p15, 0, %0, c0, c0, 5" : "=r"(mpidr));
    uint32_t core_id = mpidr & 0xFF;

    printf("[%s] core_id=%u\n", "app_core1", (unsigned)core_id);

// #ifdef __ARM_FP
//     printf("Floating point calculation using the FPU...\n");
// #else
//     printf("Floating point calculation using the software floating point library (no FPU)...\n");
// #endif
//     printf("Float result is        %f\n", calculate(1.5f, 2.5f));
//     printf("Float result should be 0.937500\n");

//     enableSystemCounter();
//     setCNTV_TVAL(MILLISECOND);
//     enableVirtualTimer();

//     GICIsrVectorTable[1] = SGI1IRQhandler;
//     GICIsrVectorTable[27] = virtualTimerIRQhandler;
//     GIC_enableVirtualTimerInterrupt();

// #ifdef TIMER1
//     GICIsrVectorTable[34] = DualTimer0INThandler;
//     enableDualTimer0(ONESECOND);
//     GIC_enableDualTimer0Interrupt();
// #else
//     enableDualTimer1(0x29aa);
//     GIC_enableDualTimer1Interrupt();
// #endif

//     __asm volatile ("CPSIE if");
    // Simple “I’m alive” loop
    volatile uint32_t counter = 0;
    while (1)
    {
        counter++;
        uint32_t hppir, rpr;
        __asm volatile("MRC p15, 0, %0, c12, c8, 0" : "=r"(hppir)); // ICC_HPPIR0
        __asm volatile("MRC p15, 0, %0, c12, c11, 3" : "=r"(rpr));  // ICC_RPR
        spinlock_printf("\nC01: HPPIR0=0x%x RPR=0x%x\n", hppir, rpr);
        spinlock_printf("C01: CNTPCT @ %u: %llu\n", counter, getCNTPCT());
        sleep_busy_wait(10000000);
    }
}

static float calculate(float a, float b)
{
    float temp1 = a + b;
    float temp2 = a * b;

    return temp2 / temp1;
}

static void enableSystemCounter(void)
{
    volatile uint32_t *cntcr = (volatile uint32_t *)CNTCONTROLBASE;
    *(cntcr + 0x10) = 10;
    *cntcr |= 0x7;
}

static void enableDualTimer0(unsigned int period)
{
    DT_SP804.Timer1Control = 0x0;
    printf("Timer1Control = 0x%x\n", DT_SP804.Timer1Control & 0xEF);
    DT_SP804.Timer1Load = period;
    printf("Timer1Load = 0x%x\n", DT_SP804.Timer1Load);
    DT_SP804.Timer1Control = 0xe2;
    printf("Timer1Control = 0x%x\n", DT_SP804.Timer1Control & 0xEF);
    printf("Timer1RIS = 0x%x\n", DT_SP804.Timer1RIS & 0x1);
}

static void enableDualTimer1(unsigned int period)
{
    DT_SP804.Timer2Control = 0x0;
    printf("Timer2Control = 0x%x\n", DT_SP804.Timer2Control & 0xEF);
    DT_SP804.Timer2Load = period;
    printf("Timer2Load = 0x%x\n", DT_SP804.Timer2Load);
    DT_SP804.Timer2Control = 0xe2;
    printf("Timer2Control = 0x%x\n", DT_SP804.Timer2Control & 0xEF);
    printf("Timer2RIS = 0x%x\n", DT_SP804.Timer2RIS & 0x1);
}

void virtualTimerIRQhandler(void)
{
    setCNTV_TVAL(MILLISECOND);
    sendGroup0SGI(0x01000000 /* ID 1 */, 0x0 /* IRM 0 */, 0x2 /* Target CPU1 */);
}

// void SGI0IRQHandler(void)
// {
//     uint32_t aff0 = 0;
//     uint32_t aff1 = 0;
//     uint32_t aff2 = 0;
//     getAffinity(&aff0, &aff1, &aff2);
// //    spinlock_printf("SGI0IRQHandler: SGI received on core with affinity: %d.%d.%d!\n\n",
// //        aff2, aff1, aff0);
// }

void SGI1IRQhandler(void)
{
    static uint32_t Seconds;
    static uint32_t Minutes;
    static uint32_t Hours;
    static uint32_t ms = 1;

    if (ms==1000)
    {
        ms = 1;

        // update timer
        if (59 == Seconds)
        {
            Seconds = 0;
            if (59 == Minutes)
            {
                Minutes = 0;
                if (23 == Hours)
                {
                    Hours = 0;
                }
                else
                {
                    Hours++;
                }
            }
            else
            {
                Minutes++;
            }
        }
        else
        {
            Seconds++;
        }
        if (Hours >= 10)
        {
            printf("%d",Hours);
        }
        else
        {
            printf("0%d",Hours);
        }
        printf(":");
        if (Minutes >= 10)
        {
            printf("%d",Minutes);
        }
        else
        {
            printf("0%d",Minutes);
        }
        printf(":");
        if (Seconds >= 10)
        {
            printf("%d",Seconds);
        }
        else
        {
            printf("0%d",Seconds);
        }
        printf(": C01: Entered FIQ handler for SGI (1) <- PPI (27) <- VirtualTimer\n");
    }
    else
        ms++;
}

void DualTimer0INThandler(void)
{
    if(GICD.IGROUPR[1])
        printf("C01: Entered IRQ handler for SPI (34) triggered by DualTimer0\n\n");
    else
        printf("C01: Entered FIQ handler for SPI (34) triggered by DualTimer0\n\n");
    DT_SP804.Timer1IntClr = 0x0; // Clear timer interrupt
}

void DualTimer1INThandler(void)
{
    if(GICD.IGROUPR[1])
        printf("C01: Entered IRQ handler for SPI (35) triggered by DualTimer1\n\n");
    else
        printf("C01: Entered FIQ handler for SPI (35) triggered by DualTimer1\n\n");
    DT_SP804.Timer2IntClr = 0x0; // Clear timer interrupt
}
