
cet_script(ALWAYS_COPY driver_with_verification.sh)

  cet_test(driver_with_verification_t HANDBUILT
	TEST_EXEC driver_with_verification.sh
	TEST_ARGS 100
	DATAFILES fcl/driver.fcl fcl/validate.fcl
  #TEST_PROPERTIES RUN_SERIAL 1
	)