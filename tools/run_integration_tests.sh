
source setupARTDAQDEMO

bootfile_name=${bootfile_name:-"boot.txt"}
extra_args="${extra_args} $@"

if [ -d $ARTDAQ_DAQINTERFACE_DIR/simple_test_config ]; then
	dir=$ARTDAQ_DAQINTERFACE_DIR/simple_test_config
elif [ -d $PWD/artdaq-utilities-daqinterface/simple_test_config ]; then
	dir=$PWD/artdaq-utilities-daqinterface/simple_test_config
else
	echo "ERROR: Could not locate artdaq_daqinterface's simple_test_config directory in $ARTDAQ_DAQINTERFACE_DIR or $PWD/artdaq-utilities-daqinterface" >&2
	exit 2
fi

if ! [ -e $PWD/run_demo.sh ]; then
	echo "ERROR: Could not locate run_demo.sh in current directory!" >&2
	exit 3
fi

function treset () 
{ 
	${TRACE_BIN}/trace_cntl reset "$@"
}


function cleanup() {
	killall -9 art
	ipcrm -a
	treset
}

function run_simple_test_config() {
	config=$1
	
	cleanup
	echo "=============================================="
	echo $config
	echo "=============================================="

	configDir=$dir/$config
	bootfile=
	brlist=
	brs=
	om=

	if [ -e $configDir/boot.txt ]; then
		bootfile="--bootfile $configDir/$bootfile_name"
	fi

	brlist_file="$dir/../docs/known_boardreaders_list_example"
	if [ -e $configDir/known_boardreaders_list_example ]; then
		brlist_file=$configDir/known_boardreaders_list_example
		brlist="--brlist $brlist_file"
	fi

	br_temp=`cat $brlist_file|awk '{print $1}'|sed 's/#.*//g'|tr '\n' ' '`
	for br in ${br_temp}; do
		if [ -e $configDir/${br}.fcl ] || [ -e $configDir/${br}_hw_cfg.fcl ]; then
			brs="$brs $br"
		fi
	done

	do_om=0
	for ff in $configDir/*.fcl;do
		do_om=$(( $do_om + `grep -c ToySimulator $ff` ))
	done


	if [ $do_om -eq 0 ];then
		om="--no_om"
	fi

	echo "Command line: ./run_demo.sh --auto --config $config $bootfile $brlist $om --comps $brs -- ${extra_args}"
	./run_demo.sh --auto --config $config $bootfile $brlist $om --comps $brs -- ${extra_args}

	echo "=================LATEST FILE=================="
	echo `ls -t daqdata|head -1`
	echo "=============================================="

}

for config in $dir/*/;do
	configName=`echo $config|sed 's|/$||g'|sed 's|.*/||g'`
	if [[ $configName != "config_includes" ]]; then
		run_simple_test_config $configName
	fi
done


# Special tests with their own configs:
echo "=============================================="
echo "demo (Hung online monitor)"
echo "=============================================="
./run_demo.sh --auto --om_fhicl TransferInputShmemWithDelay ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
