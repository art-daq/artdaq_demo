
function treset () 
{ 
        ${TRACE_BIN}/trace_cntl reset "$@"
}


function cleanup() {
	killall -9 art
	ipcrm -a
	treset
}

source setupARTDAQDEMO
cleanup
echo "=============================================="
echo "demo"
echo "=============================================="
./run_demo.sh --auto ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
echo "=============================================="
echo "ascii_simulator_example"
echo "=============================================="
./run_demo.sh --config ascii_simulator_example --comps component01 -- --no_om --auto ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
echo "=============================================="
echo "combined_eb_and_dl"
echo "=============================================="
./run_demo.sh --config combined_eb_and_dl --comps component{01..04} -- --no_om --auto --bootfile $PWD/artdaq-utilities-daqinterface/simple_test_config/combined_eb_and_dl/boot.txt ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
echo "=============================================="
echo "config_includes"
echo "=============================================="
./run_demo.sh --config config_includes --comps component{01..04} -- --auto --bootfile $PWD/artdaq-utilities-daqinterface/simple_test_config/config_includes/boot.txt ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
echo "=============================================="
echo "demo_largesystem"
echo "=============================================="
./run_demo.sh --config demo_largesystem --comps component{01..19} -- --auto ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
echo "=============================================="
echo "eventbuilder_diskwriting"
echo "=============================================="
./run_demo.sh --config eventbuilder_diskwriting --auto --bootfile $PWD/artdaq-utilities-daqinterface/simple_test_config/eventbuilder_diskwriting/boot.txt ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
echo "=============================================="
echo "file_closing_example"
echo "=============================================="
./run_demo.sh --config file_closing_example --auto ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
echo "=============================================="
echo "mediumsystem_with_routing_master"
echo "=============================================="
./run_demo.sh --config mediumsystem_with_routing_master --comps component{01..10} -- --auto --bootfile $PWD/artdaq-utilities-daqinterface/simple_test_config/mediumsystem_with_routing_master/boot.txt ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
echo "=============================================="
echo "multiple_art_processes_example"
echo "=============================================="
./run_demo.sh --config multiple_art_processes_example --auto  ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
echo "=============================================="
echo "multiple_dataloggers"
echo "=============================================="
./run_demo.sh --config multiple_dataloggers --comps component{01..04} -- --auto --bootfile $PWD/artdaq-utilities-daqinterface/simple_test_config/multiple_dataloggers/boot.txt ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
echo "=============================================="
echo "request_based_dataflow_example"
echo "=============================================="
./run_demo.sh --config request_based_dataflow_example --comps component{01..03} -- --auto ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
echo "=============================================="
echo "routing_master_example"
echo "=============================================="
./run_demo.sh --config routing_master_example --auto --bootfile $PWD/artdaq-utilities-daqinterface/simple_test_config/routing_master_example/boot.txt ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
echo "=============================================="
echo "subrun_example"
echo "=============================================="
./run_demo.sh --config subrun_example --comps component{01..04} -- --auto --bootfile $PWD/artdaq-utilities-daqinterface/simple_test_config/subrun_example/boot.txt ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
echo "=============================================="
echo "demo (Hung online monitor)"
echo "=============================================="
./run_demo.sh --auto --om_fhicl TransferInputShmemWithDelay ${extra_args}
echo "=================LATEST FILE=================="
echo `ls -t daqdata|head -1`
echo "=============================================="
cleanup
