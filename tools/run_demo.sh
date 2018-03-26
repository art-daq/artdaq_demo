#!/bin/bash

# JCF, Oct-5-2017
# This script basically follows the instructions found in https://cdcvs.fnal.gov/redmine/projects/artdaq-utilities/wiki/Artdaq-daqinterface

get_this_dir() 
{
    reldir=`dirname ${0}`
    ssi_mdt_dir=`cd ${reldir} && pwd -P`
}

validate_basedir()
{
	valid_basedir=0
	if [ -d $basedir/artdaq-utilities-daqinterface ] || [ -d $ARTDAQ_DAQINTERFACE_DIR ]; then
		if [ -d $basedir/DAQInterface ]; then
			valid_basedir=1
		fi
	fi
}

validate_toolsdir()
{
	valid_toolsdir=0
	if [ -f $toolsdir/fcl/TransferInputShmem.fcl ]; then
		valid_toolsdir=1
	fi
}

get_this_dir
basedir=$ssi_mdt_dir
validate_basedir

toolsdir="$basedir/srcs/artdaq_demo/tools"
validate_toolsdir


om_fhicl=TransferInputShmem

env_opts_var=`basename $0 | sed 's/\.sh$//' | tr 'a-z-' 'A-Z_'`_OPTS
USAGE="\
   usage: `basename $0` [options] [just_do_it.sh options]
examples: `basename $0` 
          `basename $0` --om --om_fhicl TransferInputShmemWithDelay
		  `basename $0` --om --config demo_largesystem --compfile $PWD/DAQInterface/comps.list --runduration 40
--help        This help message
--just_do_it_help Help message from just_do_it.sh
--basedir	  Base directory ($basedir, valid=$valid_basedir)
--toolsdir	  artdaq_demo/tools directory ($toolsdir, valid=$valid_toolsdir)
--no_om       Do *NOT* run Online Monitoring
--om_fhicl    Name of Fhicl file to use for online monitoring ($om_fhicl)
--partition=<N> set a partition number -- to allow multiple demos
"

# Process script arguments and options
eval env_opts=\${$env_opts_var-} # can be args too
eval "set -- $env_opts \"\$@\""
op1chr='rest=`expr "$op" : "[^-]\(.*\)"`   && set -- "-$rest" "$@"'
op1arg='rest=`expr "$op" : "[^-]\(.*\)"`   && set --  "$rest" "$@"'
reqarg="$op1arg;"'test -z "${1+1}" &&echo opt -$op requires arg. &&echo "$USAGE" &&exit'
args= do_help= do_jdi_help= do_om=1;
while [ -n "${1-}" ];do
    if expr "x${1-}" : 'x-' >/dev/null;then
        op=`expr "x$1" : 'x-\(.*\)'`; shift   # done with $1
        leq=`expr "x$op" : 'x-[^=]*\(=\)'` lev=`expr "x$op" : 'x-[^=]*=\(.*\)'`
        test -n "$leq"&&eval "set -- \"\$lev\" \"\$@\""&&op=`expr "x$op" : 'x\([^=]*\)'`
        case "$op" in
            \?*|h*)     eval $op1chr; do_help=1;;
            -help)      eval $op1arg; do_help=1;;
	    -just_do_it_help) eval $op1arg; do_jdi_help=1;;
            -basedir)   eval $reqarg; basedir=$1; shift;;
            -toolsdir)  eval $reqarg; toolsdir=$1; shift;;
	    -no_om)        do_om=0;;
	    -om_fhicl)  eval $reqarg; om_fhicl=$1; shift;;
            -partition) eval $reqarg; export ARTDAQ_PARTITION_NUMBER=$1; shift;;
            *)          aa=`echo "-$op" | sed -e"s/'/'\"'\"'/g"` args="$args '$aa'";
        esac
    else
        aa=`echo "$1" | sed -e"s/'/'\"'\"'/g"` args="$args '$aa'"; shift
    fi
done
eval "set -- $args \"\$@\""; unset args aa

test -n "${do_help-}" && echo "$USAGE" && exit
#echo "Remaining args: $@"


validate_basedir
validate_toolsdir

if [ $valid_basedir -eq 0 ]; then
	echo "Provided base directroy is not valid! Must contain DAQInterface directory, and artdaq-utilities-daqinterface directory if \$ARTDAQ_DAQINTERFACE_DIR is not set"
	return 1
	exit 1
fi
if [ $valid_toolsdir -eq 0 ] && [ $do_om -eq 1 ]; then
	echo "Provided tools directory is not valid!"
	return 2
	exit 2
fi

daqintdir=$basedir/DAQInterface
jdibootfile=$daqintdir/boot.txt
jdiduration=200
cd $basedir


if [ -n "${do_jdi_help-}" ]; then
    cd ${daqintdir}
    source ./mock_ups_setup.sh	
	export DAQINTERFACE_USER_SOURCEFILE=$PWD/user_sourcefile_example
	source $ARTDAQ_DAQINTERFACE_DIR/source_me
	just_do_it.sh --help
	exit
fi


function wait_for_state() {
    local stateName=$1

    # 20-Mar-2018, KAB
    # The DAQInterface setup uses a dynamic way to determine which PORT to use for communication.
    # This means that we need to allow sufficient time between when DAQInterface is started and
    # when we run 'source_me' so that they agree on the port that should be used.
    # The way that we work around this here is to catch what appears to be a port mis-match
    # (the status.sh call returns an empty string), wait a bit, and then re-run source_me in the
    # hope that it will pick up the correct port.
    # An important piece of this is the un-setting of the DAQINTERFACE_STANDARD_SOURCEFILE_SOURCED
    # env var so that source_me will go through the process of re-determining which port to use.

    cd ${daqintdir}
    source ./mock_ups_setup.sh
    export DAQINTERFACE_USER_SOURCEFILE=$PWD/user_sourcefile_example
    source $ARTDAQ_DAQINTERFACE_DIR/source_me > /dev/null

    while [[ "1" ]]; do
      sleep 1

      res=$( status.sh 2>/dev/null | tail -1 | tr "'" " " | awk '{print $2}' )

      if [[ "$res" == "" ]]; then
          sleep 2
          unset DAQINTERFACE_STANDARD_SOURCEFILE_SOURCED
          source $ARTDAQ_DAQINTERFACE_DIR/source_me > /dev/null
      fi

      if [[ "$res" == "$stateName" ]]; then
          break
      fi
    done
}

# And now, actually run DAQInterface as described in
# https://cdcvs.fnal.gov/redmine/projects/artdaq-utilities/wiki/Artdaq-daqinterface

    $toolsdir/xt_cmd.sh $daqintdir --geom '132x33 -sl 2500' \
        -c 'source mock_ups_setup.sh' \
	-c 'export DAQINTERFACE_USER_SOURCEFILE=$PWD/user_sourcefile_example' \
	-c 'source $ARTDAQ_DAQINTERFACE_DIR/source_me' \
	-c 'DAQInterface'

    sleep 3
    echo ""
    echo "Waiting for DAQInterface to reached the 'stopped' state before continuing..."
    wait_for_state "stopped"
    echo "Done waiting."

    $toolsdir/xt_cmd.sh $daqintdir --geom 132 \
        -c 'source mock_ups_setup.sh' \
	-c 'export DAQINTERFACE_USER_SOURCEFILE=$PWD/user_sourcefile_example' \
	-c 'source $ARTDAQ_DAQINTERFACE_DIR/source_me' \
	-c "just_do_it.sh $* $jdibootfile $jdiduration"

	if [ $do_om -eq 1 ]; then
    sleep 8;
    echo ""
    echo "Waiting for the run to start before starting online monitor apps..."
    wait_for_state "running"
    echo "Done waiting."

    xrdbproc=$( which xrdb )

    xloc=
    if [[ -e $xrdbproc ]]; then
    	xloc=$( xrdb -symbols | grep DWIDTH | awk 'BEGIN {FS="="} {pixels = $NF; print pixels/2}' )
    else
    	xloc=800
    fi

    $toolsdir/xt_cmd.sh $basedir --geom '150x33+'$xloc'+0 -sl 2500' \
        -c '. ./setupARTDAQDEMO' \
        -c 'art -c '$toolsdir'/fcl/'$om_fhicl'.fcl'

    sleep 4;

    $toolsdir/xt_cmd.sh $basedir --geom '100x33+0+0 -sl 2500' \
        -c '. ./setupARTDAQDEMO' \
    	-c 'rm -f '$toolsdir'/fcl/'$om_fhicl'2.fcl' \
        -c 'cp -p '$toolsdir'/fcl/'$om_fhicl'.fcl '$toolsdir'/fcl/'$om_fhicl'2.fcl' \
    	-c 'sed -r -i "s/.*modulus.*[0-9]+.*/modulus: 100/" '$toolsdir'/fcl/'$om_fhicl'2.fcl' \
    	-c 'sed -r -i "/end_paths:/s/a3/a1/" '$toolsdir'/fcl/'$om_fhicl'2.fcl' \
    	-c 'sed -r -i "/shm_key:/s/.*/shm_key: 0x40471453/" '$toolsdir'/fcl/'$om_fhicl'2.fcl' \
    	-c 'sed -r -i "s/shmem1/shmem2/" '$toolsdir'/fcl/'$om_fhicl'2.fcl' \
		-c 'sed -r -i "s/destination_rank: 6/destination_rank: 7/" '$toolsdir'/fcl/'$om_fhicl'2.fcl' \
        -c 'art -c '$toolsdir'/fcl/'$om_fhicl'2.fcl'

	fi
