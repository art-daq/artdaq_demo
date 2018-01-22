#!/bin/bash

source `which setupDemoEnvironment.sh`

# create the configuration file for PMT
tempFile="/tmp/pmtConfig.$$"

echo "BoardReaderMain!`hostname`!id:${ARTDAQDEMO_BR_PORT[0]} commanderPluginType:xmlrpc" >> $tempFile
echo "BoardReaderMain!`hostname`!id:${ARTDAQDEMO_BR_PORT[1]} commanderPluginType:xmlrpc" >> $tempFile
echo "EventBuilderMain!`hostname`!id:${ARTDAQDEMO_EB_PORT[0]} commanderPluginType:xmlrpc" >> $tempFile
echo "EventBuilderMain!`hostname`!id:${ARTDAQDEMO_EB_PORT[1]} commanderPluginType:xmlrpc" >> $tempFile
echo "DataLoggerMain!`hostname`!id:${ARTDAQDEMO_AG_PORT[0]} commanderPluginType:xmlrpc" >> $tempFile
echo "DispatcherMain!`hostname`!id:${ARTDAQDEMO_AG_PORT[1]} commanderPluginType:xmlrpc" >> $tempFile

# create the logfile directories, if needed
logroot="${ARTDAQDEMO_LOG_DIR:-/tmp}"
mkdir -p -m 0777 ${logroot}/pmt
mkdir -p -m 0777 ${logroot}/masterControl
mkdir -p -m 0777 ${logroot}/boardreader
mkdir -p -m 0777 ${logroot}/eventbuilder
mkdir -p -m 0777 ${logroot}/dispatcher
mkdir -p -m 0777 ${logroot}/datalogger
mkdir -p -m 0777 ${logroot}/artdaqart

# if [[ "x${ARTDAQ_MFEXTENSIONS_DIR-}" != "x" ]] && [[ "x${DISPLAY-}" != "x" ]]; then
#     configPath=$ARTDAQ_MFEXTENSIONS_DIR/config/msgviewer.fcl
#     if [ -n "${ARTDAQ_MFEXTENSIONS_FQ_DIR}" ]; then configPath=${ARTDAQ_MFEXTENSIONS_FQ_DIR}/bin/msgviewer.fcl; fi
#     msgviewer -c $configPath 2>&1 >${logroot}/msgviewer.log &
#     echo "udp: { type: \"UDP\" threshold: \"DEBUG\" host: \"${HOSTNAME}\" port: 30000 }" >${logroot}/MessageFacility.fcl
#     export ARTDAQ_LOG_FHICL=${logroot}/MessageFacility.fcl
#     echo "Sleeping for 5 seconds to allow MessageViewer time to start"
#     sleep 5
# fi

# start PMT
pmt.rb -p ${ARTDAQDEMO_PMT_PORT} -d $tempFile --logpath ${logroot} --display ${DISPLAY}
rm $tempFile

