cet_script(ALWAYS_COPY
	calculate_test_coverage.sh
	check_integration_tests.sh
	configure_artdaq_database.sh
	#	downloadDeps.sh
	#	installArtDaqDemo.sh
	#	quick-mrb-start.sh
	#	quick-start.sh
	run_demo.sh
	run_integration_tests.sh
	setupDemoEnvironment.sh
	xt_cmd.sh
)

cet_make_exec(NAME read_fhicl SOURCE readfhicl.cc
  LIBRARIES
  fhiclcpp::fhiclcpp
  Boost::program_options
  )  
  
# Is this necessary?
#install_source()
install_fhicl(SUBDIRS fcl)
install_headers()
install_source()

