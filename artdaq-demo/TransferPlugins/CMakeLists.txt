
include_directories($ENV{MPICH_INC} )

simple_plugin(NthEvent "transfer"
  artdaq_TransferPlugins
  artdaq-core_Utilities
  artdaq_DAQrate
  artdaq_DAQdata
  MF_MessageLogger
  fhiclcpp
  ${Boost_SYSTEM_LIBRARY}
  ${CETLIB}
  ${CETLIB_EXCEPT}
)

install_headers()
install_source()
