cet_script(ALWAYS_COPY setupDemoEnvironment.sh 
multi_udp_send_artdaq.py 
run_demo.sh xt_cmd.sh)

cet_script(ALWAYS_COPY configure_artdaq_database.sh)

cet_make_exec(NAME read_fhicl SOURCE readfhicl.cc
  LIBRARIES
  fhiclcpp::fhiclcpp
  Boost::program_options
  )  
  
# Is this necessary?
#install_source()
install_fhicl(SUBDIRS fcl)

