/*
 * Copyright (c) 2009 Remy Demarest
 * Portions Copyright (c) 2009 David Chisnall
 *
 *  Permission is hereby granted, free of charge, to any person
 *  obtaining a copy of this software and associated documentation
 *  files (the "Software"), to deal in the Software without
 *  restriction, including without limitation the rights to use,
 *  copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following
 *  conditions:
 *
 *  The above copyright notice and this permission notice shall be
 *  included in all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 *  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 *  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 *  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 *  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 *  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 *  OTHER DEALINGS IN THE SOFTWARE.
 */


#ifdef EMBEDDED_BLOCKS_RUNTIME
#import "objc/blocks_runtime.h"
#include "blocks_runtime.h"
#else
#import <Block.h>
#import <Block_private.h>
#endif
#include "visibility.h"


OBJC_PUBLIC const char *block_getType_np(const void *b)
{
	return _Block_signature((void*)b);
}

/**
 * Returns the block pointer, or NULL if the block is already
 * being deallocated. The implementation does not employ atomic 
 * operations, so this function must only be called by the ARC
 * subsystem after obtaining the weak-reference lock.
 */
PRIVATE void* block_load_weak(void *block)
{
	struct Block_layout *self = block;
	#ifdef EMBEDDED_BLOCKS_RUNTIME
	return (self->reserved) > 0 ? block : 0;
	#else
	return (self->flags) & BLOCK_REFCOUNT_MASK ? block : 0;
	#endif
}
