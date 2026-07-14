/*
 * Provides atomic load and store functions using either native C11 atomic
 * types and operations if available, or otherwise using fallback
 * implementations (e.g. with GCC where stdatomic.h is not useable from
 * Objective-C).
 *
 * Adopted from FreeBSD's stdatomic.h.
 */
#ifndef _GSAtomic_h_
#define _GSAtomic_h_

#ifndef __has_extension
#define __has_extension(x) 0
#endif

#if __has_extension(c_atomic) || __has_extension(cxx_atomic)

/*
 * Use native C11 atomic operations. _Atomic() should be defined by the
 * compiler.
 */
#define	gs_atomic_load_explicit(object, order) \
  __c11_atomic_load(object, order)
#define	gs_atomic_store_explicit(object, desired, order) \
  __c11_atomic_store(object, desired, order)

#else

/*
 * No native support for _Atomic(). Place object in structure to prevent
 * most forms of direct non-atomic access.
 */
#define	_Atomic(T) struct { T volatile __val; }
#if __has_builtin(__sync_swap)
/* Clang provides a full-barrier atomic exchange - use it if available. */
#define	gs_atomic_exchange_explicit(object, desired, order) \
  ((void)(order), __sync_swap(&(object)->__val, desired))
#else
/*
 * __sync_lock_test_and_set() is only an acquire barrier in theory (although in
 * practice it is usually a full barrier) so we need an explicit barrier before
 * it.
 */
#define	gs_atomic_exchange_explicit(object, desired, order) \
__extension__ ({ \
  __typeof__(object) __o = (object); \
  __typeof__(desired) __d = (desired); \
  (void)(order); \
  __sync_synchronize(); \
  __sync_lock_test_and_set(&(__o)->__val, __d); \
})
#endif
#define	gs_atomic_load_explicit(object, order) \
  ((void)(order), __sync_fetch_and_add(&(object)->__val, 0))
#define	gs_atomic_store_explicit(object, desired, order) \
  ((void)gs_atomic_exchange_explicit(object, desired, order))

#endif

#ifndef __ATOMIC_SEQ_CST
#define __ATOMIC_SEQ_CST 5
#endif

/*
 * Convenience functions.
 */
#define	gs_atomic_load(object) \
  gs_atomic_load_explicit(object, __ATOMIC_SEQ_CST)
#define	gs_atomic_store(object, desired) \
  gs_atomic_store_explicit(object, desired, __ATOMIC_SEQ_CST)

#endif // _GSAtomic_h_
