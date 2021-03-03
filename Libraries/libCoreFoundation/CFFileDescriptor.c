/*
 *  CFFileDescriptor.c
 *  CFFileDescriptor
 *
 *  http://www.puredarwin.org/ 2009, 2018
 */

#include "CFPriv.h"
#include "CFInternal.h"
#include "CFRuntime_Internal.h"
#include "CFFileDescriptor.h"
#include "CFLogUtilities.h"

#if __HAS_DISPATCH__

typedef OSSpinLock CFSpinLock_t;

typedef struct __CFFileDescriptor {
  CFRuntimeBase _base;
  CFSpinLock_t _lock;
  CFFileDescriptorNativeDescriptor _fd;
  CFRunLoopSourceRef _source0;
  CFRunLoopRef _runLoop;
  CFFileDescriptorCallBack _callout;
  CFFileDescriptorContext _context; // includes info for callback
  dispatch_source_t _read_source;
  dispatch_source_t _write_source;
} __CFFileDescriptor;

static CFTypeID __kCFFileDescriptorTypeID = _kCFRuntimeIDNotAType;

CFTypeID CFFileDescriptorGetTypeID(void) {
  return _kCFRuntimeIDCFFileDescriptor;
}


#pragma mark - Managing dispatch sources

dispatch_source_t __CFFDCreateSource(CFFileDescriptorRef f, CFOptionFlags callBackType);
void __CFFDSuspendSource(CFFileDescriptorRef f, CFOptionFlags callBackType);
void __CFFDRemoveSource(CFFileDescriptorRef f, CFOptionFlags callBackType);
void __CFFDEnableSources(CFFileDescriptorRef f, CFOptionFlags callBackTypes);

// create and return a dispatch source of the given type
dispatch_source_t __CFFDCreateSource(CFFileDescriptorRef f, CFOptionFlags callBackType) {
  dispatch_source_t source;

  if (callBackType == kCFFileDescriptorReadCallBack && !f->_read_source) {
    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, f->_fd, 0, dispatch_get_current_queue());
  }
  else if (callBackType == kCFFileDescriptorWriteCallBack && !f->_write_source) {
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
        CFRunLoopSourceSignal(f->_source0);
        CFRunLoopWakeUp(f->_runLoop);
      });
  }
  
  return source;
}

void __CFFDSuspendSource(CFFileDescriptorRef f, CFOptionFlags callBackType) {
  if (callBackType == kCFFileDescriptorReadCallBack && f->_read_source) {
    dispatch_suspend(f->_read_source);
  }
  if (callBackType == kCFFileDescriptorWriteCallBack && f->_write_source) {
    dispatch_suspend(f->_write_source);
  }
}

// callBackType will be one of Read and Write
void __CFFDRemoveSource(CFFileDescriptorRef f, CFOptionFlags callBackType) {
  if (callBackType == kCFFileDescriptorReadCallBack && f->_read_source) {
    dispatch_source_cancel(f->_read_source);
    dispatch_release(f->_read_source);
    f->_read_source = NULL;
  }
  if (callBackType == kCFFileDescriptorWriteCallBack && f->_write_source) {
    dispatch_source_cancel(f->_write_source);
    dispatch_release(f->_write_source);
    f->_write_source = NULL;
  }
}

// enable dispatch source callbacks on either lazy port creation or CFFileDescriptorEnableCallBacks()
// callBackTypes are the types just enabled, or both if called from the port creation function
void __CFFDEnableSources(CFFileDescriptorRef f, CFOptionFlags callBackTypes) {
  if (callBackTypes & kCFFileDescriptorReadCallBack && f->_read_source) {
    dispatch_resume(f->_read_source);
  }
  if (callBackTypes & kCFFileDescriptorWriteCallBack && f->_write_source) {
    dispatch_resume(f->_write_source);
  }
}


#pragma mark - RunLoop internal

// TODO
// A scheduling callback for the run loop source. This callback is called when the source is
// added to a run loop mode. Can be NULL. 
static void __CFFDSchedule(void *info, CFRunLoopRef rl, CFStringRef mode) {
  __CFFileDescriptor *_info = info;
  CFLog(kCFLogLevelError, CFSTR("CFFileDescriptor SCHEDULE callback invoked (runloop: %li)."), (long)rl);
  _info->_runLoop = rl;
}

// TODO
// A cancel callback for the run loop source. This callback is called when the source is
// removed from a run loop mode. Can be NULL. 
static void __CFFDCancel(void *info, CFRunLoopRef rl, CFStringRef mode) {
  CFLog(kCFLogLevelError, CFSTR("CFFileDescriptor CANCEL callback invoked."));
}

// TODO
// A perform callback for the run loop source. This callback is called when the source has fired.
static void __CFFDPerformV0(void *info) {
  CFFileDescriptorRef f = info;
  /* CFLog(kCFLogLevelError, CFSTR("CFFileDescriptor PERFORM callback invoked (runloop: %li)."), */
  /*       (long)_info->_runLoop); */
  f->_callout(f, kCFFileDescriptorWriteCallBack, f);
}

#pragma mark - Runtime

static void __CFFileDescriptorDeallocate(CFTypeRef cf) {
  CFFileDescriptorRef f = (CFFileDescriptorRef)cf;

  __CFLock(&f->_lock);
  CFFileDescriptorInvalidate(f); // does most of the tear-down
  __CFUnlock(&f->_lock);
}

const CFRuntimeClass __CFFileDescriptorClass = {
   0,
   "CFFileDescriptor",
   NULL,    // init
   NULL,    // copy
    __CFFileDescriptorDeallocate,
   NULL, //__CFDataEqual,
   NULL, //__CFDataHash,
   NULL, //
   NULL, //__CFDataCopyDescription
};

// register the type with the CF runtime
__private_extern__ void __CFFileDescriptorInitialize(void) {
  __kCFFileDescriptorTypeID = _CFRuntimeRegisterClass(&__CFFileDescriptorClass);
  CFLog(kCFLogLevelError, CFSTR("*** CFileDescriptiorInitialize: ID == %i."), __kCFFileDescriptorTypeID);
}

// use the base reserved bits for storage (like CFMachPort does)
Boolean __CFFDIsValid(CFFileDescriptorRef f) {
  return (Boolean)__CFRuntimeGetValue(f, 0, 0);
}

#pragma mark - Public

// create a file descriptor object
CFFileDescriptorRef CFFileDescriptorCreate(CFAllocatorRef allocator,
                                           CFFileDescriptorNativeDescriptor fd,
                                           Boolean closeOnInvalidate,
                                           CFFileDescriptorCallBack callout,
                                           const CFFileDescriptorContext *context) {
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
  }

  memory->_runLoop = NULL;
  memory->_source0 = NULL;
  memory->_read_source = NULL;
  memory->_write_source = NULL;

  __CFRuntimeSetValue(memory, 0, 0, 1);
  __CFRuntimeSetValue(memory, 1, 1, closeOnInvalidate);
    
  return memory;
}


CFFileDescriptorNativeDescriptor CFFileDescriptorGetNativeDescriptor(CFFileDescriptorRef f) {
  if (!f || (CFGetTypeID(f) != CFFileDescriptorGetTypeID()) || !__CFFDIsValid(f)) {
    return -1;
  }
  return f->_fd;
}

void CFFileDescriptorGetContext(CFFileDescriptorRef f, CFFileDescriptorContext *context) {
    
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
void CFFileDescriptorEnableCallBacks(CFFileDescriptorRef f, CFOptionFlags callBackTypes) {
  if (!CFFileDescriptorIsValid(f) || !__CFFDIsValid(f) || !callBackTypes) {
    CFLog(kCFLogLevelError, CFSTR("CFFileDescriptorEnableCallBacks ERROR: invalid descriptor!"));
    return;
  }

  __CFLock(&f->_lock);

  if (callBackTypes & kCFFileDescriptorReadCallBack) {
    /* CFLog(kCFLogLevelError, CFSTR("CFFileDescriptor enabled READ callback.")); */
    if ( !f->_read_source) {
      f->_read_source = __CFFDCreateSource(f, kCFFileDescriptorReadCallBack);
    }
    __CFFDEnableSources(f, kCFFileDescriptorReadCallBack);
  }
	
  if (callBackTypes & kCFFileDescriptorWriteCallBack) {
    /* CFLog(kCFLogLevelError, CFSTR("CFFileDescriptor enabled WRITE callback.")); */
    if (!f->_write_source) {
      f->_write_source = __CFFDCreateSource(f, kCFFileDescriptorWriteCallBack);
    }
    __CFFDEnableSources(f, kCFFileDescriptorWriteCallBack);
  }
	
  __CFUnlock(&f->_lock);
}

// disable callbacks, setting kqueue filter, regardless of whether watcher thread is running
void CFFileDescriptorDisableCallBacks(CFFileDescriptorRef f, CFOptionFlags callBackTypes) {
  if (!CFFileDescriptorIsValid(f) || !__CFFDIsValid(f) || !callBackTypes) {
    return;
  }
	
  __CFLock(&f->_lock);
    
  if (callBackTypes & kCFFileDescriptorReadCallBack && f->_read_source) {
    __CFFDRemoveSource(f, kCFFileDescriptorReadCallBack);
  }
	
  if (callBackTypes & kCFFileDescriptorWriteCallBack && f->_write_source) {
    __CFFDRemoveSource(f, kCFFileDescriptorWriteCallBack);
  }
	
  __CFUnlock(&f->_lock);
}

// invalidate the file descriptor, possibly closing the fd
void CFFileDescriptorInvalidate(CFFileDescriptorRef f) {
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
	
  if (__CFRuntimeGetValue(f, 1, 1)) { // close fd on invalidate
    close(f->_fd);
  }
	
  __CFUnlock(&f->_lock);
}

// is file descriptor still valid, based on _base header flags?
Boolean	CFFileDescriptorIsValid(CFFileDescriptorRef f) {
  if (!f || (CFGetTypeID(f) != CFFileDescriptorGetTypeID()))
    return FALSE;
  return __CFFDIsValid(f);
}

CFRunLoopSourceRef CFFileDescriptorCreateRunLoopSource(CFAllocatorRef allocator,
                                                       CFFileDescriptorRef f,
                                                       CFIndex order) {
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
      context.schedule = __CFFDSchedule;
      context.cancel = __CFFDCancel;
      context.perform = __CFFDPerformV0;
    
      f->_source0 = CFRunLoopSourceCreate(allocator, order, &context);
      CFRetain(f->_source0);
      result = f->_source0;
    }
    
    __CFUnlock(&f->_lock);
  }
  else {
    CFLog(kCFLogLevelError,
          CFSTR("CFFileDescriptorCreateRunLoopSource: CFFileDescriptorRef is invalid"));
  }

  return result;
}

#endif // __HAS_DISPATCH__
