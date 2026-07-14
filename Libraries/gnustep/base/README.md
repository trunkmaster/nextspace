GNUstep Base Library
====================

[![CI](https://github.com/gnustep/libs-base/actions/workflows/main.yml/badge.svg)](https://github.com/gnustep/libs-base/actions/workflows/main.yml?query=branch%3Amaster)

The GNUstep Base Library is a library of general-purpose, non-graphical
Objective C objects.  For example, it includes classes for strings,
object collections, byte streams, typed coders, invocations,
notifications, notification dispatchers, moments in time, network ports,
remote object messaging support (distributed objects), and event loops.

It provides functionality that aims to implement the non-graphical
portion of the Apple's Cocoa frameworks (the Foundation library) which
came from the OpenStep standard.

Initial reading
---------------

The file [NEWS](NEWS) has the library's feature history.

The files [INSTALL](INSTALL) or [GNUstep-HOWTO][1] (from the web site)
gives instructions for installing the library.

[1]: http://www.gnustep.org/resources/documentation/User/GNUstep/gnustep-howto.pdf

License
-------

The GNUstep libraries and library resources are covered under the GNU
Lesser Public License.  This means you can use these libraries in any
program (even non-free programs).  If you distribute the libraries along
with your program, you must make the improvements you have made to the
libraries freely available.  You should read the COPYING.LIB file for
more information.  All files in the 'Source', 'Headers',
'NSCharacterSets', 'NSTimeZones', and 'Resources' directories and
subdirectories under this are covered under the LGPL.

GNUstep tools, test programs, and other files are covered under the
GNU Public License.  This means if you make changes to these programs,
you cannot charge a fee, other than distribution fees, for others to use
the program.  You should read the COPYING file for more information.
All files in the 'Documentation', 'Examples', 'Tools', 'config', and
'macosx' directories are covered under the GPL.

With GNUstep-Base, we strongly recommend the use of the ffcall
libraries, which provides stack frame handling for NSInvocation and
NSConnection.  "Ffcall is under GNU GPL. As a special exception, if used
in GNUstep or in derivate works of GNUstep, the included parts of ffcall
are under GNU LGPL" (Text in quotes provided by the author of ffcall).

How can you help?
-----------------

Give us feedback! Tell us what you like; tell us what you think could be better.

Please log bug reports on the [GitHub issues page][2].

[2]: https://github.com/gnustep/libs-base/issues

Happy hacking!

Copyright (C) 2005 Free Software Foundation

Copying and distribution of this file, with or without modification,
are permitted in any medium without royalty provided the copyright
notice and this notice are preserved.
