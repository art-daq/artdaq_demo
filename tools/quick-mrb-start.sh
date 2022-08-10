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
test -d products || mkdir products
test -d download || mkdir download
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
--no-pull     Ignore status from pullProducts
--recordsdir  Set <dir> as the destination for run record information
-e, -s, -c    Use specific qualifiers when building ARTDAQ
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
set -u   # complain about uninitialed shell variables - helps development

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

function detectAndPull() {
	local startDir=$PWD
	cd $Base/download
	local packageName=$1
	local packageOs=$2
	if [[ "$packageOs" != "noarch" ]]; then
		local packageOsArch="$2-x86_64"
		packageOs=`echo $packageOsArch|sed 's/-x86_64-x86_64/-x86_64/g'`
	fi

	if [ $# -gt 2 ];then
		local qualifiers=$3
		if [[ "$qualifiers" == "nq" ]]; then
			qualifiers=
		fi
	fi
	if [ $# -gt 3 ];then
		local packageVersion=$4
	else
		local packageVersion=`curl http://scisoft.fnal.gov/scisoft/packages/${packageName}/ 2>/dev/null|grep ${packageName}|grep "id=\"v"|tail -1|sed 's/.* id="\(v.*\)".*/\1/'`
	fi
	local packageDotVersion=`echo $packageVersion|sed 's/_/\./g'|sed 's/v//'`

	if [[ "$packageOs" != "noarch" ]]; then
		local upsflavor=`ups flavor`
                if [ -n "${qualifiers-}" ];then
                	local packageQualifiers="-`echo $qualifiers|sed 's/:/-/g'`"
		        local packageUPSString="-f $upsflavor -q$qualifiers"
                fi
	fi
	local packageInstalled=`ups list -aK+ $packageName $packageVersion ${packageUPSString-}|grep -c "$packageName"`
	if [ $packageInstalled -eq 0 ]; then
	    local packagePath="$packageName/$packageVersion/$packageName-$packageDotVersion-${packageOs}${packageQualifiers-}.tar.bz2"
                echo INFO: about to wget $packageName-$packageDotVersion-${packageOs}${packageQualifiers-}
		wget --load-cookies=$cookief http://scisoft.fnal.gov/scisoft/packages/$packagePath >/dev/null 2>&1
		local packageFile=$( echo $packagePath | awk 'BEGIN { FS="/" } { print $NF }' )

		if [[ ! -e $packageFile ]]; then
			if [[ "$packageOs" == "slf7-x86_64" ]]; then
				# Try sl7, as they're both valid...
				detectAndPull $packageName sl7-x86_64 ${qualifiers:-"nq"} $packageVersion
			else
				echo "Unable to download $packageName"
				return 1
			fi
		else
			local returndir=$PWD
			cd $Base/products
			tar -xjf $Base/download/$packageFile
			cd $returndir
		fi
	fi
	cd $startDir
}

#
# urlencode -- encode special characters for post/get arguments
#
urlencode() {
   perl -pe 'chomp(); s{\W}{sprintf("%%%02x",ord($&))}ge;' "$@"
}

site=https://cdcvs.fnal.gov/redmine
listf=/tmp/list_p$$
cookief=/tmp/cookies_p$$
rlverbose=${rlverbose:=false}
#
# login form
#
do_login() {
     get_passwords
     get_auth_token "${site}/login"
     post_url  \
       "${site}/login" \
       "back_url=$site" \
       "authenticity_token=$authenticity_token" \
       "username=`echo $user | urlencode`" \
       "password=`echo $pass | urlencode`" \
       "login=Login »" 
     if grep '>Sign in' $listf > /dev/null;then
        echo "Login failed."
        false
     else
        true
     fi
}
get_passwords() {
   case "x${user-}y${pass-}" in
   xy)
       if [ -r   ${REDMINE_AUTHDIR:-.}/.redmine_lib_passfile ];then 
	   read -r user pass < ${REDMINE_AUTHDIR:-.}/.redmine_lib_passfile
       else
	   user=$USER
           stty -echo
	   printf "Services password for $user: "
	   read pass
           stty echo
       fi;;
    esac
}
get_auth_token() {
    authenticity_token=`fetch_url "${1}" |
                  tee /tmp/at_p$$ |
                  grep 'name="authenticity_token"' |
                  head -1 |
                  sed -e 's/.*value="//' -e 's/".*//' | 
                  urlencode `
}

#
# fetch_url -- GET a url from a site, maintaining cookies, etc.
#
fetch_url() {
     wget \
        --no-check-certificate \
	--load-cookies=${cookief} \
        --referer="${lastpage-}" \
	--save-cookies=${cookief} \
	--keep-session-cookies \
	-o ${debugout:-/dev/null} \
	-O - \
	"$1"  | ${debugfilter:-cat}
     lastpage="$1"
}

#
# post_url POST to a url maintaining cookies, etc.
#    takes a url and multiple form data arguments
#    which are joined with "&" signs
#
post_url() {
     url="$1"
     extra=""
     if  [ "$url" == "-b" ];then
         extra="--remote-encoding application/octet-stream"
         shift
         url=$1
     fi
     shift
     the_data=""
     sep=""
     df=/tmp/postdata$$
     :>$df
     for d in "$@";do
        printf "%s" "$sep$d" >> $df
        sep="&"
     done
     wget -O $listf \
        -o $listf.log \
        --debug \
        --verbose \
        $extra \
        --no-check-certificate \
	--load-cookies=${cookief} \
	--save-cookies=${cookief} \
        --referer="${lastpage-}" \
	--keep-session-cookies \
        --post-file="$df"  $url
     if grep '<div.*id=.errorExplanation' $listf > /dev/null;then
        echo "Failed: error was:"
        cat $listf | sed -e '1,/<div.*id=.errorExplanation/d' | sed -e '/<.div>/,$d'
        return 1
     fi
     if grep '<div.*id=.flash_notice.*Success' $listf > /dev/null;then
        $rlverbose && echo "Succeeded"
        return 0
     fi
     # not sure if it worked... 
     $rlverbose && echo "Unknown -- detagged output:"
     $rlverbose && cat $listf | sed -e 's/<[^>]*>//g'
     $rlverbose && echo "-----"
     $rlverbose && cat $listf.log
     $rlverbose && echo "-----"
     return 0
} # post_url

do_login https://cdcvs.fnal.gov/redmine

cd $Base/download

# 28-Feb-2017, KAB: use central products areas, if available and not skipped
# 10-Mar-2017, ELF: Re-working how this ends up in the setupARTDAQDEMO script
PRODUCTS_SET=""
if [[ $opt_skip_extra_products -eq 0 ]]; then
  FERMIOSG_ARTDAQ_DIR="/cvmfs/fermilab.opensciencegrid.org/products/artdaq"
  FERMIAPP_ARTDAQ_DIR="/grid/fermiapp/products/artdaq"
  for dir in $FERMIOSG_ARTDAQ_DIR $FERMIAPP_ARTDAQ_DIR;
  do
	# if one of these areas has already been set up, do no more
	for prodDir in $(echo ${PRODUCTS:-""} | tr ":" "\n")
	do
	  if [[ "$dir" == "$prodDir" ]]; then
		break 2
	  fi
	done
	if [[ -f $dir/setup ]]; then
	  echo "Setting up artdaq UPS area... ${dir}"
	  source $dir/setup
	  break
	fi
  done
  CENTRAL_PRODUCTS_AREA="/products"
  for dir in $CENTRAL_PRODUCTS_AREA;
  do
	# if one of these areas has already been set up, do no more
	for prodDir in $(echo ${PRODUCTS:-""} | tr ":" "\n")
	do
	  if [[ "$dir" == "$prodDir" ]]; then
		break 2
	  fi
	done
	if [[ -f $dir/setup ]]; then
	  echo "Setting up central UPS area... ${dir}"
	  source $dir/setup
	  break
	fi
  done
  PRODUCTS_SET="${PRODUCTS:-}"
fi

echo "Cloning cetpkgsupport to determine current OS"
git clone http://cdcvs.fnal.gov/projects/cetpkgsupport
os=`./cetpkgsupport/bin/get-directory-name os`

if [[ "$os" == "u14" ]]; then
	echo "-H Linux64bit+3.19-2.19" >../products/ups_OVERRIDE.`hostname`
fi

# Get all the information we'll need to decide which exact flavor of the software to install
notag=0
if [ -z "${tag:-}" ]; then 
  tag=develop;
  notag=1;
fi
if [[ -e product_deps ]]; then mv product_deps product_deps.save; fi
wget --load-cookies=$cookief https://cdcvs.fnal.gov/redmine/projects/artdaq-demo/repository/revisions/$tag/raw/ups/product_deps
wget --load-cookies=$cookief https://cdcvs.fnal.gov/redmine/projects/artdaq-demo/repository/revisions/$tag/raw/CMakeLists.txt
demo_version=v`grep "project" $Base/download/CMakeLists.txt|grep -oE "VERSION [^)]*"|awk '{print $2}'|sed 's/\./_/g'`
echo "Demo Version is $demo_version"
if [[ $notag -eq 1 ]] && [[ $opt_develop -eq 0 ]]; then
  tag=$demo_version

  # 06-Mar-2017, KAB: re-fetch the product_deps file based on the tag
  mv product_deps product_deps.orig
  mv CMakeLists.txt CMakeLists.txt.orig
  wget --load-cookies=$cookief https://cdcvs.fnal.gov/redmine/projects/artdaq-demo/repository/revisions/$tag/raw/ups/product_deps
  wget --load-cookies=$cookief https://cdcvs.fnal.gov/redmine/projects/artdaq-demo/repository/revisions/$tag/raw/CMakeLists.txt
  demo_version=v`grep "project" $Base/download/CMakeLists.txt|grep -oE "VERSION [^)]*"|awk '{print $2}'|sed 's/\./_/g'`
  tag=$demo_version
fi
artdaq_version=`grep "^artdaq[ 	]" $Base/download/product_deps | awk '{print $2}'`
coredemo_version=`grep "^artdaq_core_demo[ 	]" $Base/download/product_deps | awk '{print $2}'`
defaultQuals=`grep "defaultqual" $Base/download/product_deps|awk '{print $2}'`

defaultE=`echo $defaultQuals|cut -f1 -d:`
defaultS=`echo $defaultQuals|cut -f2 -d:`
if [ -n "${equalifier-}" ]; then 
	equalifier="e${equalifier}";
elif [ -n "${cqualifier-}" ]; then
    equalifier="c${cqualifier-}";
else
	equalifier=$defaultE
fi
if [ -n "${squalifier-}" ]; then
	squalifier="s${squalifier}"
else
	squalifier=$defaultS
fi
if [[ -n "${opt_debug:-}" ]] ; then
	build_type="debug"
else
	build_type="prof"
fi

wget --load-cookies=$cookief http://scisoft.fnal.gov/scisoft/bundles/tools/pullProducts
rm -f /tmp/postdata$$ /tmp/at_p$$ $cookief $listf
chmod +x pullProducts
./pullProducts $Base/products ${os} artdaq_demo-${demo_version} ${squalifier}-${equalifier} ${build_type}
mrbversion=`grep mrb *_MANIFEST.txt|sort|tail -1|awk '{print $2}'`

	if [ $? -ne 0 ]; then
	echo "Error in pullProducts. Please go to http://scisoft.fnal.gov/scisoft/bundles/artdaq_demo/${demo_version}/manifest and make sure that a manifest for the specified qualifiers (${squalifier}-${equalifier}) exists."
		if [ $opt_no_pull -eq 0 ]; then
			exit 1
		fi
	fi
export PRODUCTS=$PRODUCTS_SET
source $Base/products/setup
PRODUCTS_SET=$PRODUCTS
echo PRODUCTS after source products/setup: $PRODUCTS
detectAndPull mrb noarch nq $mrbversion
setup mrb $mrbversion
setup git
setup gitflow

export MRB_PROJECT=artdaq_demo
cd $Base
mrb newDev -f -v $demo_version -q ${equalifier}:${squalifier}:${build_type}
set +u
source $Base/localProducts_artdaq_demo_${demo_version}_${equalifier}_${squalifier}_${build_type}/setup
set -u

echo artdaq_version=$artdaq_version demo_version=$demo_version coredemo_version=$coredemo_version

cd $MRB_SOURCE
if [[ $opt_develop -eq 1 ]]; then
	if [ $opt_w -gt 0 ];then
		mrb gitCheckout ssh://git@github.com/art-daq/artdaq_core
		mrb gitCheckout ssh://git@github.com/art-daq/artdaq_utilities
		mrb gitCheckout ssh://git@github.com/art-daq/artdaq
		mrb gitCheckout ssh://git@github.com/art-daq/artdaq_core_demo
		mrb gitCheckout ssh://git@github.com/art-daq/artdaq_demo
		mrb gitCheckout ssh://git@github.com/art-daq/artdaq_epics_plugin
		mrb gitCheckout ssh://git@github.com/art-daq/artdaq_mfextensions
	else
		mrb gitCheckout https://github.com/art-daq/artdaq_core
		mrb gitCheckout https://github.com/art-daq/artdaq_utilities
                mrb gitCheckout https://github.com/art-daq/artdaq
                mrb gitCheckout https://github.com/art-daq/artdaq_core_demo
                mrb gitCheckout https://github.com/art-daq/artdaq_demo
                mrb gitCheckout https://github.com/art-daq/artdaq_epics_plugin
                mrb gitCheckout https://github.com/art-daq/artdaq_mfextensions
	fi
else
	if [ $opt_w -gt 0 ];then
		mrb gitCheckout -t ${coredemo_version} ssh://git@github.com/art-daq/artdaq_core_demo
		mrb gitCheckout -t ${demo_version}     ssh://git@github.com/art-daq/artdaq_demo
		mrb gitCheckout -t ${artdaq_version}   ssh://git@github.com/art-daq/artdaq
		mrb gitCheckout -t artdaq-${artdaq_version}   ssh://git@github.com/art-daq/artdaq_utilities
	else
		mrb gitCheckout -t ${coredemo_version} https://github.com/art-daq/artdaq_core_demo
		mrb gitCheckout -t ${demo_version}     https://github.com/art-daq/artdaq_demo
		mrb gitCheckout -t ${artdaq_version}   https://github.com/art-daq/artdaq
		mrb gitCheckout -t artdaq-${artdaq_version}   https://github.com/art-daq/artdaq_utilities
	fi
fi

os=`$Base/download/cetpkgsupport/bin/get-directory-name os`
test "$os" = "slf7" && os="sl7"
if [[ "x${opt_viewer-}" != "x" ]] && [[ $opt_develop -eq 1 ]]; then
	mrb gitCheckout -d artdaq_mfextensions http://cdcvs.fnal.gov/projects/mf-extensions-git
	qtver=$( awk '/^[[:space:]]*qt[[:space:]]*/ {print $2}' artdaq_mfextensions/ups/product_deps )
	detectAndPull qt ${os}-x86_64 ${equalifier} ${qtver}
fi
for vv in `awk '/cetbuildtools/{print$2}' */ups/product_deps | sort -u`;do
	detectAndPull cetbuildtools noarch nq $vv
        # the following looks for a missing cmake in the depend error output or a non-missing cmake in normal output
        cmake_ver=`ups depend cetbuildtools $vv 2>&1 | sed -n -e '/cmake /{s/.*cmake //;s/ .*//;p;}'`
        detectAndPull cmake ${os}-x86_64 nq $cmake_ver
done
for vv in `awk '/TRACE\s*v/{print$2}' */ups/product_deps | sort -u`;do
	detectAndPull TRACE ${os}-x86_64 nq $vv
done

ARTDAQ_DEMO_DIR=$Base/srcs/artdaq_demo
ARTDAQ_DIR=$Base/srcs/artdaq
cd $Base
	cat >setupARTDAQDEMO <<-EOF
echo # This script is intended to be sourced.

sh -c "[ \`ps \$\$ | grep bash | wc -l\` -gt 0 ] || { echo 'Please switch to the bash shell before running the artdaq-demo.'; exit; }" || exit

echo "initial PRODUCTS=\${PRODUCTS-}"
echo "resetting to demo start: $PRODUCTS_SET"
export PRODUCTS="$PRODUCTS_SET"
if echo ":\$PRODUCTS:" | grep :/cvmfs/fermilab.opensciencegrid.org/products/artdaq: >/dev/null;then
  : already there
elif [[ -e /cvmfs/fermilab.opensciencegrid.org/products/artdaq ]]; then
  # /cvmfs exists but wasn't in the orginal, so append to end
  PRODUCTS="\$PRODUCTS:/cvmfs/fermilab.opensciencegrid.org/products/artdaq/setup"
fi

source $Base/products/setup

# AT THIS POINT, verify PRODUCTS directories; produce warngings for any nonexistent directories
echo PRODUCTS cleanup and check...
PRODUCTS=\`dropit -D -E -p"\$PRODUCTS"\`
if [ "\$PRODUCTS" != "$PRODUCTS_SET" ]; then
    echo WARNING: PRODUCTS environment has changed from initial installation.
    echo "current \"\$PRODUCTS\" != demo start \"$PRODUCTS_SET\""
fi

unsetup git >/dev/null 2>&1
if [ -z \$CET_SUBDIR ];then
  unsetup cetpkgsupport >/dev/null 2>&1
  unset CET_PLATINFO
  setup cetpkgsupport
fi
echo ...done with cleanup and check

setup mrb $mrbversion
source $Base/localProducts_artdaq_demo_${demo_version}_${equalifier}_${squalifier}_${build_type}/setup
if [ \$# -ge 1 -a "\${1-}" = for_running -a -e "\$MRB_BUILDDIR/\$MRB_PROJECT-\$MRB_PROJECT_VERSION" ];then
   source "\${MRB_DIR}/libexec/shell_independence"; source "\$MRB_BUILDDIR/\$MRB_PROJECT-\$MRB_PROJECT_VERSION"
else
   mrbsetenv
fi

export TRACE_NAME=TRACE

export ARTDAQDEMO_REPO=$ARTDAQ_DEMO_DIR
export ARTDAQDEMO_BUILD=$MRB_BUILDDIR/artdaq_demo
#export ARTDAQDEMO_BASE_PORT=52200
export DAQ_INDATA_PATH=$ARTDAQ_DEMO_DIR/test/Generators
${opt_mfext+export ARTDAQ_MFEXTENSIONS_ENABLED=1}

export ARTDAQDEMO_DATA_DIR=${datadir}
export ARTDAQDEMO_LOG_DIR=${logdir}

export FHICL_FILE_PATH=\$ARTDAQDEMO_BUILD/fcl:\$ARTDAQ_DEMO_DIR/tools/fcl:\$FHICL_FILE_PATH

echo Check for Toy...
IFSsav=\$IFS IFS=:; for dd in \$LD_LIBRARY_PATH;do IFS=\$IFSsav; ls \$dd/*Toy* 2>/dev/null ;done
echo ...done with check for Toy

alias rawEventDump="if [[ -n \\\$SETUP_TRACE ]]; then unsetup TRACE ; echo Disabling TRACE so that it will not affect rawEventDump output ; sleep 1; fi; art -c \$ARTDAQ_DIR/fcl/rawEventDump.fcl"

EOF
#

# Build artdaq_demo
cd $MRB_BUILDDIR
set +u
mrbsetenv
set -u
PRODUCTS=`dropit -D -E -p"$PRODUCTS"`    # clean it
export CETPKG_J=$((`cat /proc/cpuinfo|grep processor|tail -1|awk '{print $3}'` + 1))
ups active
mrb build    # VERBOSE=1
installStatus=$?

if [ $installStatus -eq 0 ]; then
	echo "artdaq-demo has been installed correctly. Please see: "
	echo "https://cdcvs.fnal.gov/redmine/projects/artdaq-demo/wiki/Running_a_sample_artdaq-demo_system"
	echo "for instructions on how to run, or re-run this script with the --run-demo option"
	echo
	echo "Will now install DAQInterface as described at https://cdcvs.fnal.gov/redmine/projects/artdaq-utilities/wiki/Artdaq-daqinterface..."
else
	echo "BUILD ERROR!!! SOMETHING IS VERY WRONG!!!"
	echo
	echo "Continuing with installation of DAQInterface, with the hope there is a simple fix for the BUILD ERROR"
	echo
fi

# Now, install DAQInterface, basically following the instructions at
# https://cdcvs.fnal.gov/redmine/projects/artdaq-utilities/wiki/Artdaq-daqinterface

daqintdir=$Base/DAQInterface

# Nov-21-2017: in order to allow for more than one DAQInterface to run
# on the system at once, we need to take it from its current HEAD of
# the develop branch, 6c15e15c0f6e06282f2fd5dd8ad478659fdb29bd

cd $Base

if [ $opt_w -gt 0 ];then
    git clone git@github.com:art-daq/artdaq_daqinterface.git 
else
    git clone https://github.com/art-daq/artdaq_daqinterface
fi
cd artdaq_daqinterface
if [[ $opt_develop -eq 1 ]]; then 
    git checkout develop
else
    # JCF, Sep-25-2018: grep out the protodune DAQInterface series when searching for the newest DAQInterface version...

    artdaq_daqinterface_version=$( git tag --sort creatordate | grep -v "v3_00_0[0-9].*" | tail -1 )
    echo "Checking out version $artdaq_daqinterface_version of artdaq_daqinterface"
    git checkout $artdaq_daqinterface_version # Fetch latest tagged version
fi

mkdir $daqintdir
cd $daqintdir
cp ../artdaq_daqinterface/bin/mock_ups_setup.sh .
cp ../artdaq_daqinterface/docs/* .

sed -i -r 's!^\s*export ARTDAQ_DAQINTERFACE_DIR.*!export ARTDAQ_DAQINTERFACE_DIR='$Base/artdaq_daqinterface'!' mock_ups_setup.sh
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
ln -s srcs/artdaq_demo/tools/run_demo.sh .
ln -s srcs/artdaq_demo/tools/run_integration_tests.sh .


if [ "x${opt_run_demo-}" != "x" ]; then
    if [ $installStatus -eq 0 ]; then
	echo doing the demo

	set +u
	. ./run_demo.sh --basedir $Base --toolsdir ${Base}/srcs/artdaq_demo/tools
	set -u
    else
        echo 'Build error (see above) precludes running the demo (i.e --run-demo option specified)'
    fi
fi


endtime=`date`

echo "Build start time: $starttime"
echo "Build end time:   $endtime"
