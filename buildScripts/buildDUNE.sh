#!/bin/bash

# build dunetpc
# trj Feb 23, 2018: skip building lbne_raw_data and dune_raw_data
# trj May 3, 2018: skip building duneutil
# use mrb
# designed to work on Jenkins

echo "dunetpc version: $DUNE"
echo "base qualifiers: $QUAL"
echo "larsoft qualifiers: $LARSOFT_QUAL"
echo "build type: $BUILDTYPE"
echo "workspace: $WORKSPACE"

# Don't do ifdh build on macos.

#if uname | grep -q Darwin; then
#  if ! echo $QUAL | grep -q noifdh; then
#    echo "Ifdh build requested on macos.  Quitting."
#    exit
#  fi
#fi

# Get number of cores to use.

if [ `uname` = Darwin ]; then
  #ncores=`sysctl -n hw.ncpu`
  #ncores=$(( $ncores / 4 ))
  ncores=4
else
  ncores=`cat /proc/cpuinfo 2>/dev/null | grep -c -e '^processor'`
fi
if [ $ncores -lt 1 ]; then
  ncores=1
fi
echo "Building using $ncores cores."

# Environment setup, uses /grid/fermiapp or cvmfs.

echo "ls /cvmfs/dune.opensciencegrid.org/products/dune/"
ls /cvmfs/dune.opensciencegrid.org/products/dune/
echo

if [ `uname` = Darwin -a -f /grid/fermiapp/products/dune/setup_dune_fermiapp.sh ]; then
  source /grid/fermiapp/products/dune/setup_dune_fermiapp.sh || exit 1
elif [ -f /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh ]; then
  if [ -x /cvmfs/grid.cern.ch/util/cvmfs-uptodate ]; then
    /cvmfs/grid.cern.ch/util/cvmfs-uptodate /cvmfs/dune.opensciencegrid.org/products
  fi
  source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh || exit 1
else
  echo "No setup file found."
  exit 1
fi

# Use system git on macos.

if ! uname | grep -q Darwin; then
  setup git || exit 1
fi
setup gitflow || exit 1
export MRB_PROJECT=dune
echo "Mrb path:"
which mrb

# make the timeouts longer and accept low-speed transfers

export GIT_HTTP_LOW_SPEED_LIMIT=1000
export GIT_HTTP_LOW_SPEED_TIME=600

#dla set -x
rm -rf $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/copyBack || exit 1
rm -f $WORKSPACE/copyBack/* || exit 1
cd $WORKSPACE/temp || exit 1
mrb newDev -v $DUNE -q $QUAL:$BUILDTYPE || exit 1

#dla set +x
source localProducts*/setup || exit 1

# some shenanigans so we can use getopt v1_1_6
if [ `uname` = Darwin ]; then
#  cd $MRB_INSTALL
#  curl --fail --silent --location --insecure -O http://scisoft.fnal.gov/scisoft/packages/getopt/v1_1_6/getopt-1.1.6-d13-x86_64.tar.bz2 || \
#      { cat 1>&2 <<EOF
#ERROR: pull of http://scisoft.fnal.gov/scisoft/packages/getopt/v1_1_6/getopt-1.1.6-d13-x86_64.tar.bz2 failed
#EOF
#        exit 1
#      }
#  tar xf getopt-1.1.6-d13-x86_64.tar.bz2 || exit 1
  setup getopt v1_1_6  || exit 1
#  which getopt
fi

#dla set -x
cd $MRB_SOURCE  || exit 1
# make sure we get a read-only copy
# put some retry logic here instead

ntries=0
until [ $ntries -ge 10 ]
do
  mrb g -r -t $DUNE dunetpc && break
  ntries=$[$ntries+1]
done
if [ $ntries = 10 ]; then
  echo "Could not clone dunetpc using mrb g.  Quitting."
  exit 1
fi

## Extract duneutil version from dunetpc product_deps
#duneutil_version=`grep duneutil $MRB_SOURCE/dunetpc/ups/product_deps | grep -v qualifier | awk '{print $2}'`
#echo "duneutil version: $duneutil_version"
#mrb g -r -t $duneutil_version duneutil || exit 1


cd $MRB_BUILDDIR || exit 1
mrbsetenv || exit 1
mrb b -j$ncores || exit 1
mrb mp -n dune -- -j$ncores || exit 1

# add dune_data to the manifest

manifest=dune-*_MANIFEST.txt
dune_pardata_version=`grep dune_pardata $MRB_SOURCE/dunetpc/ups/product_deps | grep -v qualifier | awk '{print $2}'`
dune_pardata_dot_version=`echo ${dune_pardata_version} | sed -e 's/_/./g' | sed -e 's/^v//'`
echo "dune_pardata         ${dune_pardata_version}       dune_pardata-${dune_pardata_dot_version}-noarch.tar.bz2" >>  $manifest

# get platform
OS=$(uname)
case $OS in
    Linux)
        PLATFORM=$(uname -r | grep -o "el[0-9]"|sed s'/el/slf/')
        ;;
    Darwin)
        PLATFORM=$(uname -r | awk -F. '{print "d"$1}')
        ;;
esac

# need to check out dune_raw_data to get the dunepdsrpce version -- do it here, after the build

cd $MRB_SOURCE || exit 1

# Extract dune_raw_data version from our ups active list

dune_raw_data_version=`ups active | grep dune_raw_data | awk '{print $2}'`
echo "dune_raw_data version: $dune_raw_data_version"
artqual=`ups active | grep dune_raw_data | awk '{print $6}'   | sed -e "s/${QUAL}//g" | sed -e "s/nu//g" | sed -e "s/://g" | sed -e "s/${BUILDTYPE}//g"`
lbne_raw_data_version=`ups active | grep lbne_raw_data | awk '{print $2}'`
echo "lbne_raw_data version: $lbne_raw_data_version"

cd $MRB_BUILDDIR

# also add dune_raw_data and lbne_raw_data to the manifest

dune_raw_data_dot_version=`echo ${dune_raw_data_version} | sed -e 's/_/./g' | sed -e 's/^v//'`
echo "dune_raw_data         ${dune_raw_data_version}       dune_raw_data-${dune_raw_data_dot_version}-${PLATFORM}-x86_64-${QUAL}-nu-${artqual}-${BUILDTYPE}.tar.bz2" >>  $manifest
lbne_raw_data_dot_version=`echo ${lbne_raw_data_version} | sed -e 's/_/./g' | sed -e 's/^v//'`
echo "lbne_raw_data         ${lbne_raw_data_version}       lbne_raw_data-${lbne_raw_data_dot_version}-${PLATFORM}-x86_64-${QUAL}-nu-${artqual}-${BUILDTYPE}.tar.bz2" >>  $manifest

# add dunepdsprce to the manifest

dunepdsprce_version=`ups active | grep dunepdsprce | awk '{print $2}'`
echo "dunepdsprce version: $dunepdsprce_version"
dunepdsprce_dot_version=`echo ${dunepdsprce_version} | sed -e 's/_/./g' | sed -e 's/^v//'`
echo "dunepdsprce          ${dunepdsprce_version}          dunepdsprce-${dunepdsprce_dot_version}-${PLATFORM}-x86_64-gen-${QUAL}-${BUILDTYPE}.tar.bz2" >>  $manifest

# Extract larsoft version from product_deps.

larsoft_version=`grep larsoft $MRB_SOURCE/dunetpc/ups/product_deps | grep -v qualifier | awk '{print $2}'`
larsoft_dot_version=`echo ${larsoft_version} |  sed -e 's/_/./g' | sed -e 's/^v//'`

# Extract flavor.

flvr=''
if uname | grep -q Darwin; then
  flvr=`ups flavor -2`
else
  flvr=`ups flavor -4`
fi

# Construct name of larsoft manifest.

larsoft_hyphen_qual=`echo $LARSOFT_QUAL | tr : - | sed 's/-noifdh//'`
larsoft_manifest=larsoft-${larsoft_dot_version}-${flvr}-${larsoft_hyphen_qual}-${BUILDTYPE}_MANIFEST.txt
echo "Larsoft manifest:"
echo $larsoft_manifest
echo

# Fetch laraoft manifest from scisoft and append to dunetpc manifest.

echo "curl --fail --silent --location --insecure http://scisoft.fnal.gov/scisoft/bundles/larsoft/${larsoft_version}/manifest/${larsoft_manifest} >> $manifest || exit 1"

curl --fail --silent --location --insecure http://scisoft.fnal.gov/scisoft/bundles/larsoft/${larsoft_version}/manifest/${larsoft_manifest} >> $manifest || exit 1

echo "Done with the curl command."

# Special handling of noifdh builds goes here.

if echo $QUAL | grep -q noifdh; then

  if uname | grep -q Darwin; then

    # If this is a macos build, then rename the manifest to remove noifdh qualifier in the name

    noifdh_manifest=`echo $manifest | sed 's/-noifdh//'`
    mv $manifest $noifdh_manifest

  else

    # Otherwise (for slf builds), delete the manifest entirely.

    rm -f $manifest

  fi
fi

# Save artifacts.

echo "Moving tarballs to copyBack"

mv *.bz2  $WORKSPACE/copyBack/ || exit 1

echo "Moving manifest to copyBack"

manifest=dune-*_MANIFEST.txt
if [ -f $manifest ]; then
  mv $manifest  $WORKSPACE/copyBack/ || exit 1
fi
#cp $MRB_BUILDDIR/dunetpc/releaseDB/*.html $WORKSPACE/copyBack/
ls -l $WORKSPACE/copyBack/
cd $WORKSPACE || exit 1
rm -rf $WORKSPACE/temp || exit 1
#dla set +x

exit 0
