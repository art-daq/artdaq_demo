#define TRACE_NAME "EventReporterOutput"

#include "art/Framework/Core/ModuleMacros.h"
#include "art/Framework/Core/OutputModule.h"
#include "art/Framework/Principal/EventPrincipal.h"
#include "art/Framework/Principal/OutputHandle.h"
#include "art/Framework/Principal/RunPrincipal.h"
#include "art/Framework/Principal/SubRunPrincipal.h"
#include "art/Framework/Services/Registry/ServiceHandle.h"
#include "art/Persistency/Provenance/ProcessHistoryRegistry.h"
#include "canvas/Persistency/Common/Wrapper.h"
#include "canvas/Persistency/Provenance/BranchDescription.h"
#include "canvas/Persistency/Provenance/BranchKey.h"
#include "canvas/Persistency/Provenance/History.h"
#include "canvas/Persistency/Provenance/ParentageRegistry.h"
#include "canvas/Persistency/Provenance/ProcessConfiguration.h"
#include "canvas/Persistency/Provenance/ProcessConfigurationID.h"
#include "canvas/Persistency/Provenance/ProcessHistoryID.h"
#include "canvas/Persistency/Provenance/ProductList.h"
#include "canvas/Persistency/Provenance/ProductProvenance.h"
#include "canvas/Persistency/Provenance/RunAuxiliary.h"
#include "canvas/Persistency/Provenance/SubRunAuxiliary.h"
#include "canvas/Utilities/DebugMacros.h"
#include "canvas/Utilities/Exception.h"
#if ART_HEX_VERSION < 0x30901
#include "canvas/Utilities/WrappedTypeID.h"
#endif
#include "cetlib/column_width.h"
#include "cetlib/lpad.h"
#include "cetlib/rpad.h"
#include "fhiclcpp/ParameterSet.h"
#include "fhiclcpp/ParameterSetID.h"
#include "fhiclcpp/ParameterSetRegistry.h"

#include "artdaq-core/Data/detail/ParentageMap.hh"
#include "artdaq/DAQdata/Globals.hh"
#include "artdaq/DAQdata/NetMonHeader.hh"
#include "artdaq/TransferPlugins/MakeTransferPlugin.hh"
#include "artdaq/TransferPlugins/TransferInterface.hh"

#include <TClass.h>
#include <TMessage.h>

#include <unistd.h>
#include <algorithm>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <sstream>
#include <string>
#include <vector>

namespace art {
class EventReporterOutput;
}  // namespace art

/**
 * \brief An art::OutputModule which does nothing, but reports seen events and their fragments.
 * This module is designed for debugging purposes, where writing events into ROOT files
 * or sending events down stream is not necessary.
 */
class art::EventReporterOutput : public OutputModule
{
public:
	/**
	 * \brief EventReporterOutput Constructor
	 * \param ps ParameterSet used to configure EventReporterOutput
	 *
	 * EventReporterOutput accepts no Parameters beyond those which art::OutputModule takes.
	 * See the art::OutputModule documentation for more details on those Parameters.
	 */
	explicit EventReporterOutput(fhicl::ParameterSet const& ps);

	/**
	 * \brief EventReporterOutput Destructor
	 */
	~EventReporterOutput() override;

private:
	EventReporterOutput(EventReporterOutput const&) = delete;
	EventReporterOutput(EventReporterOutput&&) = delete;
	EventReporterOutput& operator=(EventReporterOutput const&) = delete;
	EventReporterOutput& operator=(EventReporterOutput&&) = delete;

	void openFile(FileBlock const& /*unused*/) override;

	virtual void closeFile();

	void respondToCloseInputFile(FileBlock const& /*unused*/) override;

	void respondToCloseOutputFiles(FileBlock const& /*unused*/) override;

	void endJob() override;

	void write(EventPrincipal& /*ep*/) override;

	void writeRun(RunPrincipal& /*r*/) override;

	void writeSubRun(SubRunPrincipal& /*sr*/) override;
};

art::EventReporterOutput::EventReporterOutput(fhicl::ParameterSet const& ps)
    : OutputModule(ps)
{
	TLOG(TLVL_DEBUG) << "Begin: EventReporterOutput::EventReporterOutput(ParameterSet const& ps)";
}

art::EventReporterOutput::~EventReporterOutput()
{
	TLOG(TLVL_DEBUG) << "Begin: EventReporterOutput::~EventReporterOutput()";
}

void art::EventReporterOutput::openFile(FileBlock const& /*unused*/)
{
	TLOG(TLVL_DEBUG) << "Begin/End: EventReporterOutput::openFile(const FileBlock&)";
}

void art::EventReporterOutput::closeFile() { TLOG(TLVL_DEBUG) << "Begin/End: EventReporterOutput::closeFile()"; }

void art::EventReporterOutput::respondToCloseInputFile(FileBlock const& /*unused*/)
{
	TLOG(TLVL_DEBUG) << "Begin/End: EventReporterOutput::respondToCloseOutputFiles(FileBlock const&)";
}

void art::EventReporterOutput::respondToCloseOutputFiles(FileBlock const& /*unused*/)
{
	TLOG(TLVL_DEBUG) << "Begin/End: EventReporterOutput::respondToCloseOutputFiles(FileBlock const&)";
}

void art::EventReporterOutput::endJob() { TLOG(TLVL_DEBUG) << "Begin: EventReporterOutput::endJob()"; }

void art::EventReporterOutput::write(EventPrincipal& ep)
{
	TLOG(TLVL_DEBUG) << " Begin: EventReporterOutput::write(const EventPrincipal& ep)";

	using RawEvent = artdaq::Fragments;
	;
	using RawEvents = std::vector<RawEvent>;
	using RawEventHandle = art::Handle<RawEvent>;
	using RawEventHandles = std::vector<RawEventHandle>;

	auto result_handles = std::vector<art::GroupQueryResult>();

	auto const& wrapped = art::WrappedTypeID::make<RawEvent>();
	ModuleContext const mc{moduleDescription()};
	ProcessTag const processTag{"", mc.moduleDescription().processName()};

	result_handles = ep.getMany(mc, wrapped, art::MatchAllSelector{}, processTag);

	for (auto const& result_handle : result_handles)
	{
		auto const raw_event_handle = RawEventHandle(result_handle);

		if (!raw_event_handle.isValid())
		{
			continue;
		}

		for (auto const& fragment : *raw_event_handle)
		{
			TLOG(TLVL_DEBUG) << "EventReporterOutput::write: Event sequenceID=" << fragment.sequenceID()
			                 << ", fragmentID=" << fragment.fragmentID();
		}
	}
}

void art::EventReporterOutput::writeRun(RunPrincipal& /*r*/)
{
	TLOG(TLVL_DEBUG) << " EventReporterOutput::writeRun(const RunPrincipal& rp)";
}

void art::EventReporterOutput::writeSubRun(SubRunPrincipal& /*sr*/)
{
	TLOG(TLVL_DEBUG) << " EventReporterOutput:: writeSubRun(const SubRunPrincipal& srp)";
}

DEFINE_ART_MODULE(art::EventReporterOutput)  // NOLINT(performance-unnecessary-value-param)
