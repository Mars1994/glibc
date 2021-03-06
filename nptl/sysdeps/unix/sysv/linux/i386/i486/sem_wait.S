/* Copyright (C) 2002-2003, 2005, 2007, 2011-2012 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Ulrich Drepper <drepper@redhat.com>, 2002.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <http://www.gnu.org/licenses/>.  */

#include <sysdep.h>
#include <shlib-compat.h>
#include <pthread-errnos.h>
#include <structsem.h>
#include <lowlevellock.h>


#if VALUE != 0
# error "code needs to be rewritten for VALUE != 0"
#endif

	.text

	.globl	__new_sem_wait
	.type	__new_sem_wait,@function
	.align	16
__new_sem_wait:
.LSTARTCODE:
	pushl	%ebx
.Lpush_ebx:
	pushl	%esi
.Lpush_esi:
	subl	$4, %esp
.Lsub_esp:

	movl	16(%esp), %ebx

	movl	(%ebx), %eax
2:	testl	%eax, %eax
	je	1f

	leal	-1(%eax), %edx
	LOCK
	cmpxchgl %edx, (%ebx)
	jne	2b
7:	xorl	%eax, %eax

9:	movl	4(%esp), %esi
	movl	8(%esp), %ebx
	addl	$12, %esp
.Ladd_esp:
	ret

.Lafter_ret:
1:	LOCK
	incl	NWAITERS(%ebx)

.LcleanupSTART:
6:	call	__pthread_enable_asynccancel
	movl	%eax, (%esp)

#if FUTEX_WAIT == 0
	movl	PRIVATE(%ebx), %ecx
#else
	movl	$FUTEX_WAIT, %ecx
	orl	PRIVATE(%ebx), %ecx
#endif
	xorl	%esi, %esi
	xorl	%edx, %edx
	movl	$SYS_futex, %eax
	ENTER_KERNEL
	movl	%eax, %esi

	movl	(%esp), %eax
	call	__pthread_disable_asynccancel
.LcleanupEND:

	testl	%esi, %esi
	je	3f
	cmpl	$-EWOULDBLOCK, %esi
	jne	4f

3:
	movl	(%ebx), %eax
5:	testl	%eax, %eax
	je	6b

	leal	-1(%eax), %edx
	LOCK
	cmpxchgl %edx, (%ebx)
	jne	5b

	LOCK
	decl	NWAITERS(%ebx)
	jmp	7b

4:	LOCK
	decl	NWAITERS(%ebx)

	negl	%esi
#ifdef PIC
	SETUP_PIC_REG(bx)
#else
	movl	$8f, %ebx
8:
#endif
	addl	$_GLOBAL_OFFSET_TABLE_, %ebx
#ifdef NO_TLS_DIRECT_SEG_REFS
	movl	errno@gotntpoff(%ebx), %edx
	addl	%gs:0, %edx
	movl	%esi, (%edx)
#else
	movl	errno@gotntpoff(%ebx), %edx
	movl	%esi, %gs:(%edx)
#endif
	orl	$-1, %eax

	jmp	9b
	.size	__new_sem_wait,.-__new_sem_wait
	versioned_symbol(libpthread, __new_sem_wait, sem_wait, GLIBC_2_1)


	.type	sem_wait_cleanup,@function
sem_wait_cleanup:
	LOCK
	decl	NWAITERS(%ebx)
	movl	%eax, (%esp)
.LcallUR:
	call	_Unwind_Resume@PLT
	hlt
.LENDCODE:
	.size	sem_wait_cleanup,.-sem_wait_cleanup


	.section .gcc_except_table,"a",@progbits
.LexceptSTART:
	.byte	0xff				# @LPStart format (omit)
	.byte	0xff				# @TType format (omit)
	.byte	0x01				# call-site format
						# DW_EH_PE_uleb128
	.uleb128 .Lcstend-.Lcstbegin
.Lcstbegin:
	.uleb128 .LcleanupSTART-.LSTARTCODE
	.uleb128 .LcleanupEND-.LcleanupSTART
	.uleb128 sem_wait_cleanup-.LSTARTCODE
	.uleb128  0
	.uleb128 .LcallUR-.LSTARTCODE
	.uleb128 .LENDCODE-.LcallUR
	.uleb128 0
	.uleb128  0
.Lcstend:


	.section .eh_frame,"a",@progbits
.LSTARTFRAME:
	.long	.LENDCIE-.LSTARTCIE		# Length of the CIE.
.LSTARTCIE:
	.long	0				# CIE ID.
	.byte	1				# Version number.
#ifdef SHARED
	.string	"zPLR"				# NUL-terminated augmentation
						# string.
#else
	.string	"zPL"				# NUL-terminated augmentation
						# string.
#endif
	.uleb128 1				# Code alignment factor.
	.sleb128 -4				# Data alignment factor.
	.byte	8				# Return address register
						# column.
#ifdef SHARED
	.uleb128 7				# Augmentation value length.
	.byte	0x9b				# Personality: DW_EH_PE_pcrel
						# + DW_EH_PE_sdata4
						# + DW_EH_PE_indirect
	.long	DW.ref.__gcc_personality_v0-.
	.byte	0x1b				# LSDA Encoding: DW_EH_PE_pcrel
						# + DW_EH_PE_sdata4.
	.byte	0x1b				# FDE Encoding: DW_EH_PE_pcrel
						# + DW_EH_PE_sdata4.
#else
	.uleb128 6				# Augmentation value length.
	.byte	0x0				# Personality: absolute
	.long	__gcc_personality_v0
	.byte	0x0				# LSDA Encoding: absolute
#endif
	.byte 0x0c				# DW_CFA_def_cfa
	.uleb128 4
	.uleb128 4
	.byte	0x88				# DW_CFA_offset, column 0x10
	.uleb128 1
	.align 4
.LENDCIE:

	.long	.LENDFDE-.LSTARTFDE		# Length of the FDE.
.LSTARTFDE:
	.long	.LSTARTFDE-.LSTARTFRAME		# CIE pointer.
#ifdef SHARED
	.long	.LSTARTCODE-.			# PC-relative start address
						# of the code.
#else
	.long	.LSTARTCODE			# Start address of the code.
#endif
	.long	.LENDCODE-.LSTARTCODE		# Length of the code.
	.uleb128 4				# Augmentation size
#ifdef SHARED
	.long	.LexceptSTART-.
#else
	.long	.LexceptSTART
#endif

	.byte	4				# DW_CFA_advance_loc4
	.long	.Lpush_ebx-.LSTARTCODE
	.byte	14				# DW_CFA_def_cfa_offset
	.uleb128 8
	.byte   0x83				# DW_CFA_offset %ebx
	.uleb128 2
	.byte	4				# DW_CFA_advance_loc4
	.long	.Lpush_esi-.Lpush_ebx
	.byte	14				# DW_CFA_def_cfa_offset
	.uleb128 12
	.byte   0x86				# DW_CFA_offset %esi
	.uleb128 3
	.byte	4				# DW_CFA_advance_loc4
	.long	.Lsub_esp-.Lpush_esi
	.byte	14				# DW_CFA_def_cfa_offset
	.uleb128 16
	.byte	4				# DW_CFA_advance_loc4
	.long	.Ladd_esp-.Lsub_esp
	.byte	14				# DW_CFA_def_cfa_offset
	.uleb128 4
	.byte	0xc3				# DW_CFA_restore %ebx
	.byte	0xc6				# DW_CFA_restore %esi
	.byte	4				# DW_CFA_advance_loc4
	.long	.Lafter_ret-.Ladd_esp
	.byte	14				# DW_CFA_def_cfa_offset
	.uleb128 16
	.byte   0x83				# DW_CFA_offset %ebx
	.uleb128 2
	.byte   0x86				# DW_CFA_offset %esi
	.uleb128 3
	.align	4
.LENDFDE:


#ifdef SHARED
	.hidden	DW.ref.__gcc_personality_v0
	.weak	DW.ref.__gcc_personality_v0
	.section .gnu.linkonce.d.DW.ref.__gcc_personality_v0,"aw",@progbits
	.align	4
	.type	DW.ref.__gcc_personality_v0, @object
	.size	DW.ref.__gcc_personality_v0, 4
DW.ref.__gcc_personality_v0:
	.long	__gcc_personality_v0
#endif


#if SHLIB_COMPAT(libpthread, GLIBC_2_0, GLIBC_2_1)
	.section ".text.compat", "ax"
	.global	__old_sem_wait
	.type	__old_sem_wait,@function
	.align	16
	cfi_startproc
__old_sem_wait:
	pushl	%ebx
	cfi_adjust_cfa_offset(4)
	pushl	%esi
	cfi_adjust_cfa_offset(4)
	subl	$4, %esp
	cfi_adjust_cfa_offset(4)

	movl	16(%esp), %ebx
	cfi_offset(ebx, -8)

	cfi_offset(esi, -12)
3:	movl	(%ebx), %eax
2:	testl	%eax, %eax
	je	1f

	leal	-1(%eax), %edx
	LOCK
	cmpxchgl %edx, (%ebx)
	jne	2b
	xorl	%eax, %eax

5:	movl	4(%esp), %esi
	movl	8(%esp), %ebx
	addl	$12, %esp
	cfi_restore(ebx)
	cfi_restore(esi)
	cfi_adjust_cfa_offset(-12)
	ret

	cfi_adjust_cfa_offset(12)
	cfi_offset(ebx, -8)
	cfi_offset(esi, -12)
1:	call	__pthread_enable_asynccancel
	movl	%eax, (%esp)

	xorl	%esi, %esi
	movl	$SYS_futex, %eax
	movl	%esi, %ecx
	movl	%esi, %edx
	ENTER_KERNEL
	movl	%eax, %esi

	movl	(%esp), %eax
	call	__pthread_disable_asynccancel

	testl	%esi, %esi
	je	3b
	cmpl	$-EWOULDBLOCK, %esi
	je	3b
	negl	%esi
#ifdef PIC
	SETUP_PIC_REG(bx)
#else
	movl	$4f, %ebx
4:
#endif
	addl	$_GLOBAL_OFFSET_TABLE_, %ebx
#ifdef NO_TLS_DIRECT_SEG_REFS
	movl	errno@gotntpoff(%ebx), %edx
	addl	%gs:0, %edx
	movl	%esi, (%edx)
#else
	movl	errno@gotntpoff(%ebx), %edx
	movl	%esi, %gs:(%edx)
#endif
	orl	$-1, %eax
	jmp	5b
	cfi_endproc
	.size	__old_sem_wait,.-__old_sem_wait
	compat_symbol(libpthread, __old_sem_wait, sem_wait, GLIBC_2_0)
#endif
