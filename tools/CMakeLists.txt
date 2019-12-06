cet_script(setupDemoEnvironment.sh 
multi_udp_send_artdaq.py 
run_demo.sh xt_cmd.sh)

cet_script(configure_artdaq_database.sh)
#art_make_exec(demo_driver
#  LIBRARIES
#  artdaq_Application
#  artdaq_DAQrate
#  artdaq-core_Utilities
#  artdaq-core_Core
#  art_Framework_Art
#  ${FHICLCPP}
#  ${Boost_PROGRAM_OPTIONS_LIBRARY}
#  ${MPI_C_LIBRARIES}
#  ${CETLIB}
#  )

art_make_exec(read_fhicl SOURCE readfhicl.cc
  LIBRARIES
  ${FHICLCPP}
  ${Boost_PROGRAM_OPTIONS_LIBRARY}
  ${CETLIB}
  )  

add_subdirectory(snippets)

# Is this necessary?
#install_source()
install_fhicl(SUBDIRS fcl)

