

include(artdaq::commandableGenerator)
cet_build_plugin(ToySimulator artdaq::commandableGenerator LIBRARIES REG artdaq_core_demo::artdaq-core-demo_Overlays artdaq_demo::artdaq-demo_Generators_ToyHardwareInterface )
cet_build_plugin(AsciiSimulator artdaq::commandableGenerator LIBRARIES REG artdaq_core_demo::artdaq-core-demo_Overlays )
cet_build_plugin(UDPReceiver artdaq::commandableGenerator LIBRARIES REG artdaq_core_demo::artdaq-core-demo_Overlays canvas::canvas)

add_subdirectory(ToyHardwareInterface)
