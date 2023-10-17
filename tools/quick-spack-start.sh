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

env_opts_var=`basename $0 | sed 's/\.sh$//' | tr 'a-z-' 'A-Z_'`_OPTS
USAGE="\
   usage: `basename $0` [options] [demo_root]
examples: `basename $0` .
		  `basename $0` --run-demo
		  `basename $0` --debug
		  `basename $0` --tag v2_08_04
If the \"demo_root\" optional parameter is not supplied, the user will be
prompted for this location.
--run-demo    runs the demo
--debug       perform a debug build
--develop     Install the develop version of the software (may be unstable!)
--viewer      install and run the artdaq Message Viewer
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
--no-extra-products  Skip the automatic use of central product areas, such as CVMFS
"

# Process script arguments and options
eval env_opts=\${$env_opts_var-} # can be args too
datadir="${ARTDAQDEMO_DATA_DIR:-$Base/daqdata}"
logdir="${ARTDAQDEMO_LOG_DIR:-$Base/daqlogs}"
recordsdir="${ARTDAQDEMO_RECORD_DIR:-$Base/run_records}"
spackdir="${ARTDAQDEMO_SPACK_DIR:-$Base/spack}"
eval "set -- $env_opts \"\$@\""
op1chr='rest=`expr "$op" : "[^-]\(.*\)"`   && set -- "-$rest" "$@"'
op1arg='rest=`expr "$op" : "[^-]\(.*\)"`   && set --  "$rest" "$@"'
reqarg="$op1arg;"'test -z "${1+1}" &&echo opt -$op requires arg. &&echo "$USAGE" &&exit'
args= do_help= opt_v=0; opt_w=0; opt_develop=0; opt_skip_extra_products=0; opt_no_pull=0
while [ -n "${1-}" ];do
	if expr "x${1-}" : 'x-' >/dev/null;then
		op=`expr "x$1" : 'x-\(.*\)'`; shift   # done with $1
		leq=`expr "x$op" : 'x-[^=]*\(=\)'` lev=`expr "x$op" : 'x-[^=]*=\(.*\)'`
		test -n "$leq"&&eval "set -- \"\$lev\" \"\$@\""&&op=`expr "x$op" : 'x\([^=]*\)'`
		case "$op" in
			\?*|h*)     eval $op1chr; do_help=1;;
			v*)         eval $op1chr; opt_v=`expr $opt_v + 1`;;
			x*)         eval $op1chr; set -x;;
			s*)         eval $op1arg; squalifier=$1; shift;;
			e*)         eval $op1arg; equalifier=$1; shift;;
            c*)         eval $op1arg; cqualifier=$1; shift;;
			w*)         eval $op1chr; opt_w=`expr $opt_w + 1`;;
			-run-demo)  opt_run_demo=--run-demo;;
			-debug)     opt_debug=--debug;;
			-develop) opt_develop=1;;
			-tag)       eval $reqarg; tag=$1; shift;;
			-viewer)    opt_viewer=--viewer;;
			-logdir)    eval $op1arg; logdir=$1; shift;;
			-datadir)   eval $op1arg; datadir=$1; shift;;
			-recordsdir) eval $op1arg; recordsdir=$1; shift;;
			-spackdir)  eval $op1arg; spackdir=$1; shift;;
			-no-extra-products)  opt_skip_extra_products=1;;
			-mfext)     opt_mfext=1;;
			-no-pull)   opt_no_pull=1;;
			*)          echo "Unknown option -$op"; do_help=1;;
		esac
	else
		aa=`echo "$1" | sed -e"s/'/'\"'\"'/g"` args="$args '$aa'"; shift
	fi
done
eval "set -- $args \"\$@\""; unset args aa

test -n "${do_help-}" -o $# -ge 2 && echo "$USAGE" && exit

if [[ -n "${tag:-}" ]] && [[ $opt_develop -eq 1 ]]; then 
	echo "The \"--tag\" and \"--develop\" options are incompatible - please specify only one."
	exit
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

# Get all the information we'll need to decide which exact flavor of the software to install
notag=0
if [ -z "${tag:-}" ]; then 
  tag=develop;
  notag=1;
fi
wget https://raw.githubusercontent.com/art-daq/artdaq-demo/$tag/CMakeLists.txt
demo_version=v`grep "project" $Base/CMakeLists.txt|grep -oE "VERSION [^)]*"|awk '{print $2}'|sed 's/\./_/g'`
echo "Demo Version is $demo_version"
if [[ $notag -eq 1 ]] && [[ $opt_develop -eq 0 ]]; then
  tag=$demo_version

  # 06-Mar-2017, KAB: re-fetch the product_deps file based on the tag
  mv CMakeLists.txt CMakeLists.txt.orig
  wget https://raw.githubusercontent.com/art-daq/artdaq_demo/$tag/CMakeLists.txt
  demo_version=v`grep "project" $Base/CMakeLists.txt|grep -oE "VERSION [^)]*"|awk '{print $2}'|sed 's/\./_/g'`
  tag=$demo_version
fi

defaultS="s124"

if [ -n "${squalifier-}" ]; then
	squalifier="${squalifier}"
else
	squalifier="${defaultS#s}"
fi
compiler_info="" # Maybe do e- and c- qualifiers?

if ! [ -d $spackdir ];then
	$(
    cd ${spackdir%/spack}
    git clone https://github.com/FNALssi/spack.git -b fnal-develop
    cd spack
    git checkout 28793268e7c943ad75347fe8ccbabfa30ef189b2 # For now
        )
fi

source $spackdir/share/spack/setup-env.sh

repo_found=`spack repo list|grep -c fnal_art`
if [ $repo_found -eq 0 ]; then
    cd $spackdir/var/spack/repos
    git clone https://github.com/FNALssi/fnal_art.git
    spack repo add ./fnal_art
fi

if ! [ -f ~/.spack/packages.yaml ];then
	# Fetch appropriate packages.yaml from Github
	if [ `uname -r|grep -c el7` -gt 0 ];then
		# SL7 version
		packurl="https://raw.githubusercontent.com/art-daq/artdaq-demo/develop/tools/packages.yaml.sl7"
	else
		# AL9 version
		packurl="https://raw.githubusercontent.com/art-daq/artdaq-demo/develop/tools/packages.yaml.al9"
	fi
	curl -o $spackdir/etc/spack/packages.yaml $packurl
fi

cd $Base
spack compiler find

spack env create artdaq
spack env activate artdaq

#spack add art-suite@s$squalifier
#spack concretize --force
#spack install

spack add artdaq-suite@${demo_version}${compiler_info} s=${squalifier} +demo~pcp
spack concretize --force
spack install

	cat >setupARTDAQDEMO <<-EOF
echo # This script is intended to be sourced.

sh -c "[ \`ps \$\$ | grep bash | wc -l\` -gt 0 ] || { echo 'Please switch to the bash shell before running the artdaq-demo.'; exit; }" || exit

source $spackdir/share/spack/setup-env.sh
spack env activate artdaq

export TRACE_NAME=TRACE

#export ARTDAQDEMO_BASE_PORT=52200
export DAQ_INDATA_PATH=$ARTDAQ_DEMO_DIR/test/Generators
${opt_mfext+export ARTDAQ_MFEXTENSIONS_ENABLED=1}

export ARTDAQDEMO_DATA_DIR=${datadir}
export ARTDAQDEMO_LOG_DIR=${logdir}

echo Check for Toy...
IFSsav=\$IFS IFS=:; for dd in \$LD_LIBRARY_PATH;do IFS=\$IFSsav; ls \$dd/*Toy* 2>/dev/null ;done
echo ...done with check for Toy

alias rawEventDump="if [[ -n \\\$SETUP_TRACE ]]; then unsetup TRACE ; echo Disabling TRACE so that it will not affect rawEventDump output ; sleep 1; fi; art -c rawEventDump.fcl"

EOF
#


# Now, install DAQInterface, basically following the instructions at
# https://cdcvs.fnal.gov/redmine/projects/artdaq-utilities/wiki/Artdaq-daqinterface

daqintdir=$Base/DAQInterface

# Nov-21-2017: in order to allow for more than one DAQInterface to run
# on the system at once, we need to take it from its current HEAD of
# the develop branch, 6c15e15c0f6e06282f2fd5dd8ad478659fdb29bd

cd $Base
mkdir $daqintdir
cd $daqintdir
ln -s ../setupARTDAQDEMO mock_ups_setup.sh
cp $ARTDAQ_DAQINTERFACE_DIR/docs/* .

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

sed -i -r 's!^\s*DAQ setup script:.*!DAQ setup script: '$Base'/setupARTDAQDEMO!' boot*.txt

sed -i -r 's!^\s*productsdir_for_bash_scripts:.*!productsdir_for_bash_scripts: '"$PRODUCTS"'!' settings_example

cd $Base

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
