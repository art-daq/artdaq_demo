
file(DOWNLOAD https://artdaq.fnal.gov/TestDataFiles/RawFragmentHeaderV1_example_file.root ${CMAKE_CURRENT_BINARY_DIR}/RawFragmentHeaderV1_example_file.root TIMEOUT 30 STATUS RawFragmentHeaderV1Status)
file(DOWNLOAD https://artdaq.fnal.gov/TestDataFiles/RawFragmentHeaderV2_example_file.root ${CMAKE_CURRENT_BINARY_DIR}/RawFragmentHeaderV2_example_file.root TIMEOUT 30 STATUS RawFragmentHeaderV2Status)

list(GET RawFragmentHeaderV1Status 0 RawFragmentHeaderV1StatusCode)
if (RawFragmentHeaderV1StatusCode GREATER 0)
	file(REMOVE ${CMAKE_CURRENT_BINARY_DIR}/RawFragmentHeaderV1_example_file.root)
endif()
list(GET RawFragmentHeaderV2Status 0 RawFragmentHeaderV2StatusCode)
if ( RawFragmentHeaderV2StatusCode GREATER 0)
	file(REMOVE ${CMAKE_CURRENT_BINARY_DIR}/RawFragmentHeaderV2_example_file.root)
	else()

endif()

cet_test(CheckIntegrity_RawFragmentHeaderV1 HANDBUILT
  TEST_EXEC art
  TEST_ARGS -c checkIntegrity.fcl ${CMAKE_CURRENT_BINARY_DIR}/RawFragmentHeaderV1_example_file.root
  REQUIRED_FILES
  ${CMAKE_CURRENT_BINARY_DIR}/RawFragmentHeaderV1_example_file.root
)

cet_test(CheckIntegrity_RawFragmentHeaderV2 HANDBUILT
  TEST_EXEC art
  TEST_ARGS -c checkIntegrity.fcl ${CMAKE_CURRENT_BINARY_DIR}/RawFragmentHeaderV2_example_file.root
  REQUIRED_FILES
  ${CMAKE_CURRENT_BINARY_DIR}/RawFragmentHeaderV2_example_file.root
)
