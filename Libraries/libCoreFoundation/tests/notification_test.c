#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFLogUtilities.h>
#include <CoreFoundation/CFNotificationCenter.h>

void notificationCallback(CFNotificationCenterRef center,
                          void *observer,
                          CFStringRef name,
                          const void *object,
                          CFDictionaryRef userInfo) {
  const void * keys;
  const void * values;
  
  CFShow(CFSTR("Received notification (dictionary):"));
  
  CFDictionaryGetKeysAndValues(userInfo, &keys, &values);
  for (int i = 0; i < CFDictionaryGetCount(userInfo); i++) {
    const char * keyStr = CFStringGetCStringPtr((CFStringRef)&keys[i],
                                                CFStringGetSystemEncoding());
    const char * valStr = CFStringGetCStringPtr((CFStringRef)&values[i],
                                                CFStringGetSystemEncoding());
    CFLog(kCFLogLevelError, CFSTR("\"%s\" = \"%s\""), keyStr, valStr);
  }
}

int main(int argc, char *argv[])
{
  CFNotificationCenterRef nc = CFNotificationCenterGetLocalCenter();

  if (nc != NULL) {
    CFShow(nc);
  
    // add an observer
    CFNotificationCenterAddObserver(//CFNotificationCenterRef center
                                    nc,
                                    //const void *observer
                                    NULL,
                                    //CFNotificationCallback callBack
                                    notificationCallback,
                                    //CFStringRef name
                                    CFSTR("TestNotification"),
                                    //const void *object
                                    NULL,
                                    //CFNotificationSuspensionBehavior behv
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    
    // post a notification
    CFDictionaryKeyCallBacks keyCallbacks = {0, NULL, NULL, CFCopyDescription, CFEqual, NULL}; 
    CFDictionaryValueCallBacks valueCallbacks = {0, NULL, NULL, CFCopyDescription, CFEqual};
    CFMutableDictionaryRef notif_dictionary;
    
    notif_dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &keyCallbacks, &valueCallbacks);
    CFDictionaryAddValue(notif_dictionary, CFSTR("TestKey"), CFSTR("TestValue"));
    CFNotificationCenterPostNotification(nc, CFSTR("TestNotification"), NULL, notif_dictionary, TRUE);
    CFRelease(notif_dictionary);
    
    // remove oberver
    CFNotificationCenterRemoveObserver(nc, NULL, CFSTR("TestValue"), NULL);
  }
  
  return (0);
}
