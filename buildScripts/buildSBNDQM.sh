#!/bin/bash

# build sbncode
# use mrb
# designed to work on Jenkins
# this is a proof of concept script

echo "sbndqm version: $SBNDQM_VERSION"
echo "sbndqm tag: $SBNDQM"
#echo "sbncode tag: $SBNCODE"
echo "sbndaq_onlin tag: $SBNDAQ_ONLINE"
echo "base qualifiers: $QUAL"
echo "build type: $BUILDTYPE"
echo "workspace: $WORKSPACE"

# Get number of cores to use.

ncores=`cat /proc/cpuinfo 2>/dev/null | grep -c -e '^processor'`

if [ $ncores -lt 1 ]; then
  ncores=1
fi
echo "Building using $ncores cores."

# Environment setup, uses cvmfs.

echo "ls /cvmfs/fermilab.opensciencegrid.org/products/artdaq/"
ls /cvmfs/fermilab.opensciencegrid.org/products/artdaq
echo

if [ -f /cvmfs/fermilab.opensciencegrid.org/products/artdaq/setup ]; then
  if [ -x /cvmfs/grid.cern.ch/util/cvmfs-uptodate ]; then
    /cvmfs/grid.cern.ch/util/cvmfs-uptodate /cvmfs/fermilab.opensciencegrid.org/products/artdaq
  fi
  source /cvmfs/fermilab.opensciencegrid.org/products/artdaq/setup || exit 1
else
  echo "No fermilab artdaq setup file found."
  exit 1
fi

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
setup git || exit 1
setup gitflow || exit 1
export MRB_PROJECT=sbndqm
echo "Mrb path:"
which mrb

set -x
rm -rf $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/copyBack || exit 1
rm -f $WORKSPACE/copyBack/* || exit 1
cd $WORKSPACE/temp || exit 1
mrb newDev  -v $SBNDQM_VERSION -q $QUAL:$BUILDTYPE || exit 1

set +x
source localProducts*/setup || exit 1

set -x
cd $MRB_SOURCE  || exit 1
# make sure we get a read-only copy
mrb g -r sbndqm@$SBNDQM || exit 1

#don't pull sbncode
#if [ -z "$SBNCODE" ]; then
#    # Extract sbncode version from sbncode product_deps
#    SBNCODE=`grep sbncode $MRB_SOURCE/sbndqm/ups/product_deps | grep -v qualifier | awk '{print $2}'`
#fi
#echo "sbncode version: $SBNCODE"
#mrb g -r sbncode@$SBNCODE || exit 1

if [ -z "$SBNDAQ_ONLINE" ]; then
    # Extract sbnobj version from sbncode product_deps
    SBNDAQ_ONLINE=`grep sbndaq_online $MRB_SOURCE/sbndqm/ups/product_deps | grep -v qualifier | awk '{print $2}'`
fi
echo "sbndaq_online version: $SBNDAQ_ONLINE"
mrb g -r sbndaq_online@$SBNDAQ_ONLINE || exit 1

cd $MRB_BUILDDIR || exit 1
mrbsetenv || exit 1
mrb b -j$ncores || exit 1
if uname | grep -q Linux; then
  cp /usr/lib64/libXmu.so.6 sbncode/lib
fi
mrb mp -n sbndqm -- -j$ncores || exit 1

manifest=sbndqm-*_MANIFEST.txt

# Extract larsoft version from product_deps.
sbncode_version=`grep sbncode $MRB_SOURCE/sbndqm/ups/product_deps | grep -v qualifier | awk '{print $2}'`
sbncode_dot_version=`echo ${sbncode_version} |  sed -e 's/_/./g' | sed -e 's/^v//'`

# Extract flavor.
flvr=`ups flavor -4`

# Construct name of larsoft manifest.

sbncode_hyphen_qual=`echo $QUAL | tr : - | sed 's/-noifdh//'`
sbncode_manifest=sbn-${sbncode_dot_version}-${flvr}-${sbncode_hyphen_qual}-${BUILDTYPE}_MANIFEST.txt
echo "sbncode manifest:"
echo $sbncode_manifest
echo

# Fetch larsoft manifest from scisoft and append to sbncode manifest.

curl --fail --silent --location --insecure http://scisoft.fnal.gov/scisoft/bundles/sbn/${sbncode_version}/manifest/${sbncode_manifest} >> $manifest || exit 1

if echo $QUAL | grep -q noifdh; then
   # Delete the manifest entirely.
  rm -f $manifest
fi

# Save artifacts.

mv *.bz2  $WORKSPACE/copyBack/ || exit 1
manifest=sbndqm-*_MANIFEST.txt
if [ -f $manifest ]; then
  mv $manifest  $WORKSPACE/copyBack/ || exit 1
fi
cp $MRB_BUILDDIR/sbndqm/releaseDB/*.html $WORKSPACE/copyBack/
ls -l $WORKSPACE/copyBack/
cd $WORKSPACE || exit 1
rm -rf $WORKSPACE/temp || exit 1
set +x

exit 0
