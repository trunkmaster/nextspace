# Creating Debian packages

The scripts in this directory are supposed to ease the creation of Debian
packages. The focus in on Debian sid (i.e. unstable), but tweaks for
other systems using dpkg are permitted.

## Creating the source tarballs

To avoid cluttering up git with lots of tarballs, a script generates
them on the fly. For this, run

    $ ./download-origs.sh

## Creating source package files

These are created by running

    $ ./create-dscs.sh

This overwrites most of the work that may have been done in the package
source subdirectories, so when working on the packages, rebuild the dsc
files manually, by running `dpkg-source -b .`.

You may have to setup GnuPG with a set of keys so it can sign the results.

## Building packages from dsc

There are many ways to build debian packages and the tested one is based on `pbuilder`.

### Setting up pbuilder

The way pbuilder works is by creating a chroot with a Debian system inside
that contains only the base packages. From there it installs the build
dependencies of your package, builds it and finally extracts the .deb file
from within the chroot to store it in `/var/cache/pbuilder/result`. That
initial system comes from a cached filesystem tarball that you have to
create first, using

    $ sudo pbuild create --distribution sid

If you want to build for a different distribution, adapt as appropriate
(but sid is the best tested distribution).

### Setting up local packages in pbuilder

Since the packages depend on another but are generated independently,
pbuilder needs access to the packages it built in an earlier run. The
easiest way to do that is to make pbuilder's results directory a
package archive for pbuilder.

Edit `/etc/pbuilderrc` to contain the lines

    HOOKDIR=/etc/pbuilder/hook.d
    BINDMOUNTS=/var/cache/pbuilder/result

And add a file `/etc/pbuilder/hook.d/D05self-archive` containing

    apt-get install --assume-yes apt-utils
    
    cd /var/cache/pbuilder/result/
    rm -f InRelease Packages Packages.gz Release Release.gpg Sources Sources.gz
    
    apt-ftparchive packages . > /var/cache/pbuilder/result/Packages
    apt-ftparchive release . > Release
    apt-ftparchive sources . > Sources 2>/dev/null
    
    cat<<EOF >/etc/apt/sources.list.d/apt-ftparchive.list
    deb [trusted=yes] file:///var/cache/pbuilder/result/ ./
    EOF
    
    cat<<EOF >/etc/apt/preferences
    Package: *
    Pin: release o=pbuilder
    Pin-Priority: 701
    EOF
    
    apt-get -qy update

Finally make the file executable with
`chmod +x /etc/pbuilder/hook.d/D05self-archive`.

### Building a package

This is as simple as running

    $ sudo pbuilder build [package.dsc]

There's a convenience script to build them all in the right order:

    $ ./build-from-dsc.sh

# Credits

This integration used several sources that informed how the packages are built:

* [Debian's pbuilder Tricks page](https://wiki.debian.org/PbuilderTricks) provided the base for the pbuilder hooks.
* [gnustep-build](https://github.com/plaurent/gnustep-build) helped figuring out some of configuration details required to integrate libobjc2.
* Debian packages were reused as much as possible: gnustep-{make,base,gui,back}, but renamed to nextspace-\* so they can be installed side-by-side.
* trunkmaster's helpful advice in here
