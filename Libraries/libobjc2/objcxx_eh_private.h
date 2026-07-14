typedef struct objc_object* id;

#include "objc/runtime.h"
#include "visibility.h"

#ifndef DEBUG_EXCEPTIONS
#define DEBUG_LOG(...)
#else
#define DEBUG_LOG(str, ...) fprintf(stderr, str, ## __VA_ARGS__)
#endif


/**
 * Our own definitions of C++ ABI functions and types.  These are provided
 * because this file must not include cxxabi.h.  We need to handle subtly
 * different variations of the ABI and including one specific implementation
 * would make that very difficult.
 */
namespace __cxxabiv1
{
	/**
	 * Type info for classes.  Forward declared because the GNU ABI provides a
	 * method on all type_info objects that the dynamic the dynamic cast header
	 * needs.
	 */
	struct __class_type_info;
	/**
	 * The C++ in-flight exception object.  We will derive the offset of fields
	 * in this, so we do not ever actually see a concrete definition of it.
	 */
	struct __cxa_exception;
	/**
	 * The public ABI structure for current exception state.
	 */
	struct __cxa_eh_globals
	{
		/**
		 * The current exception that has been caught.
		 */
		__cxa_exception *caughtExceptions;
		/**
		 * The number of uncaught exceptions still in flight.
		 */
		unsigned int uncaughtExceptions;
	};
	/**
	 * Retrieve the above structure.
	 */
	extern "C" __cxa_eh_globals *__cxa_get_globals();
}

namespace std
{
	struct type_info;
}

// Define some C++ ABI types here, rather than including them.  This prevents
// conflicts with the libstdc++ headers, which expose only a subset of the
// type_info class (the part required for standards compliance, not the
// implementation details).

typedef void (*unexpected_handler)();
typedef void (*terminate_handler)();

namespace std
{
	/**
	 * std::type_info, containing the minimum requirements for the ABI.
	 * Public headers on some implementations also expose some implementation
	 * details.  The layout of our subclasses must respect the layout of the
	 * C++ runtime library, but also needs to be portable across multiple
	 * implementations and so should not depend on internal symbols from those
	 * libraries.
	 */
	class type_info
	{
				public:
				virtual ~type_info();
				bool operator==(const type_info &) const;
				bool operator!=(const type_info &) const;
				bool before(const type_info &) const;
				type_info();
				private:
				type_info(const type_info& rhs);
				type_info& operator= (const type_info& rhs);
				const char *__type_name;
				protected:
				type_info(const char *name): __type_name(name) { }
				public:
				const char* name() const { return __type_name; }
	};
}

extern "C" void __cxa_throw(void*, std::type_info*, void(*)(void*));
extern "C" void __cxa_rethrow();

/**
 * Helper function to find a particular value scanning backwards in a
 * structure.
 */
template<typename T>
ptrdiff_t find_backwards(void *addr, T val)
{
	T *ptr = reinterpret_cast<T*>(addr);
	for (ptrdiff_t disp = -1 ; (disp * sizeof(T) > -128) ; disp--)
	{
		if (ptr[disp] == val)
		{
			return disp * sizeof(T);
		}
	}
	fprintf(stderr, "Unable to find field in C++ exception structure\n");
	abort();
}

/**
 * Helper function to find a particular value scanning forwards in a
 * structure.
 */
template<typename T>
ptrdiff_t find_forwards(void *addr, T val)
{
	T *ptr = reinterpret_cast<T*>(addr);
	for (ptrdiff_t disp = 0 ; (disp * sizeof(T) < 256) ; disp++)
	{
		if (ptr[disp] == val)
		{
			return disp * sizeof(T);
		}
	}
	fprintf(stderr, "Unable to find field in C++ exception structure\n");
	abort();
}

template<typename T>
T *pointer_add(void *ptr, ptrdiff_t offset)
{
	return reinterpret_cast<T*>(reinterpret_cast<char*>(ptr) + offset);
}

namespace gnustep
{
	namespace libobjc
	{
		/**
		 * Superclass for the type info for Objective-C exceptions.
		 */
		struct OBJC_PUBLIC __objc_type_info : std::type_info
		{
			/**
			 * Constructor that sets the name.
			 */
			__objc_type_info(const char *name);
			/**
			 * Helper function used by libsupc++ and libcxxrt to determine if
			 * this is a pointer type.  If so, catches automatically
			 * dereference the pointer to the thrown pointer in
			 * `__cxa_begin_catch`.
			 */
			virtual bool __is_pointer_p() const;
			/**
			 * Helper function used by libsupc++ and libcxxrt to determine if
			 * this is a function pointer type.  Irrelevant for our purposes.
			 */
			virtual bool __is_function_p() const;
			/**
			 * Catch handler.  This is used in the C++ personality function.
			 * `thrown_type` is the type info of the thrown object, `this` is
			 * the type info at the catch site.  `thrown_object` is a pointer
			 * to a pointer to the thrown object and may be adjusted by this
			 * function.
			 */
			virtual bool __do_catch(const type_info *thrown_type,
			                        void **thrown_object,
			                        unsigned) const;
			/**
			 * Function used for `dynamic_cast` between two C++ class types in
			 * libsupc++ and libcxxrt.
			 *
			 * This should never be called on Objective-C types.
			 */
			virtual bool __do_upcast(
			                const __cxxabiv1::__class_type_info *target,
			                void **thrown_object) const;
		};
		
		/**
		 * Singleton type info for the `id` type.
		 */
		struct OBJC_PUBLIC __objc_id_type_info : __objc_type_info
		{
			__objc_id_type_info();
			virtual ~__objc_id_type_info();
			virtual bool __do_catch(const type_info *thrownType,
			                        void **obj,
			                        unsigned outer) const;
		};

		struct OBJC_PUBLIC __objc_class_type_info : __objc_type_info
		{
			virtual ~__objc_class_type_info();
			virtual bool __do_catch(const type_info *thrownType,
			                        void **obj,
			                        unsigned outer) const;
		};
	}
}

/**
 * Public interface to the Objective-C++ exception mechanism
 */
extern "C"
{
/**
 * The public symbol that the compiler uses to indicate the Objective-C id type.
 */
extern OBJC_PUBLIC gnustep::libobjc::__objc_id_type_info __objc_id_type_info;
} // extern "C"

/**
 * C++ structure that is thrown through a frame with the `test_eh_personality`
 * personality function.  This contains a well-known value that we can search
 * for after the unwind header.
 */
struct
PRIVATE
MagicValueHolder
{
    /**
     * The constant that we will search for to identify the MagicValueHolder object.
     */
    static constexpr uint32_t magic = 0x01020304;
	/**
	 * The single field in this structure.
	 */
	uint32_t magic_value;
	/**
	 * Constructor.  Initialises the field with the magic constant.
	 */
	MagicValueHolder();
};
