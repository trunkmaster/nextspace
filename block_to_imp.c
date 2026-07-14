// On some platforms, we need _GNU_SOURCE to expose asprintf()
#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <ctype.h>
#ifndef _WIN32
#include <unistd.h>
#include <sys/types.h>
#include <sys/mman.h>
#else
#include "safewindows.h"
#endif
#include "objc/runtime.h"
#include "objc/blocks_runtime.h"
#include "blocks_runtime.h"
#include "lock.h"
#include "visibility.h"

#ifndef __has_builtin
#define __has_builtin(x) 0
#endif

#if defined(_WIN32)
long pagesize(void)
{
  SYSTEM_INFO si;
  GetSystemInfo(&si);

  DWORD page_size = si.dwPageSize;
  assert(page_size <= INT_MAX);

  return (int)page_size;
}
#else
long pagesize(void)
{
    return sysconf(_SC_PAGESIZE);
}
#endif // defined(_WIN32)

#if defined(_WIN32) && (defined(__arm__) || defined(__aarch64__))
    static inline void __clear_cache(void* start, void* end) {
        FlushInstructionCache(GetCurrentProcess(), start, end - start);
    }
    #define clear_cache __clear_cache
#elif __has_builtin(__builtin___clear_cache)
    #define clear_cache __builtin___clear_cache
#else
    void __clear_cache(void* start, void* end);
    #define clear_cache __clear_cache
#endif


/* QNX needs a special header for asprintf() */
#ifdef __QNXNTO__
#include <nbutil.h>
#endif

#ifdef _WIN32
#if defined(WINAPI_FAMILY) && WINAPI_FAMILY != WINAPI_FAMILY_DESKTOP_APP && _WIN32_WINNT >= 0x0A00
// Prefer the *FromApp versions when we're being built in a Windows Store App context on
// Windows >= 10. *FromApp require the application to be manifested for "codeGeneration".
#define VirtualAlloc VirtualAllocFromApp
#define VirtualProtect VirtualProtectFromApp
#endif // App family partition

#ifndef PROT_READ
#define PROT_READ  0x4
#endif

#ifndef PROT_WRITE
#define PROT_WRITE 0x2
#endif

#ifndef PROT_EXEC
#define PROT_EXEC  0x1
#endif

static int mprotect(void *buffer, size_t len, int prot)
{
	DWORD oldProt = 0, newProt = PAGE_NOACCESS;
	// Windows doesn't offer values that can be ORed together...
	if ((prot & PROT_WRITE))
	{
		// promote to readwrite as there's no writeonly protection constant
		newProt = PAGE_READWRITE;
	}
	else if ((prot & PROT_READ))
	{
		newProt = PAGE_READONLY;
	}

	if ((prot & PROT_EXEC))
	{
		switch (newProt)
		{
			case PAGE_NOACCESS: newProt = PAGE_EXECUTE; break;
			case PAGE_READONLY: newProt = PAGE_EXECUTE_READ; break;
			case PAGE_READWRITE: newProt = PAGE_EXECUTE_READWRITE; break;
		}
	}

	return 0 != VirtualProtect(buffer, len, newProt, &oldProt);
}
#else
#	ifndef MAP_ANONYMOUS
#		define MAP_ANONYMOUS MAP_ANON
#	endif
#endif

struct block_header
{
	void *block;
	void(*fnptr)(void);
	/*
	 * On 64-bit platforms, we have 16 bytes for instructions, which ought to
	 * be enough without padding.
	 * Note: If we add too much padding, then we waste space but have no other
	 * ill effects.  If we get this too small, then the assert in
	 * `init_trampolines` will fire on library load.
	 *
	 * PowerPC: We need INSTR_CNT * INSTR_LEN = 7*4 = 28 bytes
	 * for instruction. sizeof(block_header) must be a divisor of
	 * PAGE_SIZE, so we need to pad block_header to 32 bytes.
	 * On PowerPC 64-bit where sizeof(void *) = 8 bytes, we
	 * add 16 bytes of padding.
	 */
#if defined(__i386__) || (defined(__mips__) && !defined(__mips_n64)) || (defined(__powerpc__) && !defined(__powerpc64__))
	uint64_t padding[3];
#elif defined(__mips__) || defined(__ARM_ARCH_ISA_A64) || defined(__powerpc64__)
	uint64_t padding[2];
#elif defined(__arm__)
	uint64_t padding;
#endif
};

struct trampoline_set
{
	/*
	* Each trampoline loads its block and target method address
	* from the corresponding block_header
	* (one page before the start of the block structure).
	*
	* Page | Description
	*    1 | Page filled with block_header's
	*    2 | RX buffer page
	*/
	char  *region;
	struct trampoline_set *next;
	int first_free;
};


/*
 * Current page size of the system in bytes.
 * Set in init_trampolines.
 */
static int trampoline_page_size;
/*
 * Number of block_header's per page.
 * Calculated in init_trampolines after retrieving the current page size:
 */
static size_t trampoline_header_per_page;
/*
 * Size of a trampoline region in bytes.
 */
static size_t trampoline_region_size;
static mutex_t trampoline_lock;

/*
 * Size of the trampoline region (in pages)
 */
#define TRAMPOLINE_REGION_PAGES 2

#define REGION_HEADERS_START(metadata) ((struct block_header *) metadata->region)
#define REGION_RX_BUFFER_START(metadata) (metadata->region + trampoline_page_size)

struct wx_buffer
{
	void *w;
	void *x;
};
extern char __objc_block_trampoline;
extern char __objc_block_trampoline_end;
extern char __objc_block_trampoline_sret;
extern char __objc_block_trampoline_end_sret;

#if defined(__ARM_ARCH_ISA_A64)
extern char __objc_block_trampoline_16;
extern char __objc_block_trampoline_end_16;
extern char __objc_block_trampoline_sret_16;
extern char __objc_block_trampoline_end_sret_16;
#endif

// Cache the correct trampoline region
static void *trampoline_start;
static void *trampoline_end;
static void *trampoline_start_sret;
static void *trampoline_end_sret;

PRIVATE void init_trampolines(void)
{
	// Retrieve the page size
	#if defined(__powerpc64__)
	// For PowerPC we fix the page size to 64KiB.
	// We therefore effectively support all systems with page size <= 64 KiB.
	trampoline_page_size = 0x10000;
	// Check that the pagesize is greater or equal to the smallest size that we
	// can perform mprotect operations on.
	assert(pagesize() <= trampoline_page_size);
	#else
	trampoline_page_size = pagesize();
	#endif

	trampoline_region_size = trampoline_page_size * TRAMPOLINE_REGION_PAGES;
	trampoline_header_per_page = trampoline_page_size / sizeof(struct block_header);

	// Check that sizeof(struct block_header) is a divisor of the current page size
	assert(trampoline_header_per_page * sizeof(struct block_header) == trampoline_page_size);

    // Check that assumptions for all non-variable page size implementations
	// (currently everything except AArch64) are met
#if defined(__powerpc64__)
	assert(trampoline_page_size == 0x10000);
#elif defined(__ARM_ARCH_ISA_A64)
	assert(trampoline_page_size == 0x1000 || trampoline_page_size == 0x4000);
#else
	assert(trampoline_page_size == 0x1000);
#endif

	// Select the correct trampoline for our page size
#if defined(__ARM_ARCH_ISA_A64)
	if (trampoline_page_size == 0x4000) {
		trampoline_start = &__objc_block_trampoline_16;
		trampoline_end = &__objc_block_trampoline_end_16;
		trampoline_start_sret = &__objc_block_trampoline_sret_16;
		trampoline_end_sret = &__objc_block_trampoline_end_sret_16;
	} else {
#else
	{
#endif
		trampoline_start = &__objc_block_trampoline;
		trampoline_end = &__objc_block_trampoline_end;
		trampoline_start_sret = &__objc_block_trampoline_sret;
		trampoline_end_sret = &__objc_block_trampoline_end_sret;
	}	

	// Check that we can fit the body of the trampoline function inside a block_header
	assert(trampoline_end - trampoline_start <= sizeof(struct block_header));
	assert(trampoline_end_sret - trampoline_start_sret <= sizeof(struct block_header));

	INIT_LOCK(trampoline_lock);
}

static id invalid(id self, SEL _cmd)
{
	fprintf(stderr, "Invalid block method called for [%s %s]\n",
			class_getName(object_getClass(self)), sel_getName(_cmd));
	return nil;
}

static struct trampoline_set *alloc_trampolines(char *start, char *end)
{
	struct trampoline_set *metadata = calloc(1, sizeof(struct trampoline_set));
#if _WIN32
	metadata->region = VirtualAlloc(NULL, trampoline_region_size, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
#else
	metadata->region = mmap(NULL, trampoline_region_size, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);
#endif
	struct block_header *headers_start = REGION_HEADERS_START(metadata);
	char *rx_buffer_start = REGION_RX_BUFFER_START(metadata);
	for (int i=0 ; i<trampoline_header_per_page ; i++)
	{
		headers_start[i].fnptr = (void(*)(void))invalid;
		headers_start[i].block = &headers_start[i+1].block;
		char *block = rx_buffer_start + (i * sizeof(struct block_header));

		memcpy(block, start, end-start);
	}
	headers_start[trampoline_header_per_page-1].block = NULL;
	mprotect(rx_buffer_start, trampoline_page_size, PROT_READ | PROT_EXEC);
	clear_cache(rx_buffer_start, rx_buffer_start + trampoline_page_size);

	return metadata;
}

static struct trampoline_set *sret_trampolines;
static struct trampoline_set *trampolines;

IMP imp_implementationWithBlock(id block)
{
	struct Block_layout *b = (struct Block_layout *)block;
	void *start;
	void *end;
	LOCK_FOR_SCOPE(&trampoline_lock);
	struct trampoline_set **setptr;

	if ((b->flags & BLOCK_USE_SRET) == BLOCK_USE_SRET)
	{
		setptr = &sret_trampolines;
		start = trampoline_start_sret;
		end = trampoline_end_sret;
	}
	else
	{
		setptr = &trampolines;
		start = trampoline_start;
		end = trampoline_end;
	}
	size_t trampolineSize = end - start;
	// If we don't have a trampoline intrinsic for this architecture, return a
	// null IMP.
	if (0 >= trampolineSize) { return 0; }
	block = Block_copy(block);
	// Allocate some trampolines if this is the first time that we need to do this.
	if (*setptr == NULL)
	{
		*setptr = alloc_trampolines(start, end);
	}
	for (struct trampoline_set *set=*setptr ; set!=NULL ; set=set->next)
	{
		if (set->first_free != -1)
		{
			int i = set->first_free;
			struct block_header *headers_start = REGION_HEADERS_START(set);
			char *rx_buffer_start = REGION_RX_BUFFER_START(set);
			struct block_header *h = &headers_start[i];
			struct block_header *next = h->block;
			set->first_free = next ? (next - headers_start) : -1;
			assert(set->first_free < trampoline_header_per_page);
			assert(set->first_free >= -1);
			h->fnptr = (void(*)(void))b->invoke;
			h->block = b;
			uintptr_t addr = (uintptr_t)&rx_buffer_start[i*sizeof(struct block_header)];
#if (__ARM_ARCH_ISA_THUMB == 2)
			// If the trampoline is Thumb-2 code, then we must set the low bit
			// to 1 so that b[l]x instructions put the CPU in the correct mode.
			addr |= 1;
#endif
			return (IMP)addr;
		}
	}
	UNREACHABLE("Failed to allocate block");
}

static int indexForIMP(IMP anIMP, struct trampoline_set **setptr)
{
	for (struct trampoline_set *set=*setptr ; set!=NULL ; set=set->next)
	{
		struct block_header *headers_start = REGION_HEADERS_START(set);
		char *rx_buffer_start = REGION_RX_BUFFER_START(set);
		if (((char *)anIMP >= rx_buffer_start) &&
		    ((char *)anIMP < &rx_buffer_start[trampoline_page_size]))
		{
			*setptr = set;
			ptrdiff_t offset = (char *)anIMP - rx_buffer_start;
			return offset / sizeof(struct block_header);
		}
	}
	return -1;
}

id imp_getBlock(IMP anImp)
{
	LOCK_FOR_SCOPE(&trampoline_lock);
	struct trampoline_set *set = trampolines;
	int idx = indexForIMP(anImp, &set);
	if (idx == -1)
	{
		set = sret_trampolines;
		indexForIMP(anImp, &set);
	}
	if (idx == -1)
	{
		return NULL;
	}
	return REGION_HEADERS_START(set)[idx].block;
}

BOOL imp_removeBlock(IMP anImp)
{
	LOCK_FOR_SCOPE(&trampoline_lock);
	struct trampoline_set *set = trampolines;
	int idx = indexForIMP(anImp, &set);
	if (idx == -1)
	{
		set = sret_trampolines;
		indexForIMP(anImp, &set);
	}
	if (idx == -1)
	{
		return NO;
	}
	struct block_header *header_start = REGION_HEADERS_START(set);
	struct block_header *h = &header_start[idx];
	Block_release(h->block);
	h->fnptr = (void(*)(void))invalid;
	h->block = set->first_free == -1 ? NULL : &header_start[set->first_free];
	set->first_free = h - header_start;
	return YES;
}

PRIVATE size_t lengthOfTypeEncoding(const char *types);

char *block_copyIMPTypeEncoding_np(id block)
{
	char *buffer = strdup(block_getType_np(block));
	if (NULL == buffer) { return NULL; }
	char *replace = buffer;
	// Skip the return type
	replace += lengthOfTypeEncoding(replace);
	while (isdigit(*replace)) { replace++; }
	// The first argument type should be @? (block), and we need to transform
	// it to @, so we have to delete the ?.  Assert here because this isn't a
	// block encoding at all if the first argument is not a block, and since we
	// got it from block_getType_np(), this means something is badly wrong.
	assert('@' == *replace);
	replace++;
	assert('?' == *replace);
	// Use strlen(replace) not replace+1, because we want to copy the NULL
	// terminator as well.
	memmove(replace, replace+1, strlen(replace));
	// The next argument should be an object, and we want to replace it with a
	// selector
	while (isdigit(*replace)) { replace++; }
	if ('@' != *replace)
	{
		free(buffer);
		return NULL;
	}
	*replace = ':';
	return buffer;
}
