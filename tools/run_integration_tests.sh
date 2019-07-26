
source setupARTDAQDEMO

bootfile_name=${bootfile_name:-"boot.txt"}
brlistfile_name=${brlistfile_name:-"known_boardreaders_list_example"}
ignoredConfigs="dune_sample_system|pdune_swtrig|subconfigs"
extra_args="${extra_args}"
daqinterface_rundir=${daqinterface_rundir:-"$PWD/DAQInterface"}

if [ -d $ARTDAQ_DAQINTERFACE_DIR/simple_test_config ]; then
	simple_test_config_dir=$ARTDAQ_DAQINTERFACE_DIR/simple_test_config
elif [ -d $PWD/artdaq-utilities-daqinterface/simple_test_config ]; then
	simple_test_config_dir=$PWD/artdaq-utilities-daqinterface/simple_test_config
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

	configDir=$simple_test_config_dir/$config
	bootfile="--bootfile $daqinterface_rundir/$bootfile_name"
	brlist=""
	brs=
	om=

	if [ -e $configDir/$bootfile_name ]; then
		bootfile="--bootfile $configDir/$bootfile_name"
	fi

	brlist_file="$daqinterface_rundir/$brlistfile_name"
	if [ -e $configDir/$brlistfile_name ]; then
		brlist_file=$configDir/$brlistfile_name
	fi
	brlist="--brlist $brlist_file"

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



env_opts_var=`basename $0 | sed 's/\.sh$//' | tr 'a-z-' 'A-Z_'`_OPTS
USAGE="\
   usage: `basename $0` [options]
examples: `basename $0` 
		  `basename $0` --runduration 60 --runs 3
          `basename $0` --brlist_name known_boardreaders_list_example.mu2edaq --boot_name boot.mu2edaq.txt
--help        This help message
--brlist_name Name of the BoardReader list file (ex. known_boardreaders_list_example) ($brlistfile_name)
--boot_name   Name of the DAQInterface boot file (ex. boot.txt) (Default: $bootfile_name)
--config      Name of a single config to run (otherwise all simple_test_config will be run)
--ignoredConfig If --config is not specified, ignore this configuration (may be repeated) Defaults: $ignoredConfigs
"

# Process script arguments and options
eval env_opts=\${$env_opts_var-} # can be args too
eval "set -- $env_opts \"\$@\""
op1chr='rest=`expr "$op" : "[^-]\(.*\)"`   && set -- "-$rest" "$@"'
op1arg='rest=`expr "$op" : "[^-]\(.*\)"`   && set --  "$rest" "$@"'
reqarg="$op1arg;"'test -z "${1+1}" &&echo opt -$op requires arg. &&echo "$USAGE" &&exit'
args= do_help= single_mode=0;
while [ -n "${1-}" ];do
    if expr "x${1-}" : 'x-' >/dev/null;then
        op=`expr "x$1" : 'x-\(.*\)'`; shift   # done with $1
        leq=`expr "x$op" : 'x-[^=]*\(=\)'` lev=`expr "x$op" : 'x-[^=]*=\(.*\)'`
        test -n "$leq"&&eval "set -- \"\$lev\" \"\$@\""&&op=`expr "x$op" : 'x\([^=]*\)'`
        case "$op" in
            \?*|h*)     eval $op1chr; do_help=1;;
            x*)         eval $op1chr; set -x;;
            -help)      do_help=1;;
			-brlist_name) eval $reqarg;brlistfile_name=$1; shift;;
			-boot_name) eval $reqarg;bootfile_name=$1; shift;;
			-config) eval $reqarg; requested_config=$1; single_mode=1;shift;;
			-ignoredConfig) eval $reqarg; ignoredConfigs="${ignoredConfigs:+$ignoredConfigs|}$1"; shift;;
            *)          aa=`echo "-$op" | sed -e"s/'/'\"'\"'/g"` args="$args '$aa'";
        esac
    else
        aa=`echo "$1" | sed -e"s/'/'\"'\"'/g"` args="$args '$aa'"; shift
    fi
done
eval "set -- $args \"\$@\""; unset args aa

test -n "${do_help-}" && echo "$USAGE" && exit
#echo "Remaining args: $@"
extra_args="${extra_args} $@"

echo "Ignored Configs: ${ignoredConfigs}, brlist_name: ${brlistfile_name}, boot_name: ${bootfile_name}, extra_args: ${extra_args}"

if [ $single_mode -eq 0 ]; then
for config in $simple_test_config_dir/*/;do
	configName=`echo $config|sed 's|/$||g'|sed 's|.*/||g'`
	if [[ $configName =~ $ignoredConfigs ]]; then
		echo "Ignoring simple_test_config directory $configName"
	else
		run_simple_test_config $configName
	fi
done

# Special tests with their own configs:
echo "=============================================="
echo "demo (Hung online monitor)"
echo "=============================================="
./run_demo.sh --auto --om_fhicl TransferInputShmemWithDelay --bootfile $daqinterface_rundir/$bootfile_name --brlist $daqinterface_rundir/$brlistfile_name ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
else
	run_simple_test_config $requested_config
fi
