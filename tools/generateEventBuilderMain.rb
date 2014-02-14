# This function will generate the FHiCL code used to control the
# EventBuilderMain application by configuring its
# artdaq::EventBuilderCore object

require File.join( File.dirname(__FILE__), 'generateCompression' )
require File.join( File.dirname(__FILE__), 'generateEventBuilder' )


def generateEventBuilderMain(ebIndex, totalFRs, totalEBs, totalAGs, compressionLevel, 
                         totalv1720s, totalv1724s, dataDir, onmonEnable,
                         diskWritingEnable, fragSizeWords, totalFragments,
                         fclWFViewer )
  # Do the substitutions in the event builder configuration given the options
  # that were passed in from the command line.  

  ebConfig = String.new( "\

services: {
  scheduler: {
    fileMode: NOMERGE
  }
  user: {
    NetMonTransportServiceInterface: {
      service_provider: NetMonTransportService
      first_data_receiver_rank: %{ag_rank}
      mpi_buffer_count: %{netmonout_buffer_count}
      max_fragment_size_words: %{size_words}
      data_receiver_count: 1 # %{ag_count}
      #broadcast_sends: true
    }
  }
  Timing: { summaryOnly: true }
  #SimpleMemoryCheck: { }
}

%{event_builder_code}

outputs: {
  %{netmon_output}netMonOutput: {
  %{netmon_output}  module_type: NetMonOutput
  %{netmon_output}  %{drop_uncompressed}outputCommands: [ \"keep *\", \"drop artdaq::Fragments_daq_V1720_*\", \"drop artdaq::Fragments_daq_V1724_*\" ]
  %{netmon_output}}
  %{root_output}normalOutput: {
  %{root_output}  module_type: RootOutput
  %{root_output}  fileName: \"%{output_file}\"
  %{root_output}  compressionLevel: 0
  %{root_output}  %{drop_uncompressed}outputCommands: [ \"keep *\", \"drop artdaq::Fragments_daq_V1720_*\", \"drop artdaq::Fragments_daq_V1724_*\" ]
  %{root_output}}
}

physics: {
  analyzers: {
%{phys_anal_onmon_cfg}
  }

  producers: {

     %{huffdiffV1720}

     %{huffdiffV1724}
  }

  p1: [ %{compressionModules} ] 

  %{enable_onmon}a1: [ app, wf ]

  %{netmon_output}my_output_modules: [ netMonOutput ]
  %{root_output}my_output_modules: [ normalOutput ]
}
source: {
  module_type: RawInput
  waiting_time: 900
  resume_after_timeout: true
  fragment_type_map: [[1, \"missed\"], [3, \"V1720\"], [4, \"V1724\"], [6, \"TOY1\"], [7, \"TOY2\"]]
}
process_name: DAQ" )

verbose = "true"

if Integer(totalAGs) >= 1
  verbose = "false"
end


event_builder_code = generateEventBuilder( fragSizeWords, totalFRs, totalAGs, totalFragments, verbose)

ebConfig.gsub!(/\%\{event_builder_code\}/, event_builder_code)

ebConfig.gsub!(/\%\{ag_rank\}/, String(totalFRs + totalEBs))
ebConfig.gsub!(/\%\{ag_count\}/, String(totalAGs))
ebConfig.gsub!(/\%\{size_words\}/, String(fragSizeWords))
ebConfig.gsub!(/\%\{netmonout_buffer_count\}/, String(totalAGs*4))

compressionModules = []

if Integer(compressionLevel) > 0 && Integer(compressionLevel) < 3
  if Integer(totalv1720s) > 0
    ebConfig.gsub!(/\%\{huffdiffV1720\}/, "huffdiffV1720: { " + generateCompression("V1720") + "}" )
    compressionModules << "huffdiffV1720"
  else
    ebConfig.gsub!(/\%\{huffdiffV1720\}/, "")
  end

  if Integer(totalv1724s) > 0
    ebConfig.gsub!(/\%\{huffdiffV1724\}/, "huffdiffV1724: { " + generateCompression("V1724") + "}" )
    compressionModules << "huffdiffV1724"
  else
    ebConfig.gsub!(/\%\{huffdiffV1724\}/, "")
  end

else
  ebConfig.gsub!(/\%\{huffdiffV1720\}/, "")
  ebConfig.gsub!(/\%\{huffdiffV1724\}/, "")
end

if Integer(compressionLevel) > 1
  ebConfig.gsub!(/\%\{drop_uncompressed\}/, "")
else
  ebConfig.gsub!(/\%\{drop_uncompressed\}/, "#")
end

ebConfig.gsub!(/\%\{compressionModules\}/, compressionModules.join(","))

if Integer(totalAGs) >= 1
  ebConfig.gsub!(/\%\{netmon_output\}/, "")
  ebConfig.gsub!(/\%\{root_output\}/, "#")
  ebConfig.gsub!(/\%\{enable_onmon\}/, "#")
  ebConfig.gsub!(/\%\{phys_anal_onmon_cfg\}/, "")
else
  ebConfig.gsub!(/\%\{netmon_output\}/, "#")
  if Integer(diskWritingEnable) != 0
    ebConfig.gsub!(/\%\{root_output\}/, "")
  else
    ebConfig.gsub!(/\%\{root_output\}/, "#")
  end
  if Integer(onmonEnable) != 0
    ebConfig.gsub!(/\%\{phys_anal_onmon_cfg\}/, fclWFViewer )
    ebConfig.gsub!(/\%\{enable_onmon\}/, "")
  else
    ebConfig.gsub!(/\%\{phys_anal_onmon_cfg\}/, "")
    ebConfig.gsub!(/\%\{enable_onmon\}/, "#")
  end
end


currentTime = Time.now
fileName = "artdaqdemo_eb%02d_" % ebIndex
fileName += "r%06r_sr%02s_%to"
fileName += ".root"
outputFile = File.join(dataDir, fileName)
ebConfig.gsub!(/\%\{output_file\}/, outputFile)

return ebConfig

end


