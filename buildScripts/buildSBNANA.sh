#!/bin/bash

# build sbncode
# use mrb
# designed to work on Jenkins
# this is a proof of concept script

echo "sbnana version: $SBNANA_VERSION"
echo "sbnana tag/commit/branch: $SBNANA"
#echo "sbnanaobj tag/commit/branch: $SBNANAOBJ"
echo "base qualifiers: $QUAL"
echo "s qualifier: $SQUAL"
echo "build type: $BUILDTYPE"
echo "workspace: $WORKSPACE"

# Get number of cores to use.

ncores=`cat /proc/cpuinfo 2>/dev/null | grep -c -e '^processor'`

if [ $ncores -lt 1 ]; then
  ncores=1
fi
echo "Building using $ncores cores."

# Environment setup, uses cvmfs.

echo "ls /cvmfs/larsoft.opensciencegrid.org"
ls /cvmfs/larsoft.opensciencegrid.org
echo

if [ -f /cvmfs/larsoft.opensciencegrid.org/products/setup ]; then
  if [ -x /cvmfs/grid.cern.ch/util/cvmfs-uptodate ]; then
    /cvmfs/grid.cern.ch/util/cvmfs-uptodate /cvmfs/larsoft.opensciencegrid.org/products
  fi
  source /cvmfs/larsoft.opensciencegrid.org/products/setup || exit 1
else
  echo "No larsoft setup file found."
  exit 1
fi

echo "ls /cvmfs/sbn.opensciencegrid.org"
ls /cvmfs/sbn.opensciencegrid.org
echo

if [ -f /cvmfs/sbn.opensciencegrid.org/products/sbn/setup ]; then
  if [ -x /cvmfs/grid.cern.ch/util/cvmfs-uptodate ]; then
    /cvmfs/grid.cern.ch/util/cvmfs-uptodate /cvmfs/sbn.opensciencegrid.org/products/sbn
  fi
  echo "Setting up sbn cvmfs"
  source /cvmfs/sbn.opensciencegrid.org/products/sbn/setup || exit 1
else
  echo "No sbn setup file found."
  exit 1
fi

#setup mrb
setup mrb || exit 1

# Use system git on macos.
if ! uname | grep -q Darwin; then
  setup git || exit 1
fi
setup gitflow || exit 1
export MRB_PROJECT=sbnana
echo "Mrb path:"
which mrb

set -x
rm -rf $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/copyBack || exit 1
rm -f $WORKSPACE/copyBack/* || exit 1
cd $WORKSPACE/temp || exit 1
mrb newDev -v $SBNANA_VERSION -q $QUAL:$BUILDTYPE || exit 1

set +x
source localProducts*/setup || exit 1

set -x
cd $MRB_SOURCE  || exit 1
# make sure we get a read-only copy
mrb g -r sbnana@$SBNANA || exit 1

if [ -z "$SBNANAOBJ" ]; then
   # Extract sbananobj version from sbncode product_deps
   SBNANAOBJ=`grep sbnanaobj $MRB_SOURCE/sbnana/ups/product_deps | grep -v qualifier | awk '{print $2}'`
fi
echo "sbnanaobj version: $SBNANAOBJ"
mrb g -r sbnanaobj@$SBNANAOBJ || exit 1

cd $MRB_BUILDDIR || exit 1
mrbsetenv || exit 1
mrb b -j$ncores || exit 1
if uname | grep -q Linux; then
  cp /usr/lib64/libXmu.so.6 sbncode/lib
fi
mrb mp -n sbnana -- -j$ncores || exit 1

manifest=sbnana-*_MANIFEST.txt

# Save artifacts.

mv *.bz2  $WORKSPACE/copyBack/ || exit 1
if [ -f $manifest ]; then
  mv $manifest  $WORKSPACE/copyBack/ || exit 1
fi
cp $MRB_BUILDDIR/sbnana/releaseDB/*.html $WORKSPACE/copyBack/
ls -l $WORKSPACE/copyBack/
cd $WORKSPACE || exit 1
rm -rf $WORKSPACE/temp || exit 1
set +x

exit 0
