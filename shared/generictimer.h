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


#ifndef GENERICTIMER_H_
#define GENERICTIMER_H_

void setCNTFRQ(unsigned int value);
unsigned int getCNTFRQ(void);
unsigned long long getCNTPCT(void);
void setCNTP_TVAL(unsigned int value);
unsigned int getCNTP_TVAL(void);
void setCNTV_TVAL(unsigned int value);
unsigned int getCNTV_TVAL(void);
void enablePhyTimer(void);
void disablePhyTimer(void);
void enableVirtualTimer(void);
void disableVirtualTimer(void);
void setCNTP_CVAL(unsigned long long value);
unsigned long long getCNTP_CVAL(void);
void setCNTV_CVAL(unsigned long long value);
unsigned long long getCNTV_CVAL(void);
void setCNTHP_TVAL(unsigned int value);
unsigned int getCNTHP_TVAL(void);
void enableHypTimer(void);
void disableHypTimer(void);
void setCNTHP_CVAL(unsigned long long value);
unsigned long long getCNTHP_CVAL(void);

#endif /* GENERICTIMER_H_ */
