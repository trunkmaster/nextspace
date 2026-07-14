#import "Foundation/NSString.h"
#import "Foundation/NSException.h"
#import "GSPrivate.h"

#if defined(HAVE_UNICODE_UTEXT_H)
#include <unicode/utext.h>
#elif defined(HAVE_ICU_H)
#include <icu.h>
// icu.h in Windows 10 is missing a declaration of UTEXT_MAGIC
#ifndef UTEXT_MAGIC
#define UTEXT_MAGIC 0x345ad82c
#endif
#endif

/*
 * Define TRUE/FALSE to be used with UBool parameters, as these are no longer
 * defined in ICU as of ICU 68.
 */
#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

/**
 * Initialises a UText structure with an NSString.  If txt is NULL, then this
 * allocates a new structure on the heap, otherwise it fills in the existing
 * one.
 *
 * The returned UText object holds a reference to the NSString and accesses its
 * contents directly.  
 */
UText* UTextInitWithNSString(UText *txt, NSString *str) GS_ATTRIB_PRIVATE;

/**
 * Initialises a UText structure with an NSMutableString.  If txt is NULL, then
 * this allocates a new structure on the heap, otherwise it fills in the
 * existing one.
 *
 * The returned UText object holds a reference to the NSMutableString and
 * accesses its contents directly.  
 *
 * This function returns a mutable UText, and changes made to it will be
 * reflected in the underlying NSMutableString.
 */
UText* UTextInitWithNSMutableString(UText *txt, NSMutableString *str)
  GS_ATTRIB_PRIVATE;

/**
 * GSUTextString is an NSString subclass that is backed by a libicu UText
 * structure.  This class is intended to be used when returning UText created
 * by libicu functions to Objective-C code.
 */
@interface GSUTextString : NSString
{
  @public
  /** The UText structure containing the libicu string interface. */
  UText txt;
}
@end

/**
 * GSUTextString is an NSMutableString subclass that is backed by a libicu
 * UText structure.  This class is intended to be used when returning UText
 * created by libicu functions to Objective-C code.
 */
@interface GSUTextMutableString : NSMutableString
{
  @public
  /** The UText structure containing the libicu string interface. */
  UText txt;
}
@end

/**
 * Cleanup function used to fee a unichar buffer.
 */
static inline void free_string(unichar **buf)
{
  if (0 != *buf)
    {
      free(*buf);
    }
}

/**
 * Allocates a temporary buffer of the requested size.  This allocates buffers
 * of up to 64 bytes on the stack or more than 64 bytes on the heap.  The
 * buffer is automatically destroyed when it goes out of scope in either case.
 *
 * Buffers created in this way are exception safe when using native exceptions.
 */
#define TEMP_BUFFER(name, length)\
  __attribute__((cleanup(free_string))) unichar *name ##_onheap = 0;\
  unichar name ## _onstack[64];\
  unichar *name = name ## _onstack;\
  if (length > 64)\
    {\
      name ## _onheap = malloc(length * sizeof(unichar));\
      name = name ## _onheap;\
    }

