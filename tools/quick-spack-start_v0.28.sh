#! /bin/bash
# quick-mrb-start.sh - Eric Flumerfelt, May 20, 2016
# Downloads, installs, and runs the artdaq_demo as an MRB-controlled repository

git_status=`git status 2>/dev/null`
git_sts=$?
if [ $git_sts -eq 0 ];then
    echo "This script is designed to be run in a fresh install directory!"
    exit 1
fi

echo "$0 $@" >$PWD/quick-spack-start.lastrun.sh

starttime=`date`
Base=$PWD
test -d qms-log || mkdir qms-log

env_opts_var=`basename $0 | sed 's/\.sh$//' | tr 'a-z-.' 'A-Z__'`_OPTS
USAGE="\
   usage: `basename $0` [options] [demo_root]
examples: `basename $0` .
          `basename $0` --run-demo
          `basename $0` --debug
          `basename $0` --tag v2_08_04
If the \"demo_root\" optional parameter is not supplied, the user will be
prompted for this location.
--run-demo    runs the demo
--develop     Install the develop version of the software (may be unstable!)
--dev-only    Do not install the suite in an environment (use with upstreams!)
--mfext       Use artdaq_mfextensions Destinations by default
--tag         Install a specific tag of artdaq_demo
--logdir      Set <dir> as the destination for log files
--datadir     Set <dir> as the destination for data files
--recordsdir  Set <dir> as the destination for run record information
--spackdir    Install Spack in this directory (or use existing installation)
-s            Use specific qualifiers when building ARTDAQ
-v            Be more verbose
-x            set -x this script
-w            Check out repositories read/write
--upstream    Use <dir> as a Spack upstream (repeatable)
--no-use-cvmfs Do not search /cvmfs/fermilab.opensciencegrid.org/products/artdaq/spack_v0.28 for upstreams
              If --upstream is used, CVMFS will not be automatically searched for upstreams
--no-view     Do not create Spack environment views
--padding     Pad paths to 255 characters for relocatability
--pcp         Install the artdaq-pcp-mmv-plugin metric component
--caen        Install the artdaq-caen plugin for CAEN digitizer support
--no-kmod     Do not build TRACE kernel module (for Docker builds)
--arch        Architecture for build (Defaults to linux-almalinux9-x86_64_v3)
--host-arch   Use Spack-default arch
"

# Process script arguments and options
eval env_opts=\${$env_opts_var-} # can be args too
datadir="${ARTDAQDEMO_DATA_DIR:-$Base/daqdata}"
logdir="${ARTDAQDEMO_LOG_DIR:-$Base/daqlogs}"
recordsdir="${ARTDAQDEMO_RECORD_DIR:-$Base/run_records}"
spackdir="${ARTDAQDEMO_SPACK_DIR:-$Base/spack}"
arch=""
tag=develop
upstreams=()
installStatus=0
eval "set -- $env_opts \"\$@\""
op1chr='rest=`expr "$op" : "[^-]\(.*\)"`   && set -- "-$rest" "$@"'
op1arg='rest=`expr "$op" : "[^-]\(.*\)"`   && set --  "$rest" "$@"'
reqarg="$op1arg;"'test -z "${1+1}" &&echo opt -$op requires arg. &&echo "$USAGE" &&exit'
args= do_help= opt_v=0; opt_w=0; opt_develop=0; opt_padding=0; opt_pcp=0; opt_caen=0; opt_no_kmod=0; opt_no_view=0; opt_dev_only=0; opt_use_cvmfs=1; opt_host_arch=0
while [ -n "${1-}" ];do
    if expr "x${1-}" : 'x-' >/dev/null;then
        op=`expr "x$1" : 'x-\(.*\)'`; shift   # done with $1
        leq=`expr "x$op" : 'x-[^=]*\(=\)'` lev=`expr "x$op" : 'x-[^=]*=\(.*\)'`
        test -n "$leq"&&eval "set -- \"\$lev\" \"\$@\""&&op=`expr "x$op" : 'x\([^=]*\)'`
        case "$op" in
            \?*|h*)         eval $op1chr; do_help=1;;
            v*)             eval $op1chr; opt_v=`expr $opt_v + 1`;;
            x*)             eval $op1chr; set -x;;
            s*)             eval $op1arg; squalifier=$1; shift;;
            w*)             eval $op1chr; opt_w=`expr $opt_w + 1`;;
            -run-demo)      opt_run_demo=--run-demo;;
            -develop)       opt_develop=1;;
            -dev-only)      opt_dev_only=1;;
            -tag)           eval $reqarg; tag=$1; shift;;
            -logdir)        eval $op1arg; logdir=$1; shift;;
            -datadir)       eval $op1arg; datadir=$1; shift;;
            -recordsdir)    eval $op1arg; recordsdir=$1; shift;;
            -spackdir)      eval $op1arg; spackdir=$1; shift;;
            -arch)          eval $op1arg; arch=$1; shift;;
            -host-arch)     opt_host_arch=1;;
            -mfext)         opt_mfext=1;;
            -upstream)      eval $op1arg; upstreams+=($1); opt_use_cvmfs=0; shift;;
            -padding)       opt_padding=1;;
            -pcp)           opt_pcp=1;;
            -caen)          opt_caen=1;;
            -no-kmod)       opt_no_kmod=1;;
            -no-view)       opt_no_view=1;;
            -no-use-cvmfs)  opt_use_cvmfs=0;;
            *)              echo "Unknown option -$op"; do_help=1;;
        esac
    else
        aa=`echo "$1" | sed -e"s/'/'\"'\"'/g"` args="$args '$aa'"; shift
    fi
done
eval "set -- $args \"\$@\""; unset args aa

test -n "${do_help-}" -o $# -ge 2 && echo "$USAGE" && exit

if [ "x$SPACK_ROOT" == "x$spackdir" ]; then
  echo "Using pre-existing Spack installation $SPACK_ROOT.\nIf this is not correct, hit Ctrl-C and run 'unset SPACK_ROOT'."
  sleep 5
  spack env deactivate
fi

# JCF, 1/16/15
# Save all output from this script (stdout + stderr) in a file with a
# name that looks like "quick-start.sh_Fri_Jan_16_13:58:27.script" as
# well as all stderr in a file with a name that looks like
# "quick-start.sh_Fri_Jan_16_13:58:27_stderr.script"
alloutput_file=$( date | awk -v "SCRIPTNAME=$(basename $0)" '{print SCRIPTNAME"_"$1"_"$2"_"$3"_"$4".script"}' )
stderr_file=$( date | awk -v "SCRIPTNAME=$(basename $0)" '{print SCRIPTNAME"_"$1"_"$2"_"$3"_"$4"_stderr.script"}' )
exec  > >(tee "$Base/qms-log/$alloutput_file")
exec 2> >(tee "$Base/qms-log/$stderr_file")

svariant=""

if [ -n "${squalifier-}" ]; then
    svariant="s=${squalifier}"
fi

pcp_opt="~pcp"
if [ $opt_pcp -eq 1 ];then
  pcp_opt="+pcp"
fi

caen_opt="~caen"
if [ $opt_caen -eq 1 ];then
    caen_opt="+caen"
fi

view_opt=""
if [ $opt_no_view -eq 1 ];then
    view_opt="--without-view"
fi

build_system_script=`find $Base/srcs $Base -maxdepth 4 -type f -name setup_spack_build_system_v0.28.sh|head -1`
if [[ "x$build_system_script" == "x" ]];then
  echo "WARNING: setup_spack_build_system_v0.28.sh not found, downloading from https://github.com/art-daq/artdaq-demo"
  cd $Base
  wget https://raw.githubusercontent.com/art-daq/artdaq_demo/refs/heads/develop/tools/setup_spack_build_system_v0.28.sh
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

if [[ $tag == "develop" ]] && [[ $opt_dev_only -eq 0 ]]; then
    tag=`spack list --format=version_json artdaq-suite|jq ".[]|.latest_version"| sed -e 's/^"//' -e 's/"$//'`
fi

concrete_include_cmd=

os_long=$(spack arch -o)

if [ $opt_host_arch -eq 1 ]; then
    arch_opt=""
elif [[ "x$arch" != "x" ]]; then
    arch_opt="arch=$arch"
else
    arch_opt="arch=linux-${os_long}-x86_64_v3"
fi

os=$(echo ${os_long//./_}|sed 's/almalinux/al/;s/ubuntu/u/')
if [ $opt_use_cvmfs -eq 1 ] && [ -d /cvmfs/fermilab.opensciencegrid.org/products/artdaq/spack_v0.28 ]; then
  if [ $opt_dev_only -eq 1 ]; then
    artdaq=`ls -d /cvmfs/fermilab.opensciencegrid.org/products/artdaq/spack_v0.28/artdaq-*-${os}|tail -1`
    upstreams+=($artdaq)
  else
    art=`ls -d /cvmfs/fermilab.opensciencegrid.org/products/artdaq/spack_v0.28/art-suite-*-${os}|tail -1`
    upstreams+=($art)
  fi
fi

# If updating upstreams, clear existing file first
if [ ${#upstreams[@]} -gt 0 ]; then
  rm $spackdir/etc/spack/upstreams.yaml
fi

for upstream in ${upstreams[@]}; do
    echo "Adding upstream $upstream"
    for upstreamdir in `find $upstream -type f -wholename '*/.spack-db/index.json'|grep -v bootstrap 2>/dev/null`; do
        echo "Getting real directory for upstream database $upstreamdir"
        upstreamdir=`dirname $upstreamdir`
        upstreamdir=`dirname $upstreamdir`
        upstreamdir=`realpath $upstreamdir`
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

    # Get this upstream's upstreams
    if [ -f $upstream/spack/etc/spack/upstreams.yaml ]; then
        tail -n +2 $upstream/spack/etc/spack/upstreams.yaml >>$spackdir/etc/spack/upstreams.yaml
    fi

    for envdir in `find $upstream -type d -wholename '*/var/spack/environments' 2>/dev/null`; do
        echo "Looking for artdaq environments in $envdir"

        environment="artdaq-${tag}-${os_long//./_}"
        if ! [ -d $environment ]; then continue; fi
        environment_dir=`realpath $environment`
        echo "Adding environment $environment_dir to include-concrete list"
        concrete_include_cmd="$concrete_include_cmd --include-concrete $environment_dir"
    done
done

spack reindex

cd $Base

BUILD_J=$((`cat /proc/cpuinfo|grep processor|tail -1|awk '{print $3}'` + 1))
env_name=artdaq-${tag}-${os}
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

if [ ${opt_dev_only:-0} -eq 0 ];then
    spack env create ${concrete_include_cmd} ${view_opt} ${env_name}
    spack env activate ${env_name}

    ln -s ${spackdir}/var/spack/environments/${env_name}

    if [ $opt_no_kmod -eq 1 ];then
        spack add trace~kmod
    else
        spack add trace+kmod
    fi

    spack add artdaq-suite@${tag} ${svariant} +demo ${pcp_opt} ${caen_opt} $arch_opt %gcc${gccver:+@${gccver}}
    spack add node-js@22.4.0 # Newer Node.js does not build correctly on AL10
    env_to_activate=${env_name}

    spack concretize --deprecated --force && spack install --deprecated -j $BUILD_J
    installStatus=$?
fi

function checkout_package()
{
    pkg=$1
    if ! [ -d $pkg ]; then
        if [ $opt_w -eq 0 ];then
            git clone https://github.com/art-daq/$pkg.git
        else
            git clone git@github.com:art-daq/$pkg.git
        fi
    else
        cd $pkg
        git pull
        cd ..
    fi
}

if [[ ${opt_develop:-0} -eq 1 ]];then
    spack env deactivate
    env_to_activate="artdaq-develop"

    spack mpd init -r site -u $Base/spack-repos/mpd

    cd $Base
    mkdir srcs
    cd srcs
    for pkg in artdaq artdaq-core artdaq-core-demo artdaq-database artdaq-demo artdaq-epics-plugin artdaq-mfextensions artdaq-utilities artdaq-daqinterface trace artdaq-suite;do
        checkout_package $pkg
    done
    if [ $opt_pcp -eq 1 ];then
        checkout_package artdaq-pcp-mmv-plugin
    fi
    if [ $opt_caen -eq 1 ];then
        checkout_package artdaq-caen
    fi
    cd $Base

    if [ ${opt_dev_only:-0} -eq 0 ];then
        spack mpd new-project --force -y --name artdaq-develop -E ${env_name} cxxstd=20 %gcc${gccver:+@${gccver}}
    else
        spack mpd new-project --force -y --name artdaq-develop cxxstd=20 %gcc${gccver:+@${gccver}}
    fi
    spack env activate artdaq-develop
    spack mpd build -G Ninja
    installStatus=$?
    if [ $installStatus -eq 0 ]; then
        cd $Base/build
        ninja install
        installStatus=$?
        cd $Base
    fi
fi

cd $Base
    cat >setupARTDAQDEMO <<-EOF
echo # This script is intended to be sourced.

if [ \${ARTDAQ_SETUP:-0} -eq 0 ]; then
  # Save environment
  declare -x >$Base/.env_before_setupARTDAQDEMO
fi

sh -c "[ \`ps \$\$ | grep bash | wc -l\` -gt 0 ] || { echo 'Please switch to the bash shell before running the artdaq-demo.'; exit; }" || exit
export SPACK_DISABLE_LOCAL_CONFIG=true
export SPACK_USER_CACHE_PATH=$Base/.spack-cache
source $spackdir/share/spack/setup-env.sh

spack env activate ${env_to_activate}

if [ -d $Base/local/install ]; then
  export PATH=$Base/local/install/bin:\$PATH
  export LD_LIBRARY_PATH=$Base/local/install/lib:\$LD_LIBRARY_PATH
  export CET_PLUGIN_PATH=$Base/local/install/lib:\$CET_PLUGIN_PATH
  export FHICL_FILE_PATH=$Base/local/install/fcl:\$FHICL_FILE_PATH
  export ARTDAQ_DAQINTERFACE_DIR=$Base/local/install
  source trace_functions.sh
fi

k5user=\`klist|grep "Default principal"|cut -d: -f2|sed 's/@.*//;s/ //'\`
export TRACE_FILE=/tmp/trace_buffer_\$USER.\$k5user

export ARTDAQ_DAQINTERFACE_VERSION=SPACK
#export ARTDAQDEMO_BASE_PORT=52200
export DAQ_INDATA_PATH=\$ARTDAQ_DEMO_DIR/test/Generators
${opt_mfext+export ARTDAQ_MFEXTENSIONS_ENABLED=1}

export ARTDAQDEMO_ROOT=$Base
export ARTDAQDEMO_DATA_DIR=${datadir}
export ARTDAQDEMO_LOG_DIR=${logdir}

echo Check for Toy...
IFSsav=\$IFS IFS=:; for dd in \$LD_LIBRARY_PATH;do IFS=\$IFSsav; ls \$dd/*Toy* 2>/dev/null ;done
echo ...done with check for Toy

alias rawEventDump="if [[ -n \\\$SETUP_TRACE ]]; then unsetup TRACE ; echo Disabling TRACE so that it will not affect rawEventDump output ; sleep 1; fi; art -c rawEventDump.fcl"
alias mpd="spack mpd"
# Note that the Ninja install command is needed to activate built changes!
alias mb="spack mpd build -G Ninja;pushd $Base/build;ninja install;popd"

if [ \${ARTDAQ_SETUP:-0} -eq 0 ]; then
  # Now save a copy of the environment after setup
  declare -x >$Base/.env_after_setupARTDAQDEMO
  # Next, remove any variables that haven't changed
  grep -v -x -Ff $Base/.env_before_setupARTDAQDEMO $Base/.env_after_setupARTDAQDEMO >$Base/artdaq_demo_rte.sh
fi
export ARTDAQ_SETUP=1

EOF
#


# Now, install DAQInterface, basically following the instructions at
# https://cdcvs.fnal.gov/redmine/projects/artdaq-utilities/wiki/Artdaq-daqinterface

daqintdir=$Base/DAQInterface

# Nov-21-2017: in order to allow for more than one DAQInterface to run
# on the system at once, we need to take it from its current HEAD of
# the develop branch, 6c15e15c0f6e06282f2fd5dd8ad478659fdb29bd

cd $Base

if ! [ -d $daqintdir ]; then
  mkdir $daqintdir
  cd $daqintdir
  ln -s ../setupARTDAQDEMO mock_ups_setup.sh

  git clone https://github.com/art-daq/artdaq_daqinterface
  cp artdaq_daqinterface/docs/* . && rm -rf artdaq_daqinterface

  sed -i -r 's!^\s*export DAQINTERFACE_SETTINGS.*!export DAQINTERFACE_SETTINGS='$PWD/settings_example'!' user_sourcefile_example
  sed -i -r 's!^\s*export DAQINTERFACE_KNOWN_BOARDREADERS_LIST.*!export DAQINTERFACE_KNOWN_BOARDREADERS_LIST='$PWD/known_boardreaders_list_example'!' user_sourcefile_example
  sed -i -r '/export DAQINTERFACE_USER_SOURCEFILE_ERRNO=0/i \
  export yourArtdaqInstallationDir='$Base'  ' user_sourcefile_example
  sed -i -r "s!DAQINTERFACE_LOGDIR=.*!DAQINTERFACE_LOGDIR=$logdir!" user_sourcefile_example

  mkdir -p $recordsdir
  chmod g+w $recordsdir
  sed -i -r 's!^\s*record_directory.*!record_directory: '$recordsdir'!' settings_example

  mkdir -p $logdir
  chmod g+w $logdir
  sed -i -r 's!^\s*log_directory.*!log_directory: '$logdir'!' settings_example

  mkdir -p $datadir
  chmod g+w $datadir
  sed -i -r 's!^\s*data_directory_override.*!data_directory_override: '$datadir'!' settings_example

  sed -i -r 's!^\s*DAQ setup script:.*!DAQ setup script: '$Base'/artdaq_demo_rte.sh!' boot*.txt

  sed -i -r 's!^\s*productsdir_for_bash_scripts:.*!spack_root_for_bash_scripts: '"$spackdir"'!' settings_example
  cd $Base
fi

if [ "x${opt_run_demo-}" != "x" ]; then
    if [ $installStatus -eq 0 ]; then
    echo doing the demo

    run_demo.sh --basedir $Base --toolsdir ${Base}/srcs/artdaq_demo/tools
    else
        echo 'Build error (see above) precludes running the demo (i.e --run-demo option specified)'
    fi
fi


endtime=`date`

echo "Build start time: $starttime"
echo "Build end time:   $endtime"

exit $installStatus
