/*
*   NXSystemInfo
*     - readonly access to othe NXSystem* information;
*     - processor (type,speed), memory, OS (type, bitness);
*   NXDeviceManager 
*     - register added/removed system devices 
*     - manages storage, monitor, mouse, keyboard, bluetooth devices
*     - uses HAL on Linux, devd or HAL on FreeBSD
*   NXFileSystem - file system events monitor (create, delete, etc.)
*   NXSystemKeyboard - type, input languages, shortcuts, repeat rate
*   NXSystemMouse - type, acceleration, buttons mapping, pointer
*   NXSystemDisplay - monitors info, resolution, multimonitor modes, alpha
*   NXSystemSound - volume/bass/treble/balance, device information
*   NXSystemPower - power state, battery, hibernate, shutdown, restart, sleep
*   NXSystemNetwork - hostname, interfaces, routes, user initiated up/down, WiFi
*   NXSystemAuth - user authentification, user/groups management
*/

#import <NXSystem/NXSystemInfo.h>
