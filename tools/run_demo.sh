#!/bin/bash

# JCF, Oct-5-2017
# This script basically follows the instructions found in https://cdcvs.fnal.gov/redmine/projects/artdaq-utilities/wiki/Artdaq-daqinterface

if [ $# -lt 2 ];then
 echo "USAGE: $0 base_directory tools_directory [flags to pass to just_do_it.sh]"
 exit
fi
basedir=$1
toolsdir=$2
shift;shift;
daqintdir=$basedir/DAQInterface
jdibootfile=$daqintdir/boot.txt
jdiduration=200
jdiopts=$@;

cd $basedir


if [[ ! -e $daqintdir ]]; then
    echo "Expected DAQInterface script directory $daqintdir doesn't appear to exist; if you haven't installed DAQInterface please see https://cdcvs.fnal.gov/redmine/projects/artdaq-utilities/wiki/Artdaq-daqinterface for instructions on how to do so" >&2
    return 1
    exit 1
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
	-c "just_do_it.sh $jdiopts $jdibootfile $jdiduration"

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
        -c 'art -c '$toolsdir'/fcl/TransferInputShmem.fcl'

    sleep 4;

    $toolsdir/xt_cmd.sh $basedir --geom '100x33+0+0 -sl 2500' \
        -c '. ./setupARTDAQDEMO' \
    	-c 'rm -f '$toolsdir'/fcl/TransferInputShmem2.fcl' \
        -c 'cp -p '$toolsdir'/fcl/TransferInputShmem.fcl '$toolsdir'/fcl/TransferInputShmem2.fcl' \
    	-c 'sed -r -i "s/.*modulus.*[0-9]+.*/modulus: 100/" '$toolsdir'/fcl/TransferInputShmem2.fcl' \
    	-c 'sed -r -i "/end_paths:/s/a3/a1/" '$toolsdir'/fcl/TransferInputShmem2.fcl' \
    	-c 'sed -r -i "/shm_key:/s/.*/shm_key: 0x40471453/" '$toolsdir'/fcl/TransferInputShmem2.fcl' \
    	-c 'sed -r -i "s/shmem1/shmem2/" '$toolsdir'/fcl/TransferInputShmem2.fcl' \
		-c 'sed -r -i "s/destination_rank: 6/destination_rank: 7/" '$toolsdir'/fcl/TransferInputShmem2.fcl' \
        -c 'art -c '$toolsdir'/fcl/TransferInputShmem2.fcl'

