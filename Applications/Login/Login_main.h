/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - Login application
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

// 1 - Catchall for general errors
// 2 - Misuse of shell builtins (according to Bash documentation)
// 10 - exit(0)
// 11 - shutdown
// 12 - reboot
enum LoginExitCode {
  QuitExitCode = 10,
  ShutdownExitCode = 11,
  RebootExitCode = 12,
  UpdateExitCode = 13
};
int panelExitCode;
