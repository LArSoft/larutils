#!/bin/bash

# build "third party" products

usage()
{
  cat 1>&2 <<EOF
Usage: $(basename ${0}) [-h]
       $(basename ${0}) <version> <qual_set> <build_type>
       env WORKSPACE=<workspace> LARVER=<larsoft version> QUAL=<qualifier> BUILDTYPE=<debug|prof> $(basename ${0})

Options:

  -h    This help.

EOF
}

have_label() {
  for label in "${labels[@]}"; do
    for wanted in "$@"; do
      [[ "${label}" == "${wanted}" ]] && return 0
    done
  done
  return 1
}


while getopts :h OPT; do
  case ${OPT} in
    h)
      usage
      exit 1
      ;;
    *)
      usage
      exit 1
  esac
done
shift `expr $OPTIND - 1`
OPTIND=1

working_dir="${WORKSPACE:-$(pwd)}"
version="${1:-${LARVER}}"
qual_set="${2:-${QUAL}}"
oIFS=${IFS}; IFS=:; quals=(${qual_set//-/:}); IFS=$oIFS; unset oIFS
build_type="${3:-${BUILDTYPE}}"

labels=()
for onequal in "${quals[@]}"; do
  if [[ "${onequal}" =~ ^([ec])([0-9]+)$ ]]; then
    basequal=${onequal}
  elif [[ "${onequal}" =~ ^(s)([1-9][0-9]+)$ ]]; then
    squal=${onequal}
  else
      labels+=${onequal}
  fi
done

case ${build_type} in
  debug) ;;
  prof) ;;
  *)
    usage
    exit 1
esac

# create copyBack so artifact copy does not fail on early exit
rm -rf "${working_dir}/copyBack"
mkdir -p "${working_dir}/copyBack" || exit 1

# Find platform flavor.
OS=`uname`
if [ "${OS}" = "Linux" ]
then
  id=`lsb_release -is`
  if [ "${id}" = "Ubuntu" ]
  then
    flvr=u`lsb_release -r | sed -e 's/[[:space:]]//g' | cut -f2 -d":" | cut -f1 -d"."`
  else
    flvr=slf`lsb_release -r | sed -e 's/[[:space:]]//g' | cut -f2 -d":" | cut -f1 -d"."`
  fi
elif [ "${OS}" = "Darwin" ]
then
  flvr=d`uname -r | cut -f1 -d"."`
  # set locale
  echo
  locale
  echo
  export LANG=C
  export LC_ALL=$LANG
  locale
  echo
else
  echo "ERROR: unrecognized operating system ${OS}"
  exit 1
fi

# Check supported builds.
if [[ `uname -s` == Darwin ]]; then
  OSnum=`uname -r | cut -f1 -d"."`
  xver=`xcodebuild -version | grep Xcode | cut -f2 -d" " | cut -f1 -d"."`
  xcver=`xcodebuild -version | grep Xcode`
  if { [[ ${basequal} =~ ^e(9$|[1-9][0-9]) ]] && \
    [[ ${xver} < 7 ]] && \
    [[ ${OSnum} > 13 ]]; }; then
    # XCode too old on this platform.
    echo "${basequal} build not supported on `uname -s`${OSnum} with ${xcver}"
    echo "${basequal} build not supported on `uname -s`${OSnum} with ${xcver}" > \
      "${working_dir}/copyBack/skipping_build"
    exit 0
  elif { [[ "$basequal" == e* ]] || \
    { [[ "$basequal" == c* ]] && (( $OSnum < 15 )); }; }; then
    if want_unsupported; then
      echo "Building unsupported ${basequal} on `uname -s`${OSnum} due to \$CET_BUILD_UNSUPPORTED=${CET_BUILD_UNSUPPORTED}"
    else
      # Don't normally support GCC builds on MacOS.
      msg="${basequal} build not supported on `uname -s`${OSnum} -- export CET_BUILD_UNSUPPORTED=1 to override."
      echo "$msg"
      echo "$msg" > "${working_dir}/copyBack/skipping_build"
      exit 0
    fi
  fi
  if have_label py2; then
    msg="We are not building for Python2 on Darwin."
    echo "${msg}"
    echo "${msg}" > "${working_dir}/copyBack/skipping_build"
    exit 0
  fi
elif [[ "${flvr}" == slf6 ]]; then
  if have_label py2; then
    echo "Building for supported Python2 on SLF6"
  else
    msg="Python3 builds not supported on SLF6."
    echo "${msg}"
    echo "${msg}" > "${working_dir}/copyBack/skipping_build"
    exit 0
  fi
fi

export UPS_OVERRIDE='-H Linux64bit+3.10-2.17'

dotver=`echo ${version} | sed -e 's/_/./g' | sed -e 's/^v//'`

echo "building the larsoft product stack for ${version} ${dotver} ${qual_set} ${build_type}"
echo "build flavor is ${flvr}"
echo ""

qualdir=`echo ${qual_set} | sed -e 's%:%-%'`

set -x

blddir=${working_dir}/build
srcdir=${working_dir}/source
# start with clean directories
rm -rf ${blddir}
rm -rf ${srcdir}
# now make the dfirectories
mkdir -p ${srcdir} || exit 1
mkdir -p ${blddir} || exit 1

buildFW="${working_dir}/artutilscripts/tools/buildFW"

cd ${blddir} || exit 1

if [ -z "${buildFW}" ]; then
  curl --fail --silent --location --insecure -O http://scisoft.fnal.gov/scisoft/bundles/tools/buildFW || exit 1
  chmod +x buildFW
  buildFW="${blddir}/buildFW"
fi

cd ${blddir} || exit 1
echo
echo "begin build"
echo
(( ${#labels[@]} > 0 )) && lopt=-l
${buildFW} -t -b ${basequal} \
  ${lopt} $(IFS=:; printf '%s' "${labels[*]}") \
  ${blddir} ${build_type} lar_product_stack-${version} || \
 { mv ${blddir}/*.log  "${working_dir}/copyBack/"
   exit 1
 }

echo
echo "move files"
echo
mv ${blddir}/*source* ${srcdir}/
mv ${blddir}/g*noarch* ${srcdir}/
mv ${blddir}/*.bz2  $WORKSPACE/copyBack/
mv ${blddir}/*.txt  $WORKSPACE/copyBack/
echo
echo "cleanup"
echo
rm -rf ${srcdir}
rm -rf ${blddir}

exit 0
