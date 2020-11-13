#ifndef _WNOTIFICATION_H_
#define _WNOTIFICATION_H_

//#include "WMcore.h"

typedef struct W_Notification WMNotification;
typedef struct W_NotificationQueue WMNotificationQueue;

typedef enum {
    WMPostWhenIdle = 1,
    WMPostASAP = 2,
    WMPostNow = 3
} WMPostingStyle;

typedef enum {
    WNCNone = 0,
    WNCOnName = 1,
    WNCOnSender = 2
} WMNotificationCoalescing;
  
typedef void WMNotificationObserverAction(void *observerData,
                                          WMNotification *notification);

/* ---[ notification.c ]-------------------------------------------------- */

void W_InitNotificationCenter(void);

void W_ReleaseNotificationCenter(void);

void W_FlushASAPNotificationQueue(void);

void W_FlushIdleNotificationQueue(void);


/* ---[ WUtil ]-------------------------------------------------- */

WMNotification* WMCreateNotification(const char *name, void *object, void *clientData);

void WMReleaseNotification(WMNotification *notification);

WMNotification* WMRetainNotification(WMNotification *notification);

void* WMGetNotificationClientData(WMNotification *notification);

void* WMGetNotificationObject(WMNotification *notification);

const char* WMGetNotificationName(WMNotification *notification);


void WMAddNotificationObserver(WMNotificationObserverAction *observerAction,
                               void *observer, const char *name, void *object);

void WMPostNotification(WMNotification *notification);

void WMRemoveNotificationObserver(void *observer);

void WMRemoveNotificationObserverWithName(void *observer, const char *name,
                                          void *object);

void WMPostNotificationName(const char *name, void *object, void *clientData);

WMNotificationQueue* WMGetDefaultNotificationQueue(void);

WMNotificationQueue* WMCreateNotificationQueue(void);

void WMDequeueNotificationMatching(WMNotificationQueue *queue,
                                   WMNotification *notification,
                                   unsigned mask);

void WMEnqueueNotification(WMNotificationQueue *queue,
                           WMNotification *notification,
                           WMPostingStyle postingStyle);

void WMEnqueueCoalesceNotification(WMNotificationQueue *queue,
                                   WMNotification *notification,
                                   WMPostingStyle postingStyle,
                                   unsigned coalesceMask);


#endif
