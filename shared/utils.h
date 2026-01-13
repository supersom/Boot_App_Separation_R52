/*
 * utils.h
 *
 *  Created on: Dec 8, 2025
 *  Description: Declarations for utils that are used globally
 *
 *  Copyright (c) C2i Semiconductors.
 *  All rights reserved. This file is part of proprietary firmware and
 *  internal development at C2i Semiconductors. Unauthorized copying,
 *  redistribution, or use of this file in source or binary forms, with or
 *  without modification, is strictly prohibited unless explicit written
 *  permission is granted by C2i Semiconductors.
 *
 * ---------------------------------------------------------------------------*/

#ifndef UTILS_H_
#define UTILS_H_
#include <stdint.h>
#include <stdio.h>

void wait(void);
void getAffinity(uint32_t*, uint32_t*, uint32_t*);
void markCLibraryInitialized(void);
uint32_t isCLibraryInitialized(void);

// Functions to acquire and release the print lock
void lock(volatile uint32_t *lock_var);
void unlock(volatile uint32_t *lock_var);

// Functions for profiling by counting cycles
void init_pmu_cctr(void);
void profile_start_asm(uint32_t *);
uint32_t profile_stop_asm(uint32_t *,uint32_t *,uint32_t *);

#endif /* UTILS_H_ */

