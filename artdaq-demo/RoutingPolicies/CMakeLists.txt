simple_plugin("MisbehaviorTest" "policy"
    artdaq_RoutingPolicies
    artdaq_DAQdata
    fhiclcpp
    MF_MessageLogger
  ${Boost_SYSTEM_LIBRARY}
    cetlib_except
    cetlib
    )

simple_plugin(NthEvent "policy"
artdaq_RoutingPolicies
artdaq_DAQdata
fhiclcpp
MF_MessageLogger
  ${Boost_SYSTEM_LIBRARY}
cetlib_except
cetlib
)
install_headers()
install_fhicl(SUBDIRS fcl)
install_source()
