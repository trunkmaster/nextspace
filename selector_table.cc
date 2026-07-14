/**
 * Handle selector uniquing.
 *
 * When building, you may define TYPE_DEPENDENT_DISPATCH to enable message
 * sends to depend on their types.
 */
#include <string.h>
#include <stdio.h>
#include <assert.h>
#include <ctype.h>
#include <vector>
#include <mutex>
#include <forward_list>
#include <tsl/robin_set.h>
#include "class.h"
#include "lock.h"
#include "method.h"
#include "objc/runtime.h"
#include "pool.hh"
#include "selector.h"
#include "string_hash.h"
#include "visibility.h"

#ifdef TYPE_DEPENDENT_DISPATCH
#	define TDD(x) x
#else
#	define TDD(x)
#endif

namespace {

/**
 * Type representing a selector that has not been registered with the runtime.
 *
 * This is used only for looking up entries in the selector table, it is never
 * stored.
 */
struct UnregisteredSelector
{
	/// The selector name.
	const char *name;

	/// The type encoding of the selector.
	const char *types;
};

/**
 * Class for holding the name and list of types for a selector.  With
 * type-dependent dispatch, we store all of the types that we've seen for each
 * selector name alongside the untyped variant of the selector.  When a
 * selector is registered with the runtime, its name is replaced with the UID
 * (dtable index) used for dispatch and we use the first element of the types
 * list to store the name.
 *
 * In the common case, this will have 1-2 entries.
 */
struct TypeList : public std::forward_list<const char*>
{
	/// The superclass type.
	using Super = std::forward_list<const char*>;
	/// Inherit constructors
	using Super::forward_list;

	/// Get the name of the selector represented by this list
	const char *name()
	{
		return front();
	}

	/**
	 * Begin iterator.  This skips the name and returns an iterator to the
	 * first type.
	 */
	auto begin()
	{
		return ++(std::forward_list<const char*>::begin());
	}

	/**
	 * Add a type.  The order of types is not defined and so, for simplicity,
	 * we store new ones immediately after the name element.
	 */
	void add_types(const char *types)
	{
		// Types cannot be added to an empty type list, a name is the first element.
		assert(!empty());
		insert_after(Super::begin(), types);
	}
};

/**
 * Mapping from selector numbers to selector names, followed by types.
 *
 * Note: This must be a pointer so that we do not hit issues with 
 */
std::vector<TypeList> *selector_list;

/**
 * Lock protecting the selector table.
 */
RecursiveMutex selector_table_lock;

/// Type to use as a lock guard
using LockGuard = std::lock_guard<decltype(selector_table_lock)>;

inline TypeList *selLookup_locked(uint32_t idx)
{
	if (idx >= selector_list->size())
	{
		return nullptr;
	}
	return &(*selector_list)[idx];
}

inline TypeList *selLookup(uint32_t idx)
{
	LockGuard g{selector_table_lock};
	return selLookup_locked(idx);
}

BOOL isSelRegistered(SEL sel)
{
	if (sel->index < selector_list->size())
	{
		return YES;
	}
	return NO;
}

/// Gets the name of a registered selector.
const char *sel_getNameRegistered(SEL sel)
{
	const char *name = sel->name;
	return selLookup_locked(sel->index)->name();
}

/**
 * Gets the name of a selector that might not have been registered.  This
 * should be used only on legacy-ABI compatibility code paths.
 */
const char *sel_getNameNonUnique(SEL sel)
{
	const char *name = sel->name;
	if (isSelRegistered(sel))
	{
		auto* list = selLookup_locked(sel->index);
		name = (list == nullptr) ? nullptr : list->name();
	}
	if (nullptr == name)
	{
		name = "";
	}
	return name;
}

/**
 * Skip anything in a type encoding that is irrelevant to the comparison
 * between selectors, including type qualifiers and argframe info.
 */
static const char *skip_irrelevant_type_info(const char *t)
{
	switch (*t)
	{
		default: return t;
		case 'r': case 'n': case 'N': case 'o': case 'O': case 'R':
		case 'V': case 'A': case '!': case '0'...'9':
			return skip_irrelevant_type_info(t+1);
	}
}

static BOOL selector_types_equal(const char *t1, const char *t2)
{
	if (t1 == nullptr || t2 == nullptr) { return t1 == t2; }

	while (('\0' != *t1) && ('\0' != *t2))
	{
		t1 = skip_irrelevant_type_info(t1);
		t2 = skip_irrelevant_type_info(t2);
		// This is a really ugly hack.  For some stupid reason, the people
		// designing Objective-C type encodings decided to allow * as a
		// shorthand for char*, because strings are 'special'.  Unfortunately,
		// FSF GCC generates "*" for @encode(BOOL*), while Clang and Apple GCC
		// generate "^c" or "^C" (depending on whether BOOL is declared
		// unsigned).  
		//
		// The correct fix is to remove * completely from type encodings, but
		// unfortunately my time machine is broken so I can't travel to 1986
		// and apply a cluebat to those responsible.
		if ((*t1 == '*') && (*t2 != '*'))
		{
			if (*t2 == '^' && (((*(t2+1) == 'C') || (*(t2+1) == 'c'))))
			{
				t2++;
			}
			else
			{
				return NO;
			}
		}
		else if ((*t2 == '*') && (*t1 != '*'))
		{
			if (*t1 == '^' && (((*(t1+1) == 'C') || (*(t1+1) == 'c'))))
			{
				t1++;
			}
			else
			{
				return NO;
			}
		}
		else if (*t1 != *t2)
		{
			return NO;
		}

		if ('\0' != *t1) { t1++; }
		if ('\0' != *t2) { t2++; }
	}
	return YES;
}

#ifdef TYPE_DEPENDENT_DISPATCH

static BOOL selector_types_equivalent(const char *t1, const char *t2)
{
	// We always treat untyped selectors as having the same type as typed
	// selectors, for dispatch purposes.
	if (t1 == nullptr || t2 == nullptr) { return YES; }

	return selector_types_equal(t1, t2);
}
#endif

/**
 * Compare selectors based on whether they are treated as equivalent for the
 * purpose of dispatch.
 */
struct SelectorEqual
{
	/// Opt into heterogeneous lookup
	using is_transparent = void;

	/// Compare two registered selectors
	bool operator()(const SEL a, const SEL b) const
	{
#ifdef TYPE_DEPENDENT_DISPATCH
		return string_compare(sel_getNameRegistered(a), sel_getNameRegistered(b)) &&
			selector_types_equal(sel_getType_np(a), sel_getType_np(b));
#else
		return string_compare(sel_getNameRegistered(a), sel_getNameRegistered(b));
#endif
	}

	/// Compare an unregistered and registered selector
	bool operator()(const UnregisteredSelector &a, const SEL b) const
	{
#ifdef TYPE_DEPENDENT_DISPATCH
		return string_compare(a.name, sel_getNameRegistered(b)) &&
			selector_types_equal(a.types, sel_getType_np(b));
#else
		return string_compare(a.name, sel_getNameRegistered(b));
#endif
	}

	/// Compare a registered and unregistered selector
	bool operator()(const SEL b, const UnregisteredSelector &a) const
	{
		return (*this)(a, b);
	}
};

/**
 * Compare whether two selectors are identical.
 */
static int selector_identical(const UnregisteredSelector &key,
                              const SEL value)
{
	return SelectorEqual{}(key, value);
}


/**
 * Hash a selector.
 */
struct SelectorHash
{
	size_t hash(const char *name, const char *types) const
	{
		size_t hash = 5381;
		const char *str = name;
		size_t c;
		while((c = (size_t)*str++))
		{
			hash = hash * 33 + c;
		}
#ifdef TYPE_DEPENDENT_DISPATCH
		// We can't use all of the values in the type encoding for the hash,
		// because our equality test is a bit more complex than simple string
		// encoding (for example, * and ^C have to be considered equivalent, since
		// they are both used as encodings for C strings in different situations)
		if ((str = types))
		{
			while((c = (size_t)*str++))
			{
				switch (c)
				{
					case '@': case 'i': case 'I': case 'l': case 'L':
					case 'q': case 'Q': case 's': case 'S': 
					hash = hash * 33 + c;
				}
			}
		}
#endif
		return hash;
	}

	size_t operator()(objc_selector *sel) const
	{
		return hash(sel_getNameNonUnique(sel), sel_getType_np(sel));
	}

	size_t operator()(const UnregisteredSelector &sel) const
	{
		return hash(sel.name, sel.types);
	}
};

using SelectorAllocator = PoolAllocate<objc_selector>;
using SelectorTable = tsl::robin_set<objc_selector*, SelectorHash, SelectorEqual>;

/**
 * Table of registered selector.  Maps from selector to selector.
 */
static SelectorTable *selector_table;

static int selector_name_copies;
}

extern "C" PRIVATE void log_selector_memory_usage(void)
{
#if 0
	fprintf(stderr, "%lu bytes in selector name list.\n", (unsigned long)(table_size * sizeof(void*)));
	fprintf(stderr, "%d bytes in selector names.\n", selector_name_copies);
	fprintf(stderr, "%d bytes (%d entries) in selector hash table.\n", (int)(sel_table->table_size *
	        sizeof(struct selector_table_cell_struct)), sel_table->table_size);
	fprintf(stderr, "%d selectors registered.\n", selector_count);
	fprintf(stderr, "%d hash table cells per selector (%.2f%% full)\n", sel_table->table_size / selector_count,  ((float)selector_count) /  sel_table->table_size * 100);
#endif
}




/**
 * Resizes the dtables to ensure that they can store as many selectors as
 * exist.
 */
extern "C" void objc_resize_dtables(uint32_t);

/**
 * Create data structures to store selectors.
 */
extern "C" PRIVATE void init_selector_tables()
{
	selector_list = new std::vector<TypeList>(1<<16);
	selector_table = new SelectorTable(1024);
	selector_table_lock.init();
}

static SEL selector_lookup(const char *name, const char *types)
{
	UnregisteredSelector sel = {name, types};
	LockGuard g{selector_table_lock};
	auto result = selector_table->find(sel);
	return (result == selector_table->end()) ? nullptr : *result;
}

static inline void add_selector_to_table(SEL aSel)
{
	// Store the name at the head of the list.
	if (selector_list->capacity() == selector_list->size())
	{
		selector_list->reserve(selector_list->capacity() * 2);
	}
	selector_list->push_back({aSel->name});
	// Set the selector's name to the uid.
	aSel->index = selector_list->size() - 1;
	// Store the selector in the set.
	selector_table->insert(aSel);
}

/**
 * Really registers a selector.  Must be called with the selector table locked.
 */
static inline void register_selector_locked(SEL aSel)
{
	if (aSel->name == nullptr)
	{
		return;
	}
	if (nullptr == aSel->types)
	{
		add_selector_to_table(aSel);
		objc_resize_dtables(selector_list->size());
		return;
	}
	SEL untyped = selector_lookup(aSel->name, 0);
	// If this has a type encoding, store the untyped version too.
	if (untyped == nullptr)
	{
		untyped = SelectorAllocator::allocate();
		untyped->name = aSel->name;
		untyped->types = 0;
		add_selector_to_table(untyped);
	}
	else
	{
		// Make sure we only store one copy of the name
		aSel->name = sel_getNameNonUnique(untyped);
	}
	add_selector_to_table(aSel);

	// Add this set of types to the list.
	if (aSel->types)
	{
		(*selector_list)[aSel->index].add_types(aSel->types);
		TDD((*selector_list)[untyped->index].add_types(aSel->types));
	}
	objc_resize_dtables(selector_list->size());
}
/**
 * Registers a selector.  This assumes that the argument is never deallocated.
 */
extern "C" PRIVATE SEL objc_register_selector(SEL aSel)
{
	if (isSelRegistered(aSel))
	{
		return aSel;
	}
	UnregisteredSelector unregistered{aSel->name, aSel->types};
	// Check that this isn't already registered, before we try
	SEL registered = selector_lookup(aSel->name, aSel->types);
	SelectorEqual eq;
	if (nullptr != registered && eq(unregistered, registered))
	{
		aSel->name = registered->name;
		return registered;
	}
	assert(!(aSel->types && (strstr(aSel->types, "@\"") != nullptr)));
	LockGuard g{selector_table_lock};
	register_selector_locked(aSel);
	return aSel;
}

/**
 * Registers a selector by copying the argument.
 */
SEL objc_register_selector_copy(UnregisteredSelector &aSel, BOOL copyArgs)
{
	// If an identical selector is already registered, return it.
	SEL copy = selector_lookup(aSel.name, aSel.types);
	if ((nullptr != copy) && selector_identical(aSel, copy))
	{
		return copy;
	}
	LockGuard g{selector_table_lock};
	copy = selector_lookup(aSel.name, aSel.types);
	if (nullptr != copy && selector_identical(aSel, copy))
	{
		return copy;
	}
	assert(!(aSel.types && (strstr(aSel.types, "@\"") != nullptr)));
	// Create a copy of this selector.
	copy = SelectorAllocator::allocate();
	copy->name = aSel.name;
	copy->types = (nullptr == aSel.types) ? nullptr : aSel.types;
	if (copyArgs)
	{
		SEL untyped = selector_lookup(aSel.name, 0);
		if (untyped != nullptr)
		{
			copy->name = sel_getName(untyped);
		}
		else
		{
			copy->name = strdup(aSel.name);
			if (copy->name == nullptr)
			{
				fprintf(stderr, "Failed to allocate memory for selector %s\n", aSel.name);
				abort();
			}
			assert(copy->name);
			selector_name_copies += strlen(copy->name);
		}
		if (copy->types != nullptr)
		{
			copy->types = strdup(copy->types);
			if (copy->name == nullptr)
			{
				fprintf(stderr, "Failed to allocate memory for selector %s\n", aSel.name);
				abort();
			}
			selector_name_copies += strlen(copy->types);
		}
	}
	// Try to register the copy as the authoritative version
	register_selector_locked(copy);
	return copy;
}

/**
 * Public API functions.
 */
extern "C"
{

const char *sel_getName(SEL sel)
{
	if (nullptr == sel) { return "<null selector>"; }
	auto list = selLookup(sel->index);
	return  (list == nullptr) ? "" : list->front();
}

SEL sel_getUid(const char *selName)
{
	return sel_registerName(selName);
}

BOOL sel_isEqual(SEL sel1, SEL sel2)
{
	if ((0 == sel1) || (0 == sel2))
	{
		return sel1 == sel2;
	}
	if (sel1->name == sel2->name)
	{
		return YES;
	}
	// Otherwise, do a slow compare
	return string_compare(sel_getNameNonUnique(sel1), sel_getNameNonUnique(sel2)) TDD(&&
			(sel1->types == nullptr || sel2->types == nullptr ||
		selector_types_equivalent(sel_getType_np(sel1), sel_getType_np(sel2))));
}

SEL sel_registerName(const char *selName)
{
	if (nullptr == selName) { return nullptr; }
	UnregisteredSelector sel = {selName, nullptr};
	return objc_register_selector_copy(sel, YES);
}

SEL sel_registerTypedName_np(const char *selName, const char *types)
{
	if (nullptr == selName) { return nullptr; }
	UnregisteredSelector sel = {selName, types};
	return objc_register_selector_copy(sel, YES);
}

const char *sel_getType_np(SEL aSel)
{
	if (nullptr == aSel) { return nullptr; }
	return aSel->types;
}


unsigned sel_copyTypes_np(const char *selName, const char **types, unsigned count)
{
	if (nullptr == selName) { return 0; }
	SEL untyped = selector_lookup(selName, 0);
	if (untyped == nullptr) { return 0; }

	auto *l = selLookup(untyped->index);
	if (l == nullptr)
	{
		return 0;
	}
	if (count == 0)
	{
		for (auto type : *l)
		{
			count++;
		}
		return count;
	}

	unsigned found = 0;
	for (auto type : *l)
	{
		if (found < count)
		{
			types[found] = type;
		}
		found++;
	}
	return found;
}

unsigned sel_copyTypedSelectors_np(const char *selName, SEL *const sels, unsigned count)
{
	if (nullptr == selName) { return 0; }
	SEL untyped = selector_lookup(selName, 0);
	if (untyped == nullptr) { return 0; }

	auto *l = selLookup(untyped->index);
	if (l == nullptr)
	{
		return 0;
	}

	if (count == 0)
	{
		for (auto type : *l)
		{
			count++;
		}
		return count;
	}

	unsigned found = 0;
	for (auto type : *l)
	{
		if (found > count)
		{
			break;
		}
		sels[found++] = selector_lookup(selName, type);
	}
	return found;
}

extern "C" PRIVATE void objc_register_selectors_from_list(struct objc_method_list *l)
{
	for (int i=0 ; i<l->count ; i++)
	{
		Method m = method_at_index(l, i);
		UnregisteredSelector sel{(const char*)m->selector, m->types};
		m->selector = objc_register_selector_copy(sel, NO);
	}
}
/**
 * Register all of the (unregistered) selectors that are used in a class.
 */
extern "C" PRIVATE void objc_register_selectors_from_class(Class aClass)
{
	for (struct objc_method_list *l=aClass->methods ; nullptr!=l ; l=l->next)
	{
		objc_register_selectors_from_list(l);
	}
}
extern "C" PRIVATE void objc_register_selector_array(SEL selectors, unsigned long count)
{
	// GCC is broken and always sets the count to 0, so we ignore count until
	// we can throw stupid and buggy compilers in the bin.
	for (unsigned long i=0 ;  (nullptr != selectors[i].name) ; i++)
	{
		objc_register_selector(&selectors[i]);
	}
}


/**
 * Legacy GNU runtime compatibility.
 *
 * All of the functions in this section are deprecated and should not be used
 * in new code.
 */
#ifndef NO_LEGACY
SEL sel_get_typed_uid (const char *name, const char *types)
{
	if (nullptr == name) { return nullptr; }
	SEL sel = selector_lookup(name, types);
	if (nullptr == sel) { return sel_registerTypedName_np(name, types); }

	struct sel_type_list *l = selLookup(sel->index);
	// Skip the head, which just contains the name, not the types.
	l = l->next;
	if (nullptr != l)
	{
		sel = selector_lookup(name, l->value);
	}
	return sel;
}

SEL sel_get_any_typed_uid (const char *name)
{
	if (nullptr == name) { return nullptr; }
	SEL sel = selector_lookup(name, 0);
	if (nullptr == sel) { return sel_registerName(name); }

	struct sel_type_list *l = selLookup(sel->index);
	// Skip the head, which just contains the name, not the types.
	l = l->next;
	if (nullptr != l)
	{
		sel = selector_lookup(name, l->value);
	}
	return sel;
}

SEL sel_get_any_uid (const char *name)
{
	return selector_lookup(name, 0);
}

SEL sel_get_uid(const char *name)
{
	return selector_lookup(name, 0);
}

const char *sel_get_name(SEL selector)
{
	return sel_getNameNonUnique(selector);
}

BOOL sel_is_mapped(SEL selector)
{
	return isSelRegistered(selector);
}

const char *sel_get_type(SEL selector)
{
	return sel_getType_np(selector);
}

SEL sel_register_name(const char *name)
{
	return sel_registerName(name);
}

SEL sel_register_typed_name(const char *name, const char *type)
{
	return sel_registerTypedName_np(name, type);
}

BOOL sel_eq(SEL s1, SEL s2)
{
	return sel_isEqual(s1, s2);
}

#endif // NO_LEGACY
}
