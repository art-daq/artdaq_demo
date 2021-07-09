
simple_plugin(ToySimulator "generator"
  artdaq-demo_Generators_ToyHardwareInterface
  artdaq_core_demo::artdaq-core-demo_Overlays
  artdaq_Generators
  artdaq_DAQdata
  artdaq_DAQrate
  artdaq_core::artdaq-core_Utilities
  artdaq_core::artdaq-core_Data
  artdaq_utilities::artdaq-utilities_Plugins
  canvas
  ${FHICLCPP}
  ${MF_MESSAGELOGGER}
  ${CETLIB}
${CETLIB_EXCEPT}
  )

simple_plugin(AsciiSimulator "generator"
  artdaq_core_demo::artdaq-core-demo_Overlays
  artdaq_Generators
  artdaq_DAQdata
  artdaq_core::artdaq-core_Utilities
  artdaq_core::artdaq-core_Data
  ${Boost_SYSTEM_LIBRARY}
  ${FHICLCPP}
  ${MF_MESSAGELOGGER}
  ${CETLIB}
  ${CETLIB_EXCEPT}
  )

simple_plugin(UDPReceiver "generator"
    artdaq_core_demo::artdaq-core-demo_Overlays
    artdaq_Generators
    artdaq_DAQdata
    artdaq_core::artdaq-core_Utilities
    artdaq_core::artdaq-core_Data
  ${Boost_SYSTEM_LIBRARY}
  canvas
    ${FHICLCPP}
  ${MF_MESSAGELOGGER}
    ${CETLIB}
 ${CETLIB_EXCEPT}
    )

add_subdirectory(ToyHardwareInterface)
