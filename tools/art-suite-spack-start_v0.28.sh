#! /bin/bash
# quick-mrb-start.sh - Eric Flumerfelt, May 20, 2016
# Downloads, installs, and runs the artdaq_demo as an MRB-controlled repository

git_status=`git status 2>/dev/null`
git_sts=$?
if [ $git_sts -eq 0 ];then
    echo "This script is designed to be run in a fresh install directory!"
    exit 1
fi

starttime=`date`
Base=$PWD
test -d qms-log || mkdir qms-log

env_opts_var=`basename $0 | sed 's/\.sh$//' | tr 'a-z-.' 'A-Z__'`_OPTS
USAGE="\
   usage: `basename $0` [options] [demo_root]
examples: `basename $0` .
          `basename $0` -s 132
If the \"demo_root\" optional parameter is not supplied, the user will be
prompted for this location.
--spackdir    Install Spack in this directory (or use existing installation)
-s            Use specific qualifiers when building ARTDAQ
-v            Be more verbose
-x            set -x this script
--upstream    Use <dir> as a Spack upstream (repeatable)
--no-view     Do not create Spack environment views
--padding     Pad paths to 255 characters for relocatability
--arch        Architecture for build (defaults to linux-almalinux9-x86_64_v3)
--host-arch   Use Spack-default arch
"

# Process script arguments and options
eval env_opts=\${$env_opts_var-} # can be args too
spackdir="${ARTDAQDEMO_SPACK_DIR:-$Base/spack}"
arch=""
upstreams=()
installStatus=0
eval "set -- $env_opts \"\$@\""
op1chr='rest=`expr "$op" : "[^-]\(.*\)"`   && set -- "-$rest" "$@"'
op1arg='rest=`expr "$op" : "[^-]\(.*\)"`   && set --  "$rest" "$@"'
reqarg="$op1arg;"'test -z "${1+1}" &&echo opt -$op requires arg. &&echo "$USAGE" &&exit'
args= do_help= opt_develop=0; opt_padding=0; opt_pcp=0; opt_no_kmod=0; opt_no_view=0; opt_host_arch=0
while [ -n "${1-}" ];do
    if expr "x${1-}" : 'x-' >/dev/null;then
        op=`expr "x$1" : 'x-\(.*\)'`; shift   # done with $1
        leq=`expr "x$op" : 'x-[^=]*\(=\)'` lev=`expr "x$op" : 'x-[^=]*=\(.*\)'`
        test -n "$leq"&&eval "set -- \"\$lev\" \"\$@\""&&op=`expr "x$op" : 'x\([^=]*\)'`
        case "$op" in
            \?*|h*)     eval $op1chr; do_help=1;;
            x*)         eval $op1chr; set -x;;
            s*)         eval $op1arg; squalifier=$1; shift;;
            -spackdir)  eval $op1arg; spackdir=$1; shift;;
            -arch)      eval $op1arg; arch=$1; shift;;
            -host-arch) opt_host_arch=1;;
            -upstream)  eval $op1arg; upstreams+=($1); shift;;
            -padding)   opt_padding=1;;
            -no-view)   opt_no_view=1;;
            *)          echo "Unknown option -$op"; do_help=1;;
        esac
    else
        aa=`echo "$1" | sed -e"s/'/'\"'\"'/g"` args="$args '$aa'"; shift
    fi
done
eval "set -- $args \"\$@\""; unset args aa

test -n "${do_help-}" -o $# -ge 2 && echo "$USAGE" && exit


# JCF, 1/16/15
# Save all output from this script (stdout + stderr) in a file with a
# name that looks like "quick-start.sh_Fri_Jan_16_13:58:27.script" as
# well as all stderr in a file with a name that looks like
# "quick-start.sh_Fri_Jan_16_13:58:27_stderr.script"
alloutput_file=$( date | awk -v "SCRIPTNAME=$(basename $0)" '{print SCRIPTNAME"_"$1"_"$2"_"$3"_"$4".script"}' )
stderr_file=$( date | awk -v "SCRIPTNAME=$(basename $0)" '{print SCRIPTNAME"_"$1"_"$2"_"$3"_"$4"_stderr.script"}' )
exec  > >(tee "$Base/qms-log/$alloutput_file")
exec 2> >(tee "$Base/qms-log/$stderr_file")


defaultS="s133"
BUILD_J=$((`cat /proc/cpuinfo|grep processor|tail -1|awk '{print $3}'` + 1))

if [ -n "${squalifier-}" ]; then
    squalifier="${squalifier}"
else
    squalifier="${defaultS#s}"
fi

view_opt=""
if [ $opt_no_view -eq 1 ];then
    view_opt="--without-view"
fi

build_system_script=`find $Base/srcs $Base -maxdepth 4 -type f -name setup_spack_build_system_v0.28.sh|head -1`
if [[ "x$build_system_script" == "x" ]];then
  echo "WARNING: setup_spack_build_system_v0.28.sh not found, downloading from https://github.com/art-daq/artdaq-demo"
  wget https://raw.githubusercontent.com/art-daq/artdaq_demo/refs/heads/develop/tools/setup_spack_build_system_v0.28.sh $Base/setup_spack_build_system_v0.28.sh
  build_system_script=$Base/setup_spack_build_system_v0.28.sh
fi

echo "5827e2df97f9fbf30c435aaced7fbd381dd68d79 *$build_system_script" | sha1sum -c -
if [ $? -ne 0 ]; then
  echo "ERROR: setup_spack_build_system_v0.28.sh does not have the expected checksum! Please check Github for updates to this script!"
  exit 1
fi

source $build_system_script
# Note that install_spack_build_system sources setup-env.sh
install_spack_build_system $Base $spackdir $opt_padding

os_long=$(spack arch -o)

if [ $opt_host_arch -eq 1 ]; then
    arch_opt=""
elif [[ "x$arch" != "x" ]]; then
    arch_opt="arch=$arch"
else
    arch_opt="arch=linux-${os_long}-x86_64_v3"
fi

os=$(echo ${os_long//./_}|sed 's/almalinux/al/;s/ubuntu/u/')
env_name="art-s${squalifier//./_}-${os}"

for upstream in ${upstreams[@]}; do
    for upstreamdir in `find $upstream -type f -wholename */.spack-db/index.json 2>/dev/null`; do

        upstreamdir=`dirname $upstreamdir`
        upstreamdir=`dirname $upstreamdir`
        upstreamname=`echo $upstreamdir|sed 's|/__spack[^/]*||g;s|/spack/opt/spack||g'`

        if ! [ -d $upstreamdir/.spack-db ]; then
            echo "No Spack instance found at $upstream!"
            continue
        fi

        if ! [ -f $spackdir/etc/spack/upstreams.yaml ]; then
            echo "upstreams:" > $spackdir/etc/spack/upstreams.yaml
        fi

        if [ `grep -c $upstreamdir $spackdir/etc/spack/upstreams.yaml` -eq 0 ]; then
            # Only add upstream if not already present
            echo "  upstream${upstreamname//\//-}:" >>$spackdir/etc/spack/upstreams.yaml
            echo "    install_tree: $upstreamdir" >>$spackdir/etc/spack/upstreams.yaml
        fi
    done

done

spack reindex

cd $Base

gccver=13.1.0
if [ "$os_long" == "almalinux10" ];then
    gccver=13.3.0
fi

if [ "x$gccver" != "x" ];then
    spack load --first gcc@${gccver} >/dev/null 2>&1
    if [ $? -ne 0 ];then
      spack install --deprecated -j $BUILD_J gcc@${gccver} $arch_opt +binutils
      installStatus=$?
      spack load gcc@${gccver}
    fi
fi
spack compiler find

spack env create ${view_opt} ${env_name}
spack env activate ${env_name}

ln -s ${spackdir}/var/spack/environments/${env_name}

spack add art-suite@s${squalifier} +root $arch_opt ${gccver:+%gcc@${gccver}}
spack add art %gcc

spack concretize --force --deprecated && spack install --deprecated -j $BUILD_J
installStatus=$?

endtime=`date`

echo "Build start time: $starttime"
echo "Build end time:   $endtime"

exit $installStatus
