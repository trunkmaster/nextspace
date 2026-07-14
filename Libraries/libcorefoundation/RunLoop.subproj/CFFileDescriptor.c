/*
 *  CFFileDescriptor.c
 *  CFFileDescriptor
 *
 *  http://www.puredarwin.org/ 2009, 2018
 */

#include "CFInternal.h"
#include "CFRuntime_Internal.h"
#include "CFFileDescriptor.h"
#include "CFLogUtilities.h"
#include <stdbool.h>

#if __HAS_DISPATCH__

#pragma mark - Types

typedef OSSpinLock CFSpinLock_t;

typedef struct __CFFileDescriptor {
  CFRuntimeBase _base;
  CFSpinLock_t _lock;
  CFFileDescriptorNativeDescriptor _fd;
  CFRunLoopSourceRef _source0;
  CFRunLoopRef _runLoop;
  CFFileDescriptorCallBack _callout;
  CFFileDescriptorContext _context;  // includes info for callback
  dispatch_source_t _read_source;
  Boolean _read_source_suspended;
  dispatch_source_t _write_source;
  Boolean _write_source_suspended;
} __CFFileDescriptor;

static CFTypeID __kCFFileDescriptorTypeID = _kCFRuntimeIDNotAType;

CFTypeID CFFileDescriptorGetTypeID(void) { return _kCFRuntimeIDCFFileDescriptor; }

#pragma mark - Managing dispatch sources

dispatch_source_t __CFFDCreateSource(CFFileDescriptorRef f, CFOptionFlags callBackType);
void __CFFDSuspendSource(CFFileDescriptorRef f, CFOptionFlags callBackType);
void __CFFDRemoveSource(CFFileDescriptorRef f, CFOptionFlags callBackType);
void __CFFDEnableSources(CFFileDescriptorRef f, CFOptionFlags callBackTypes);

// create and return a dispatch source of the given type
dispatch_source_t __CFFDCreateSource(CFFileDescriptorRef f, CFOptionFlags callBackType)
{
  dispatch_source_t source;

  // CFLog(kCFLogLevelDebug, CFSTR("CFFileDescriptor->__CFFDCreateSource(%i)"), f->_fd);

  if (callBackType == kCFFileDescriptorReadCallBack && !f->_read_source) {
    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, f->_fd, 0, dispatch_get_current_queue());
  } else if (callBackType == kCFFileDescriptorWriteCallBack && !f->_write_source) {
    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, f->_fd, 0, dispatch_get_current_queue());
  }

  if (source) {
    dispatch_source_set_event_handler(source, ^{
      /* size_t estimated = dispatch_source_get_data(source); */
      /* CFLog(kCFLogLevelError, CFSTR("%i amount of data is ready on descriptor %i (runloop: %li)"), */
      /*       estimated, f->_fd, (long)f->_runLoop); */

      // Each call back is one-shot, and must be re-enabled if you want to get another one.
      __CFFDSuspendSource(f, callBackType);

      // Tell runloop about event (it will call 'perform' callback)
      if (f && f->_source0) {
        CFRunLoopSourceSignal(f->_source0);
      }
      if (f && f->_runLoop) {
        CFRunLoopWakeUp(f->_runLoop);
      }
    });
  }

  return source;
}

void __CFFDSuspendSource(CFFileDescriptorRef f, CFOptionFlags callBackType)
{
  // CFLog(kCFLogLevelError, CFSTR("CFFileDescriptor->__CFFDSuspendSource(%i)"), f->_fd);

  if (callBackType & kCFFileDescriptorReadCallBack && f->_read_source && f->_read_source_suspended == FALSE) {
    dispatch_suspend(f->_read_source);
    f->_read_source_suspended = TRUE;
  }
  if (callBackType & kCFFileDescriptorWriteCallBack && f->_write_source && f->_write_source_suspended == FALSE) {
    dispatch_suspend(f->_write_source);
    f->_write_source_suspended = TRUE;
  }
}

// callBackType will be one of Read and Write
void __CFFDRemoveSource(CFFileDescriptorRef f, CFOptionFlags callBackType)
{
  if (callBackType & kCFFileDescriptorReadCallBack && f->_read_source) {
    // Suspended runloop source can't be released so resume
    if (f->_read_source_suspended != FALSE) {
      dispatch_resume(f->_read_source);
      f->_read_source_suspended = FALSE;
    }
    dispatch_source_cancel(f->_read_source);
    dispatch_release(f->_read_source);
    f->_read_source = NULL;
  }
  if (callBackType & kCFFileDescriptorWriteCallBack && f->_write_source) {
    // Suspended runloop source can't be released so resume
    if (f->_write_source_suspended != FALSE) {
      dispatch_resume(f->_write_source);
      f->_write_source_suspended = FALSE;
    }
    dispatch_source_cancel(f->_write_source);
    dispatch_release(f->_write_source);
    f->_write_source = NULL;
  }
}

// Enable dispatch source callbacks on either lazy port creation or CFFileDescriptorEnableCallBacks()
// callBackTypes are the types just enabled, or both if called from the port creation function
void __CFFDEnableSources(CFFileDescriptorRef f, CFOptionFlags callBackTypes)
{
  if (callBackTypes & kCFFileDescriptorReadCallBack && f->_read_source && f->_read_source_suspended != FALSE) {
    // CFLog(kCFLogLevelInfo, CFSTR("CFFileDescriptor->__CFFDEnabledSource(%i) - READ"), f->_fd);
    dispatch_resume(f->_read_source);
    f->_read_source_suspended = FALSE;
  }
  if (callBackTypes & kCFFileDescriptorWriteCallBack && f->_write_source && f->_write_source_suspended != FALSE) {
    // CFLog(kCFLogLevelInfo, CFSTR("CFFileDescriptor->__CFFDEnabledSource(%i) - WRITE"), f->_fd);
    dispatch_resume(f->_write_source);
    f->_write_source_suspended = FALSE;
  }
}

#pragma mark - RunLoop internal

// TODO
// A scheduling callback for the run loop source. This callback is called when the source is
// added to a run loop mode. Can be NULL.
static void __CFFDScheduleCallback(void *info, CFRunLoopRef rl, CFStringRef mode)
{
  __CFFileDescriptor *_info = info;

  if (info && rl) {
    // CFLog(kCFLogLevelDebug, CFSTR("CFFileDescriptor SCHEDULE callback invoked (runloop: 0x%0lx)."), (long)rl);
    _info->_runLoop = rl;
  }
}

// A cancel callback for the run loop source. This callback is called when the source is
// removed from a run loop mode. Can be NULL.
static void __CFFDCancelCallback(void *info, CFRunLoopRef rl, CFStringRef mode)
{
  __CFFileDescriptor *_info = info;

  // CFLog(kCFLogLevelDebug, CFSTR("CFFileDescriptor CANCEL callback invoked."));
  if (info != NULL) {
    _info->_runLoop = NULL;
  }
}

// A perform callback for the run loop source. This callback is called when the source has fired.
static void __CFFDPerformCallback(void *info)
{
  CFFileDescriptorRef cffd = info;
  void *context_info = NULL;

  // CFLog(kCFLogLevelError, CFSTR("CFFileDescriptor PERFORM callback invoked (runloop: %li)."), (long)f->_runLoop);

  // CFRunLoop soesn't like NULL `context` parameter - pass CFFileDescriptor to omit lockups.
  if (cffd->_context.info) {
    context_info = cffd->_context.info;
  } else {
    // CFLog(kCFLogLevelError, CFSTR("CFFileDescriptor PERFORM callback: context->info is NULL passing self"));
    context_info = cffd;
  }

  cffd->_callout(cffd, kCFFileDescriptorWriteCallBack, context_info);
}

#pragma mark - Runtime

static void __CFFileDescriptorDeallocate(CFTypeRef cf)
{
  CFFileDescriptorRef f = (CFFileDescriptorRef)cf;

  __CFLock(&f->_lock);
  CFFileDescriptorInvalidate(f);  // does most of the tear-down
  __CFUnlock(&f->_lock);
}

const CFRuntimeClass __CFFileDescriptorClass = {
    0,
    "CFFileDescriptor",
    NULL, // init
    NULL, // copy
    __CFFileDescriptorDeallocate,
    NULL, //__CFDataEqual,
    NULL, //__CFDataHash,
    NULL, //
    NULL, //__CFDataCopyDescription
};

// register the type with the CF runtime
__private_extern__ void __CFFileDescriptorInitialize(void)
{
  __kCFFileDescriptorTypeID = _CFRuntimeRegisterClass(&__CFFileDescriptorClass);
  // CFLog(kCFLogLevelDebug, CFSTR("*** CFileDescriptiorInitialize: ID == %i."), __kCFFileDescriptorTypeID);
}

// use the base reserved bits for storage (like CFMachPort does)
Boolean __CFFDIsValid(CFFileDescriptorRef f)
{
  return (Boolean)__CFRuntimeGetValue(f, 0, 0);
}

#pragma mark - Public

// create a file descriptor object
CFFileDescriptorRef CFFileDescriptorCreate(CFAllocatorRef allocator, CFFileDescriptorNativeDescriptor fd, Boolean closeOnInvalidate,
                                           CFFileDescriptorCallBack callout, const CFFileDescriptorContext *context)
{
  CFIndex size;
  CFFileDescriptorRef memory;

  if (!callout) {
    CFLog(kCFLogLevelError, CFSTR("*** CFileDescriptiorCreate: no callback was specified."));
    return NULL;
  }

  size = sizeof(struct __CFFileDescriptor) - sizeof(CFRuntimeBase);
  memory = (CFFileDescriptorRef)_CFRuntimeCreateInstance(allocator, CFFileDescriptorGetTypeID(), size, NULL);
  if (!memory) {
    CFLog(kCFLogLevelError, CFSTR("*** CFileDescriptiorCreate: unable to allocate memory!"));
    return NULL;
  }

  memory->_lock = CFLockInit;
  memory->_fd = fd;
  memory->_callout = callout;
  memory->_context.version = 0;
  if (context) {
    memory->_context.info = context->info;
    memory->_context.retain = context->retain;
    memory->_context.release = context->release;
    memory->_context.copyDescription = context->copyDescription;
  } else {
    memory->_context.info = (void *)CFStringCreateWithFormat(NULL, 0, CFSTR("CFFileDescriptor %i"), fd);
    memory->_context.retain = CFRetain;
    memory->_context.release = CFRelease;
    memory->_context.copyDescription = CFCopyDescription;
  }

  memory->_runLoop = NULL;
  memory->_source0 = NULL;
  memory->_read_source = NULL;
  memory->_read_source_suspended = TRUE;
  memory->_write_source = NULL;
  memory->_write_source_suspended = TRUE;

  __CFRuntimeSetValue(memory, 0, 0, 1);
  __CFRuntimeSetValue(memory, 1, 1, closeOnInvalidate);

  return memory;
}

CFRunLoopSourceRef CFFileDescriptorCreateRunLoopSource(CFAllocatorRef allocator, CFFileDescriptorRef f, CFIndex order)
{
  CFRunLoopSourceRef result = NULL;

  if (CFFileDescriptorIsValid(f)) {
    __CFLock(&f->_lock);

    if (NULL != f->_source0 && !CFRunLoopSourceIsValid(f->_source0)) {
      CFRelease(f->_source0);
      f->_source0 = NULL;
    }
    if (NULL == f->_source0) {
      CFRunLoopSourceContext context;
      context.version = 0;
      context.info = f;
      context.retain = CFRetain;
      context.release = CFRelease;
      context.copyDescription = CFCopyDescription;
      context.equal = CFEqual;
      context.hash = CFHash;
      context.schedule = __CFFDScheduleCallback;
      context.cancel = __CFFDCancelCallback;
      context.perform = __CFFDPerformCallback;

      f->_source0 = CFRunLoopSourceCreate(allocator, order, &context);
      CFRetain(f->_source0);
      result = f->_source0;
    }

    __CFUnlock(&f->_lock);
  } else {
    CFLog(kCFLogLevelError, CFSTR("CFFileDescriptorCreateRunLoopSource: CFFileDescriptorRef is invalid"));
  }

  return result;
}

CFFileDescriptorNativeDescriptor CFFileDescriptorGetNativeDescriptor(CFFileDescriptorRef f)
{
  if (!f || (CFGetTypeID(f) != CFFileDescriptorGetTypeID()) || !__CFFDIsValid(f)) {
    return -1;
  }
  return f->_fd;
}

void CFFileDescriptorGetContext(CFFileDescriptorRef f, CFFileDescriptorContext *context)
{
  if (!f || !context || (CFGetTypeID(f) != CFFileDescriptorGetTypeID()) || !__CFFDIsValid(f)) {
    return;
  }

  context->version = f->_context.version;
  context->info = f->_context.info;
  context->retain = f->_context.retain;
  context->release = f->_context.release;
  context->copyDescription = f->_context.copyDescription;
}

// enable callbacks, setting kqueue filter, regardless of whether watcher thread is running
void CFFileDescriptorEnableCallBacks(CFFileDescriptorRef f, CFOptionFlags callBackTypes)
{
  if (!CFFileDescriptorIsValid(f) || !__CFFDIsValid(f) || !callBackTypes) {
    CFLog(kCFLogLevelError, CFSTR("CFFileDescriptorEnableCallBacks ERROR: invalid descriptor!"));
    return;
  }

  // CFLog(kCFLogLevelWarning, CFSTR("CoreFoundation: CFFileDescriptorEnableCallBacks for FD: %i"), f->_fd);
  
 __CFLock(&f->_lock);

  if (callBackTypes & kCFFileDescriptorReadCallBack) {
    /* CFLog(kCFLogLevelDebug, CFSTR("CFFileDescriptor enabled READ callback.")); */
    if (!f->_read_source) {
      f->_read_source = __CFFDCreateSource(f, kCFFileDescriptorReadCallBack);
    }
    __CFFDEnableSources(f, kCFFileDescriptorReadCallBack);
  }

  if (callBackTypes & kCFFileDescriptorWriteCallBack) {
    /* CFLog(kCFLogLevelDebug, CFSTR("CFFileDescriptor enabled WRITE callback.")); */
    if (!f->_write_source) {
      f->_write_source = __CFFDCreateSource(f, kCFFileDescriptorWriteCallBack);
    }
    __CFFDEnableSources(f, kCFFileDescriptorWriteCallBack);
  }

  __CFUnlock(&f->_lock);
}

// disable callbacks, setting kqueue filter, regardless of whether watcher thread is running
void CFFileDescriptorDisableCallBacks(CFFileDescriptorRef f, CFOptionFlags callBackTypes)
{
  if (!CFFileDescriptorIsValid(f) || !__CFFDIsValid(f) || !callBackTypes) {
    return;
  }

  // CFLog(kCFLogLevelWarning, CFSTR("CoreFoundation: CFFileDescriptorDisableCallBacks for FD: %i"), f->_fd);

  __CFLock(&f->_lock);

  if (callBackTypes & kCFFileDescriptorReadCallBack && f->_read_source) {
    __CFFDSuspendSource(f, kCFFileDescriptorReadCallBack);
  }

  if (callBackTypes & kCFFileDescriptorWriteCallBack && f->_write_source) {
    __CFFDSuspendSource(f, kCFFileDescriptorWriteCallBack);
  }

  __CFUnlock(&f->_lock);
}

// invalidate the file descriptor, possibly closing the fd
void CFFileDescriptorInvalidate(CFFileDescriptorRef f)
{
  if (!CFFileDescriptorIsValid(f) || !__CFFDIsValid(f)) {
    return;
  }

  __CFLock(&f->_lock);

  __CFRuntimeSetValue(f, 0, 0, 0);

  __CFFDRemoveSource(f, kCFFileDescriptorReadCallBack);
  __CFFDRemoveSource(f, kCFFileDescriptorWriteCallBack);

  if (f->_source0) {
    CFRelease(f->_source0);
    f->_source0 = NULL;
  }

  if (__CFRuntimeGetValue(f, 1, 1)) {  // close fd on invalidate
    close(f->_fd);
  }

  __CFUnlock(&f->_lock);
}

// is file descriptor still valid, based on _base header flags?
Boolean CFFileDescriptorIsValid(CFFileDescriptorRef f)
{
  if (!f || (CFGetTypeID(f) != CFFileDescriptorGetTypeID()))
    return FALSE;
  return __CFFDIsValid(f);
}


#endif  // __HAS_DISPATCH__
