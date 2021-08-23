#!/bin/bash

#set -x
setup_sourced=0

min_events_ascii_simulator_example=600
min_events_circular_buffer_mode_example=60
min_events_circular_buffer_mode_withRM=10
min_events_complex_subsystems=600
min_events_complicated_subsystems=60
min_events_config_includes=600
min_events_demo=600
min_events_demo_largesystem=600
min_events_eventbuilder_diskwriting=300
min_events_file_closing_example=10
min_events_issue24231_test1=600
min_events_mediumsystem_with_routing_manager=100
min_events_mu2e_sample_system=600
min_events_multiple_art_processes_example=600
min_events_multiple_dataloggers=100
min_events_multiple_fragment_ids=600
min_events_request_based_dataflow_example=600
min_events_routing_manager_example=600
min_events_simple_subsystems=600
min_events_subrun_example=10

min_fragments_ascii_simulator_example=0
min_fragments_circular_buffer_mode_example=2000
min_fragments_circular_buffer_mode_withRM=3000
min_fragments_complex_subsystems=4
min_fragments_complicated_subsystems=5
min_fragments_config_includes=4
min_fragments_demo=2
min_fragments_demo_largesystem=19
min_fragments_eventbuilder_diskwriting=2
min_fragments_file_closing_example=2
min_fragments_issue24231_test1=4
min_fragments_mediumsystem_with_routing_manager=10
min_fragments_mu2e_sample_system=1
min_fragments_multiple_art_processes_example=2
min_fragments_multiple_dataloggers=4
min_fragments_multiple_fragment_ids=6
min_fragments_request_based_dataflow_example=6
min_fragments_routing_manager_example=2
min_fragments_simple_subsystems=2
min_fragments_subrun_example=4


function source_setup {
    if [ $setup_sourced -eq 0 ]; then
	#set +x
        source setupARTDAQDEMO
	#set -x
        export setup_sourced=1
    fi
}

function get_run_config {
    run_config_name=`grep "Config name:" $1/metadata.txt|sed 's/.*: //g'`
}

function get_run_files {
    run_files=`ls daqdata|grep -e "_r0*${1}_"|grep -v dump`
    run_files_count=`ls daqdata|grep -e "_r0*${1}_"|grep -v dump|wc -l`
}

function get_run_dump_file {
    if ! [ -e daqdata/${1}.toydump ];then
        source_setup >/dev/null 2>&1
        art -c toyDump.fcl daqdata/$1 >daqdata/$1.toydump 2>&1
    fi
    echo daqdata/${1}.toydump
}

function check_onmon() {

onmonFileCount=`ls daqdata|grep -e '.*\.bin$'|wc -l`
runCount=`ls run_records|wc -l`
diff=$(( $runCount - $onmonFileCount ))
if [ $diff -ne 0 ]; then
	echo "Expected $runCount online monitor files, but found $onmonFileCount"
fi

if [ $onmonFileCount -gt 0 ]; then
	for file in daqdata/*.bin;do
		fileSize=`ls -l $file|awk '{print $5}'`
		if [[ $file =~ .*_noom.bin ]]; then
			if [ $fileSize -ne 0 ];then
				echo "File $file somehow has nonzero size ($fileSize)!"
			fi
		else
			if [ $fileSize -eq 0 ];then
				echo "File $file has zero size! Check online monitoring in this configuration!"
			fi
		fi
	done
fi
}

function check_event_count() {
    res=0

    local lfile=$1
    local lconfig=$2

    local ldump=`get_run_dump_file $lfile`
#	echo "Dump file is $ldump"

    local fevents=`grep "Events total" $ldump|sed 's/.*total = \([0-9]*\).*/\1/g'`
	local ooevents=`grep -c "Event ordering problem" $ldump`

	local mineventsVarname=`echo min_events_${lconfig}`
	local minevents=${!mineventsVarname}
#	echo "minevents is $minevents, varname is $mineventsVarname"

	if [ $fevents -lt $minevents ];then
		echo "    File $lfile has $fevents events, which is less than the minimum required: $minevents!"
		res=1
	fi
	if [ $ooevents -gt 0 ];then
		echo "    File $lfile has $ooevents out-of-order events! This could be benign, but check dump output for other problems!"
		res=1
	fi

    return $res
}

function check_fragment_count() {
    res=0
    local lfile=$1
    local lconfig=$2

    local ldump=`get_run_dump_file $lfile`
#	echo "Dump file is $ldump"
    
    local ffragments=`grep "ENDSUBRUN: There were " $ldump|sed 's/.*There were \([0-9]*\) events with \([0-9]*\) TOY1 or TOY2.*/\1:\2/g'`

	local minfragsVarname=`echo min_fragments_${lconfig}`
	local minfrags=${!minfragsVarname}

	local badevents=0
	local totalevents=0
	local maxfrags=0
	for fragResult in $ffragments;do
		local nevents=`echo $fragResult|cut -d: -f1`
		local fragCount=`echo $fragResult|cut -d: -f2`
		if [ $fragCount -lt $minfrags ];then
			badevents=$(( $badevents + $nevents ))
		fi
		if [ $fragCount -gt $maxfrags ];then
			maxfrags=$fragCount
		fi
		totalevents=$(( $totalevents + $nevents ))
	done

	if [ $badevents -gt 0 ];then
		badEventsPct=$(( 100 * $badevents / $totalevents ))
		echo "    File $lfile has $badevents events with fewer than $minfrags Fragments out of $totalevents (${badEventsPct}%)"
		
		histo="===================================================================================================="

		for fragResult in $ffragments;do
			local nevents=$(( 100 * `echo $fragResult|cut -d: -f1` / $totalevents ))
			local fragCount=`echo $fragResult|cut -d: -f2`
			echo -n "$fragCount      "
			echo ${histo:0:$nevents}
		done
	fi
	#echo "    File $lfile has $maxfrags Fragments in its largest event."

    return $res
}

for run in `ls -d run_records/*|sort -V`;do 
    run_number=`echo $run|sed 's|.*/||g'`

    get_run_config $run

    get_run_files $run_number
    #echo "Run files:"
    #echo "$run_files"

    echo "Run $run_number with configuration $run_config_name has $run_files_count data file(s)"
	if [ $run_files_count -gt 0 ]; then
		for file in $run_files;do
			#echo "    $file"
			check_event_count $file $run_config_name
		    check_fragment_count $file $run_config_name
	    done
    else
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "!!!!!RUN $run_number WITH CONFIGURATION $run_config_name HAS NO DATA!!!!"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	fi
done
check_onmon
