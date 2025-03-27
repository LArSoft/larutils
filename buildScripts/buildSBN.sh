#!/bin/bash

# build sbncode
# use mrb
# designed to work on Jenkins
# this is a proof of concept script

echo "sbncode version: $SBN_VERSION"
echo "sbncode tag: $SBN"
echo "sbnalg tag: $SBNALG"
echo "sbnobj tag: $SBNOBJ"
echo "sbnanaobj tag: $SBNANAOBJ"
echo "sbndaq_artdaq_core tag: $SBNDAQ_ARTDAQ_CORE"
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
export MRB_PROJECT=sbn
echo "Mrb path:"
which mrb

set -x
rm -rf $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/copyBack || exit 1
rm -f $WORKSPACE/copyBack/* || exit 1
cd $WORKSPACE/temp || exit 1
mrb newDev  -v $SBN_VERSION -q $QUAL:$BUILDTYPE || exit 1

set +x
source localProducts*/setup || exit 1

set -x
cd $MRB_SOURCE  || exit 1
# make sure we get a read-only copy
mrb g -r sbncode@$SBN || exit 1

if [ -z "$SBNALG" ]; then
    # Extract sbnalg version from sbnalg product_deps
    SBNALG=`grep sbnalg $MRB_SOURCE/sbncode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
fi
echo "sbnalg version: $SBNALG"
mrb g -r sbnalg@$SBNALG || exit 1

if [ -z "$SBNOBJ" ]; then
    # Extract sbnobj version from sbncode product_deps
    SBNOBJ=`grep sbnobj $MRB_SOURCE/sbncode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
fi
echo "sbnobj version: $SBNOBJ"
mrb g -r sbnobj@$SBNOBJ || exit 1

if [ -z "$SBNANAOBJ" ]; then
    # Extract sbnanaobj version from sbncode product_deps
    SBNANAOBJ=`grep sbnanaobj $MRB_SOURCE/sbncode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
fi
echo "sbnanaobj version: $SBNANAOBJ"
mrb g -r sbnanaobj@$SBNANAOBJ || exit 1

if [ -z "$SBNDAQ_ARTDAQ_CORE" ]; then
    # Extract sbndaq_artdaq_core version from sbncode product_deps
    SBNDAQ_ARTDAQ_CORE=`grep sbndaq_artdaq_core $MRB_SOURCE/sbncode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
fi
echo "sbndaq_artdaq_core version: $SBNDAQ_ARTDAQ_CORE"
mrb g -r sbndaq_artdaq_core@$SBNDAQ_ARTDAQ_CORE || exit 1

cd $MRB_BUILDDIR || exit 1
mrbsetenv || exit 1
mrb b -j$ncores || exit 1
if uname | grep -q Linux; then
  cp /usr/lib64/libXmu.so.6 sbncode/lib
fi
mrb mp -n sbn -- -j$ncores || exit 1

manifest=sbn-*_MANIFEST.txt

# Extract larsoft version from product_deps.
larsoft_version=`grep larsoft $MRB_SOURCE/sbncode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
larsoft_dot_version=`echo ${larsoft_version} |  sed -e 's/_/./g' | sed -e 's/^v//'`

# Extract flavor.
flvr=`ups flavor -4`

# Construct name of larsoft manifest.

larsoft_hyphen_qual=`echo $SQUAL:$QUAL | tr : - | sed 's/-noifdh//'`
larsoft_manifest=larsoft-${larsoft_dot_version}-${flvr}-${larsoft_hyphen_qual}-${BUILDTYPE}_MANIFEST.txt
echo "Larsoft manifest:"
echo $larsoft_manifest
echo

# Fetch larsoft manifest from scisoft and append to sbncode manifest.

curl --fail --silent --location --insecure http://scisoft.fnal.gov/scisoft/bundles/larsoft/${larsoft_version}/manifest/${larsoft_manifest} >> $manifest || exit 1

if echo $QUAL | grep -q noifdh; then
   # Delete the manifest entirely.
  rm -f $manifest
fi

# Save artifacts.

mv *.bz2  $WORKSPACE/copyBack/ || exit 1
manifest=sbn-*_MANIFEST.txt
if [ -f $manifest ]; then
  mv $manifest  $WORKSPACE/copyBack/ || exit 1
fi
cp $MRB_BUILDDIR/sbncode/releaseDB/*.html $WORKSPACE/copyBack/
ls -l $WORKSPACE/copyBack/
cd $WORKSPACE || exit 1
rm -rf $WORKSPACE/temp || exit 1
set +x

exit 0
