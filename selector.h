#ifndef OBJC_SELECTOR_H_INCLUDED
#define OBJC_SELECTOR_H_INCLUDED
#include <stdint.h>
#include "objc/runtime.h"

/**
 * Structure used to store selectors in the list.
 */
// begin: objc_selector
struct objc_selector
{
	union
	{
		/**
		 * The name of this selector.  Used for unregistered selectors.
		 */
		const char *name;
		/**
		 * The index of this selector in the selector table.  When a selector
		 * is registered with the runtime, its name is replaced by an index
		 * uniquely identifying this selector.  The index is used for dispatch.
		 */
		uintptr_t index;
	};
	/**
	 * The Objective-C type encoding of the message identified by this selector.
	 */
	const char * types;
};
// end: objc_selector


/**
 * Returns the untyped variant of a selector.
 */
__attribute__((unused))
static uint32_t get_untyped_idx(SEL aSel)
{
	SEL untyped = sel_registerTypedName_np(sel_getName(aSel), 0);
	return untyped->index;
}

__attribute__((unused))
static SEL sel_getUntyped(SEL aSel)
{
	return sel_registerTypedName_np(sel_getName(aSel), 0);
}

#ifdef __cplusplus
extern "C"
{
#endif
/**
 * Registers the selector.  This selector may be returned later, so it must not
 * be freed.
 */
SEL objc_register_selector(SEL aSel);

#ifdef __cplusplus
}
#endif

/**
 * SELECTOR() macro to work around the fact that GCC hard-codes the type of
 * selectors.  This is functionally equivalent to @selector(), but it ensures
 * that the selector has the type that the runtime uses for selectors.
 */
#ifdef __clang__
#define SELECTOR(x) @selector(x)
#else
#define SELECTOR(x) (SEL)@selector(x)
#endif

#endif // OBJC_SELECTOR_H_INCLUDED
