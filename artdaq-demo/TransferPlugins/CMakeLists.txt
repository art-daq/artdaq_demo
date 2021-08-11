
include_directories($ENV{MPICH_INC} )

simple_plugin(NthEvent "transfer"
  artdaq_TransferPlugins
  artdaq_core::artdaq-core_Utilities
  artdaq_DAQrate
  artdaq_DAQdata
  MF_MessageLogger
  fhiclcpp
  ${Boost_SYSTEM_LIBRARY}
  cetlib
  cetlib_except
)

install_headers()
install_source()
