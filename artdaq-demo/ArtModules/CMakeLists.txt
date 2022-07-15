include(BuildPlugins) # Art Module

cet_build_plugin(ArtdaqDemoBuildInfo art::module 
  LIBRARIES REG 
  TRACE::MF
  artdaq_demo::artdaq-demo_BuildInfo
  artdaq_core::artdaq-core_BuildInfo
  artdaq_core_demo::artdaq-core-demo_BuildInfo
  artdaq_utilities::artdaq-utilities_BuildInfo
  artdaq::BuildInfo)

cet_build_plugin(NthEvent art::module)

cet_build_plugin(ToyDump art::module LIBRARIES REG artdaq_core_demo::artdaq-core-demo_Overlays)

cet_build_plugin(ASCIIDump art::module LIBRARIES REG artdaq_core_demo::artdaq-core-demo_Overlays)

cet_build_plugin(RootApplication art::module LIBRARIES REG ROOT::Gui )

cet_build_plugin(WFViewer art::module LIBRARIES REG artdaq_core_demo::artdaq-core-demo_Overlays ROOT::Core ROOT::Gui)

cet_build_plugin(CheckIntegrity art::module LIBRARIES REG artdaq_core_demo::artdaq-core-demo_Overlays)
  
cet_build_plugin(EventReporterOutput art::module LIBRARIES REG artdaq::DAQdata ROOT::Core artdaq_core::artdaq-core_Data_ParentageMap)

install_headers(SUBDIRS detail)
install_source(SUBDIRS detail)
install_fhicl(SUBDIRS fcl)
