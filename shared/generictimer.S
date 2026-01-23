/*
 * SPDX-FileCopyrightText: Copyright 2016-2025 Arm Limited and/or its affiliates <open-source-office@arm.com>
 * SPDX-License-Identifier: MIT
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */


	.section  generictimer,"ax"
#ifdef __THUMB__
	.thumb
#endif

	.global setCNTFRQ
	.type setCNTFRQ, %function
setCNTFRQ:							// Arguments: system counter clock frequency, in Hz
  mcr p15, 0, r0, c14, c0, 0 		// Write r0 to CNTFRQ
  bx lr

	.global getCNTFRQ
	.type getCNTFRQ, %function
getCNTFRQ:							// Return: system counter clock frequency, in Hz
  mrc p15, 0, r0, c14, c0, 0		// Read CNTFRQ into r0
  bx lr

	.global getCNTPCT
	.type getCNTPCT, %function
getCNTPCT:							// Return: low and high word
  mrrc p15, 0, r0, r1, c14 			// Read 64-bit CNTPCT into r0 (low word) and r1 (high word)
  bx lr

	.global setCNTP_TVAL
	.type setCNTP_TVAL, %function
setCNTP_TVAL:						// Arguments: physical timer value
  mcr p15, 0, r0, c14, c2, 0 		// Write r0 to CNTP_TVAL
  bx lr

	.global getCNTP_TVAL
	.type getCNTP_TVAL, %function
getCNTP_TVAL:						// Return: physical timer value
  mrc p15, 0, r0, c14, c2, 0		// Read CNTP_TVAL into r0
  bx lr

	.global setCNTV_TVAL
	.type setCNTV_TVAL, %function
setCNTV_TVAL:						// Arguments: virtual timer value
  mcr p15, 0, r0, c14, c3, 0 		// Write r0 to CNTV_TVAL
  bx lr

	.global getCNTV_TVAL
	.type getCNTV_TVAL, %function
getCNTV_TVAL:						// Return: virtual timer value
  mrc p15, 0, r0, c14, c3, 0		// Read CNTV_TVAL into r0
  bx lr

	.global enablePhyTimer
	.type enablePhyTimer, %function
enablePhyTimer:
  ldr r0, =0x1						// Enable timer
  mcr p15, 0, r0, c14, c2, 1  		// Write r0 to CNTP_CTL
  bx lr

	.global disablePhyTimer
	.type disablePhyTimer, %function
disablePhyTimer:
  ldr r0, =0x0						// Disable timer
  mcr p15, 0, r0, c14, c2, 1  		// Write r0 to CNTP_CTL
  bx lr

	.global enableVirtualTimer
	.type enableVirtualTimer, %function
enableVirtualTimer:
  ldr r0, =0x1						// Enable timer
  mcr p15, 0, r0, c14, c3, 1 		// Write r0 to CNTV_CTL
  bx lr

	.global disableVirtualTimer
	.type disableVirtualTimer, %function
disableVirtualTimer:
  ldr r0, =0x0						// Disable timer
  mcr p15, 0, r0, c14, c3, 1 		// Write r0 to CNTV_CTL
  bx lr

	.global setCNTP_CVAL
	.type setCNTP_CVAL, %function
setCNTP_CVAL:						// Arguments: low and high word
  mcrr p15, 2, r0, r1, c14			// Write r0 (low word) and r1 (high word) to 64-bit CNTP_CVAL
  bx lr

	.global getCNTP_CVAL
	.type getCNTP_CVAL, %function
getCNTP_CVAL:						// Return: low and high word
  mrrc p15, 2, r0, r1, c14			// Read 64-bit CNTP_CVAL into r0 (low word) and r1 (high word)
  bx lr

	.global setCNTV_CVAL
	.type setCNTV_CVAL, %function
setCNTV_CVAL:						// Arguments: low and high word
  mcrr p15, 3, r0, r1, c14			// Write r0 (low word) and r1 (high word) to 64-bit CNTV_CVAL
  bx lr

	.global getCNTV_CVAL
	.type getCNTV_CVAL, %function
getCNTV_CVAL:						// Return: low and high word
  mrrc p15, 3, r0, r1, c14			// Read 64-bit CNTV_CVAL into r0 (low word) and r1 (high word)
  bx lr

	.global setCNTVOFF
	.type setCNTVOFF, %function
setCNTVOFF:							// Arguments: low and high word
  mcrr p15, 4, r0, r1, c14			// Write r0 (low word) and r1 (high word) to 64-bit CNTVOFF
  bx lr

	.global getCNTVOFF
	.type getCNTVOFF, %function
getCNTVOFF:							// Return: low and high word
  mrrc p15, 4, r0, r1, c14			// Read 64-bit CNTVOFF into r0 (low word) and r1 (high word)
  bx lr

	.global setCNTHP_TVAL
	.type setCNTHP_TVAL, %function
setCNTHP_TVAL:						// Arguments: virtual timer value
  mcr p15, 4, r0, c14, c2, 0 		// Write r0 to CNTHP_TVAL
  bx lr

	.global getCNTHP_TVAL
	.type getCNTHP_TVAL, %function
getCNTHP_TVAL:						// Return: virtual timer value
  mrc p15, 4, r0, c14, c2, 0		// Read CNTHP_TVAL into r0
  bx lr

	.global enableHypTimer
	.type enableHypTimer, %function
enableHypTimer:
  ldr r0, =0x1						// Enable timer
  mcr p15, 4, r0, c14, c1, 0  		// Write r0 to CNTHP_CTL
  bx lr

	.global disableHypTimer
	.type disableHypTimer, %function
disableHypTimer:
  ldr r0, =0x0						// Disable timer
  mcr p15, 4, r0, c14, c1, 0  		// Write r0 to CNTHP_CTL
  bx lr

	.global setCNTHP_CVAL
	.type setCNTHP_CVAL, %function
setCNTHP_CVAL:						// Arguments: low and high word
  mcrr p15, 6, r0, r1, c14			// Write r0 (low word) and r1 (high word) to 64-bit CNTHP_CVAL
  bx lr

	.global getCNTHP_CVAL
	.type getCNTHP_CVAL, %function
getCNTHP_CVAL:						// Return: low and high word
  mrrc p15, 6, r0, r1, c14			// Read 64-bit CNTHP_CVAL into r0 (low word) and r1 (high word)
  bx lr
