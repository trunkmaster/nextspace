#!/bin/sh
BASE_VERSION=1.27.0
GUI_VERSION=0.28.0
BACK_VERSION=0.28.0
GORM_VERSION=1.2.24
PC_VERSION=0.6.2

source /Developer/Makefiles/GNUstep.sh

# Base
cd libs-base
printf "Creating dist for Base $BASE_VERSION...\n"
printf "  Configuring..."
./configure 2>&1 > /dev/null
printf "\n"
printf "  Packing..."
make dist 2>&1 > /dev/null
printf "\n"
cd ..
mv gnustep-base-$BASE_VERSION.tar.gz ~/rpmbuild/SOURCES

# GUI
cd libs-gui
printf "Creating dist for GUI $GUI_VERSION...\n"
printf "  Configuring..."
./configure 2>&1 > /dev/null
printf "\n"
printf "  Packing..."
make dist 2>&1 > /dev/null
printf "\n"
cd ..
mv gnustep-gui-$GUI_VERSION.tar.gz ~/rpmbuild/SOURCES
cp libs-gui_rpmbuild.patch ~/rpmbuild/SOURCES
cp gnustep-gui-images.tar.gz ~/rpmbuild/SOURCES

# Back
cd libs-back
printf "Creating dist for Back $BACK_VERSION...\n"
printf "  Configuring..."
./configure 2>&1 > /dev/null
printf "\n"
echo "  Packing..."
make dist 2>&1 > /dev/null
printf "\n"
cd ..
mv gnustep-back-$BACK_VERSION.tar.gz ~/rpmbuild/SOURCES
cp libs-back_IconImage.patch ~/rpmbuild/SOURCES
cp libs-back_TakeFocus.patch ~/rpmbuild/SOURCES
cp libs-back_rpmbuild.patch ~/rpmbuild/SOURCES

# GORM
cd apps-gorm
printf "Creating dist for GORM $GORM_VERSION...\n"
printf "  Packing..."
make dist 2>&1 > /dev/null
printf "\n"
cd ..
mv gorm-$GORM_VERSION.tar.gz ~/rpmbuild/SOURCES

# ProjectCenter
cd apps-projectcenter
printf "Creating dist for ProjectCenter $PC_VERSION...\n"
printf "  Packing..."
make dist 2>&1 > /dev/null
printf "\n"
cd ..
mv ProjeCtcenter-$PC_VERSION.tar.gz ~/rpmbuild/SOURCES
cp projectcenter-images.tar.gz ~/rpmbuild/SOURCES

# spec file
cp nextspace-gnustep.spec ~/rpmbuild/SPECS
