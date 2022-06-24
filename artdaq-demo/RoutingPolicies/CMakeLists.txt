
include(PolicyPlugins)
cet_build_plugin(MisbehaviorTest artdaq::policy)

install_headers()
install_fhicl(SUBDIRS fcl)
install_source()
