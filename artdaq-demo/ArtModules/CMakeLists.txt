art_make( BASENAME_ONLY
 LIBRARY_NAME artdaq-demo_ArtModules
  NO_PLUGINS
  DICT_DICTIONARIES
  ${ART_PERSISTENCY_PROVENANCE}
  ${CANVAS_PERSISTENCY_PROVENANCE}
 LIB_LIBRARIES
 artdaq-core-demo_Overlays
 artdaq_ArtModules
  art_Framework_Core
  art_Framework_IO_Sources
  art_Framework_Principal
  art_Persistency_Provenance
  canvas
  MF_MessageLogger
  ${ROOT_CINTEX}
  ${ROOT_RIO}
  ${ROOT_CORE}
  ${ROOT_NET}
  ${ROOT_REFLEX}
  cetlib
  cetlib_except
)

#art_make(NO_PLUGINS # WAnt different link lists for modues
#  LIB_LIBRARIES artdaq-core-demo_Overlays
#)

# foreach (mod NthEvent )
#   simple_plugin(${mod} "module" artdaq-demo_ArtModules)
# endforeach()

simple_plugin(ArtdaqDemoBuildInfo "module"
  artdaq_DAQdata
  artdaq_BuildInfo
  artdaq_core::artdaq-core_BuildInfo
  artdaq_utilities::artdaq-utilities_BuildInfo
  artdaq-demo_BuildInfo
  artdaq_core_demo::artdaq-core-demo_BuildInfo
  art_Persistency_Provenance
  MF_MessageLogger
  fhiclcpp
  cetlib
  cetlib_except
)

simple_plugin(NthEvent "module"
	cetlib_except
)

simple_plugin(ToyDump "module"
	artdaq_core::artdaq-core_Data
    artdaq_core::artdaq-core_Utilities
	artdaq_core_demo::artdaq-core-demo_Overlays
	art_Persistency_Provenance
	cetlib_except
)

simple_plugin(ASCIIDump "module"
			  artdaq_core::artdaq-core_Data
              artdaq_core::artdaq-core_Utilities
			  artdaq_core_demo::artdaq-core-demo_Overlays
			  art_Persistency_Provenance
			  cetlib_except
)

simple_plugin(RootApplication "module"
  cetlib_except
  ${ROOT_CORE}
  )

simple_plugin(WFViewer "module"
			  artdaq_core::artdaq-core_Data
              artdaq_core::artdaq-core_Utilities
			  artdaq_core_demo::artdaq-core-demo_Overlays
			  MF_MessageLogger
  art_Persistency_Provenance
  ${ROOT_CORE}
			  ${ROOT_GPAD}
			  ${ROOT_HIST}
			  ${ROOT_GUI}
			  ${ROOT_RIO}
  cetlib_except
  )

simple_plugin(CheckIntegrity "module"
			  artdaq_core::artdaq-core_Data
              artdaq_core::artdaq-core_Utilities
			  artdaq_core_demo::artdaq-core-demo_Overlays
			art_Persistency_Provenance
  MF_MessageLogger
  cetlib_except
)
  
simple_plugin(EventReporterOutput "module"
  artdaq_ArtModules
  artdaq_DAQdata
  artdaq_core::artdaq-core_Utilities
  art_Framework_Services_Registry
  art_Utilities
  MF_MessageLogger
  fhiclcpp
  cetlib
  cetlib_except
  ${ROOT_CORE}
  ${ROOT_RIO}
)

install_headers(SUBDIRS detail)
install_source(SUBDIRS detail)
install_fhicl(SUBDIRS fcl)
