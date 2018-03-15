#!/bin/bash

# JCF, Oct-5-2017
# This script basically follows the instructions found in https://cdcvs.fnal.gov/redmine/projects/artdaq-utilities/wiki/Artdaq-daqinterface

if [ $# -lt 2 ];then
 echo "USAGE: $0 base_directory tools_directory"
 exit
fi
basedir=$1
toolsdir=$2

cd $basedir

daqintdir=$basedir/DAQInterface

if [[ ! -e $daqintdir ]]; then
    echo "Expected DAQInterface script directory $daqintdir doesn't appear to exist; if you haven't installed DAQInterface please see https://cdcvs.fnal.gov/redmine/projects/artdaq-utilities/wiki/Artdaq-daqinterface for instructions on how to do so" >&2
    return 1
    exit 1
fi

function wait_for_state() {
    local stateName=$1

    cd ${daqintdir}
    source ./mock_ups_setup.sh
    export DAQINTERFACE_USER_SOURCEFILE=$PWD/user_sourcefile_example
    source $ARTDAQ_DAQINTERFACE_DIR/source_me > /dev/null

    while [[ "1" ]]; do
      sleep 1

      res=$( status.sh  | tail -1 | tr "'" " " | awk '{print $2}' )

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
	-c 'just_do_it.sh $PWD/boot.txt 200'

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

