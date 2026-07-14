#include <CoreFoundation/CFLogUtilities.h>
#include <CFNetwork/CFNetwork.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <arpa/inet.h>

void printAddressFromData(CFDataRef data)
{
  struct sockaddr *ai_addr = (struct sockaddr *)CFDataGetBytePtr(data);
  struct sockaddr_in *addr = (struct sockaddr_in *)ai_addr;

  CFLog(kCFLogLevelInfo, CFSTR("->-> %s"), inet_ntoa((struct in_addr)addr->sin_addr));
}

void ClientCallback(CFHostRef theHost, CFHostInfoType typeInfo, const CFStreamError* error, void *info)
{
  CFHostRef host = (CFHostRef)info;
  CFArrayRef addrs, names;
  Boolean hasBeenResolved;

  CFHostSetClient(theHost, NULL, NULL);

  CFLog(kCFLogLevelInfo, CFSTR("-> Client callback called"));
  if (!error->error) {
    names = CFHostGetNames(host, &hasBeenResolved);
    addrs = CFHostGetAddressing(theHost, &hasBeenResolved);
    CFLog(kCFLogLevelInfo, CFSTR("-> Address %@ without error"), hasBeenResolved ? CFSTR("resolved") : CFSTR("not resolved"));

    CFLog(kCFLogLevelInfo, CFSTR("-> Addresses for host name: %@"), CFArrayGetValueAtIndex(names, 0));
    for (int i = 0; i < CFArrayGetCount(addrs); i++) {
      printAddressFromData(CFArrayGetValueAtIndex(addrs, i));
    }
    CFRelease(addrs);
  }

  CFRunLoopStop(CFRunLoopGetCurrent());
}


int main(int argc, char **argv)
{
  CFHostRef host = CFHostCreateWithName(kCFAllocatorDefault, CFSTR("localhost"));
  CFStreamError error;
  CFRunLoopRef runloop = CFRunLoopGetCurrent();
  CFHostClientContext ctxt = {0, (void *)host, NULL, NULL, NULL};

  CFLog(kCFLogLevelInfo, CFSTR("Setup resolution process..."));
  CFHostSetClient(host, (CFHostClientCallBack)ClientCallback, &ctxt);
  CFHostScheduleWithRunLoop(host, runloop, kCFRunLoopDefaultMode);

  CFLog(kCFLogLevelInfo, CFSTR("Starting addresses resolution..."));
  if (CFHostStartInfoResolution(host, kCFHostAddresses, &error) != TRUE) {
    CFLog(kCFLogLevelInfo, CFSTR("Failed to start name resolution"));
    exit(1);
  }

  CFRunLoopRun();
}