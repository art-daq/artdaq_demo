cet_script(setupDemoEnvironment.sh 
multi_udp_send_artdaq.py 
run_demo.sh xt_cmd.sh)

cet_script(configure_artdaq_database.sh)

art_make_exec(read_fhicl SOURCE readfhicl.cc
  LIBRARIES
  ${FHICLCPP}
  ${Boost_PROGRAM_OPTIONS_LIBRARY}
  ${CETLIB}
  )  
  
# Is this necessary?
#install_source()
install_fhicl(SUBDIRS fcl)

