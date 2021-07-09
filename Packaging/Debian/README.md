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

    $ sudo pbuilder create --distribution sid

If you want to build for a different distribution, adapt as appropriate
(but sid is the best tested distribution).

To build using Debian stable (Buster) you will need to use clang-8 from backports. So create the pbuilder system this way:

    $ sudo pbuilder create --distribution buster --othermirror "deb http://deb.debian.org/debian buster-backports main"

### Setting up local packages in pbuilder

Since the packages depend on another but are generated independently,
pbuilder needs access to the packages it built in an earlier run. The
easiest way to do that is to make pbuilder's results directory a
package archive for pbuilder.

Edit `/etc/pbuilderrc` to contain the lines

    HOOKDIR=/etc/pbuilder/hook.d
    BINDMOUNTS=/var/cache/pbuilder/result

Add a file `/etc/pbuilder/hook.d/D05self-archive` containing

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

Add another file `/etc/pbuilder/hook.d/I99self-archive` containing

    cd /var/cache/pbuilder/result/
    rm -f InRelease Packages Packages.gz Release Release.gpg Sources Sources.gz
    
    apt-ftparchive packages . > /var/cache/pbuilder/result/Packages
    apt-ftparchive release . > Release
    apt-ftparchive sources . > Sources 2>/dev/null
    
For building for stable/Buster with clang from backports you will need to add a further file. `/etc/pbuilder/hook.d/E01clang-backports`:

```
#!/bin/sh
set -e
cat > "/etc/apt/preferences" << EOF
Package: clang*
Pin: release a=buster-backports
Pin-Priority: 999

Package: llvm*   
Pin: release a=buster-backports
Pin-Priority: 999
EOF

apt-get -t buster-backports install --assume-yes clang-8 llvm-8
update-alternatives --install /usr/bin/clang clang /usr/bin/clang-8 50
update-alternatives --install /usr/bin/cc cc /usr/bin/clang-8 50
update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-8 50
update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++-8 50
```

Finally make the files executable with
`chmod +x /etc/pbuilder/hook.d/{D05self-archive,I99self-archive,E01clang-backports}`.


### Building a package

This is as simple as running

    $ sudo pbuilder build [package.dsc]

There's a convenience script to build them all in the right order:

    $ ./build-from-dsc.sh

# Updating a package source

To update a package, several steps need to be done:

1. Update the version number in versions.inc.sh
2. Download the new tarball: `./download-origs.sh` and check that they're correct
3. Move the source directory: `git mv package-old-version package-new-version`
4. Clean out the package's source tree: `cd package-new-version && git clean -fdx $PWD && cd ..`
5. Unpack the new sources: `tar xf package-new-version.tar.*`
6. Update the package's changelog: `cd package-new-version && dch -d && dch -r && cd ..`
7. Create the dsc files: `./create-dscs.sh`
8. Build the packages: `./build-from-dsc.sh`

After double-checking everything, `git commit -a` and push for review!

# Installing the packages

To install the entire desktop environment, just install the `nextspace-desktop` package. This might require some preparation though.

## Setting things up to install pbuilder created packages locally

To tell `apt` to look for the packages created by pbuilder, just create a file `/etc/apt/sources.list.d/nextspace.list` containing

    deb [trusted=yes] file:///var/cache/pbuilder/result/ ./

After running `apt-get update` the package manager will use the packages generated with pbuilder.

## Post configuration steps

You'll need to manually enable the plymouth theme if you want to use it: `sudo plymouth-set-default-theme nextspace`

# Credits

This integration used several sources that informed how the packages are built:

* [Debian's pbuilder Tricks page](https://wiki.debian.org/PbuilderTricks) provided the base for the pbuilder hooks.
* [gnustep-build](https://github.com/plaurent/gnustep-build) helped figuring out some of configuration details required to integrate libobjc2.
* Debian packages were reused as much as possible: gnustep-{make,base,gui,back}, but renamed to nextspace-\* so they can be installed side-by-side.
* trunkmaster provided lots of advice.
