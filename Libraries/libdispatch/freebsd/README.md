# FreeBSD dispatch runtime

`build.sh` builds swift-corelibs-libdispatch swift-5.10.1-RELEASE with the
FreeBSD ports `lang/swift510/files/patch-swift-corelibs-libdispatch_*` patches
from ports commit `b83952c07f19c664b7b9eeae55aad54772efb5df`.
The release archive SHA256 is checked before extraction. The patches retain
their original contents; upstream source licensing is in the release archive.

The unpatched 5.9.2 stage failed to compile FreeBSD lock primitives, but its
unchecked build/install commands continued. No installer dispatch library
was installed, so consumers silently linked the packaged libdispatch 6.1.1.
That runtime failed the GNUstep main-queue callback smoke test (0/1), while
this source with the ports patches passed (1/1) and restored WM interaction.

CMake installs dispatch with public ABI major 1 (project VERSION 1.3), so
existing FreeBSD consumers requesting libdispatch.so.1 and newly linked
consumers both select the same prefix library. Package-owned files under
/usr/local/lib are preserved. Session startup must put /usr/local/NextSpace/lib
first in LD_LIBRARY_PATH; verify actual process mappings.

The Linux stage is unchanged. The FreeBSD helper stops on all build/install
failures and supports DESTDIR through its third argument. Its fourth argument
is the install prefix, passed from Packaging/environment.sh as NEXTSPACE_PREFIX
(default /usr/local/NextSpace). It avoids the old postinstall that moved an
unversioned symlink as if it were a regular library.

Acceptance requires NSRunLoop callback execution and actual window/input
handling, not merely a quiet CPU or a desktop screenshot. See the harness
`wm-responsive.c` and `responsive-session-check.sh`. A host cold boot remains
a separate acceptance gate from repeated full Xorg session starts.
