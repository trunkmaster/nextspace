/* 
   Project: Time

   Copyright (C) 2006 Free Software Foundation

   Author: Serg Stoyan

   Created: 2006-06-05 01:22:56 +0300 by stoyan

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
 
   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
 
   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import <X11/Xlib.h>
#import <AppKit/AppKit.h>

int 
main(int argc, const char *argv[])
{
  if (!XInitThreads()) {
    NSLog(@"X11 multi-threading is not initialized!");
  }
  return NSApplicationMain (argc, argv);
}

