#define ARGUMENT_SPILL_SIZE (10*8 + 8*8)

.macro MSGSEND receiver, sel
	.cfi_startproc
	beqz \receiver, 3f	 	 // Skip everything if receiver is nil

	andi t0, \receiver, SMALLOBJ_MASK
	bnez t0, 5f

	ld t0, 0(\receiver)    	 // Load class into t0
0:
	ld t0, DTABLE_OFFSET(t0) // dtable -> t0
	ld t1, 0(\sel) 	 	 	 // selector->index -> t1
	ld t2, SHIFT_OFFSET(t0)	 // dtable->shift -> t2

	li t3, 8
	beq t2, t3, 1f
	beqz t2, 2f

	srli t2, t1, 16-3	 	 // Extract byte 3 of sel index and multiply by 2^3
	and t2, t2, 0x7F8	 	 // Mask target byte
				 			 // Example: ((0xCAFEBA >> 13) & 0x7f8) == (0xCA << 3)
	add t2, t0, t2		 	 // t2 = dtable address + offset
	ld t0, DATA_OFFSET(t2)   // Load, adding in the data offset
1:
	srli t2, t1, 8-3	 	 // Extract byte 2 of sel index and multiply by 2^3
	and t2, t2, 0x7F8	 	 // Mask target byte
	add t2, t0, t2		 	 // t2 = dtable address + offset
	ld t0, DATA_OFFSET(t2)   // Load, adding in the data offset
2:
	slli t2, t1, 3	 	 	 // Multiply by 2^3
	and t2, t2, 0x7F8	 	 // Mask target byte
	add t2, t0, t2		 	 // t2 = dtable address + offset
	ld t0, DATA_OFFSET(t2)   // Load, adding in the data offset
				 	    	 // Slot pointer is now in t0

	beqz t0, 4f              // If the slot is nil, go to the C path

	ld t0, SLOT_OFFSET(t0)   // Load the method from the slot
	jalr zero, t0, 0 	 	 // Tail-call the method

3:
	li \receiver, 0
	li \sel, 0
	fmv.d.x fa0, zero
	fmv.d.x fa1, zero
	jalr zero, ra, 0

4:
	add sp, sp, -(ARGUMENT_SPILL_SIZE)

	// Spill function arguments
	sd a0, 0(sp)
	sd a1, 8(sp)
	sd a2, 16(sp)
	sd a3, 24(sp)
	sd a4, 32(sp)
	sd a5, 40(sp)
	sd a6, 48(sp)
	sd a7, 56(sp)

	// Spill FP arguments
	fsd fa0, 64(sp)
	fsd fa1, 72(sp)
	fsd fa2, 80(sp)
	fsd fa3, 88(sp)
	fsd fa4, 96(sp)
	fsd fa5, 104(sp)
	fsd fa6, 112(sp)
	fsd fa7, 120(sp)

	sd fp, 128(sp)
	sd ra, 136(sp)

	add fp, sp, 128
	add sp, sp, -16

	sd \receiver, 0(sp) 	// it is convenient if \receiver is spilled at sp
	
	.cfi_def_cfa fp, 16
	.cfi_offset fp, -16
	.cfi_offset ra, -8
	
	add a0, sp, zero 	    // &self in first argument
	call CDECL(slowMsgLookup)
	
	add t0, a0, zero 		// IMP -> t0
	
	ld a0, 16(sp)
	ld a1, 24(sp)
	ld a2, 32(sp)
	ld a3, 40(sp)
	ld a4, 48(sp)
	ld a5, 56(sp)
	ld a6, 64(sp)
	ld a7, 72(sp)
	
	fld fa0, 80(sp)
	fld fa1, 88(sp)
	fld fa2, 96(sp)
	fld fa3, 104(sp)
	fld fa4, 112(sp)
	fld fa5, 120(sp)
	fld fa6, 128(sp)
	fld fa7, 136(sp)
	
	ld fp, 144(sp)
	ld ra, 152(sp)
	
	ld \receiver, 0(sp)

	add sp, sp, ARGUMENT_SPILL_SIZE
	add sp, sp, 16
	
	jalr zero, t0, 0 	// Tail-call the method

5:
	// Load address of SmallObjectClasses
	auipc t1, %pcrel_hi(CDECL(SmallObjectClasses))
	addi t1, t1, %pcrel_lo(5b)

	// Calculate array offset (INDEX * 2^3)
	slli t0, t0, 3
	add t0, t1, t0

	ld t0, 0(t0)

	j 0b
	.cfi_endproc
.endm

.globl CDECL(objc_msgSend_fpret)
TYPE_DIRECTIVE(CDECL(objc_msgSend_fpret), %function)
.globl CDECL(objc_msgSend)
TYPE_DIRECTIVE(CDECL(objc_msgSend), %function)
.globl CDECL(objc_msgSend_stret)
CDECL(objc_msgSend):
CDECL(objc_msgSend_fpret):
	MSGSEND a0, a1
CDECL(objc_msgSend_stret):
	MSGSEND a1, a2 // Pointer to stack frame in a0
