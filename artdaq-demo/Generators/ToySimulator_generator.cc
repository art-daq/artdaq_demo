// For an explanation of this class, look at its header,
// ToySimulator.hh, as well as
// https://cdcvs.fnal.gov/redmine/projects/artdaq-demo/wiki/Fragments_and_FragmentGenerators_w_Toy_Fragments_as_Examples

#include "artdaq-demo/Generators/ToySimulator.hh"

#include "canvas/Utilities/Exception.h"

#include "artdaq-core/Utilities/SimpleLookupPolicy.hh"
#include "artdaq/Generators/GeneratorMacros.hh"

#include "artdaq-core-demo/Overlays/FragmentType.hh"
#include "artdaq-core-demo/Overlays/ToyFragment.hh"

#include "fhiclcpp/ParameterSet.h"

#include <fstream>
#include <iomanip>
#include <iostream>
#include <iterator>

#include <unistd.h>
#define TRACE_NAME "ToySimulator"
#include "cetlib_except/exception.h"
#include "tracemf.h"  // TRACE, TLOG*

demo::ToySimulator::ToySimulator(fhicl::ParameterSet const& ps)
    : CommandableFragmentGenerator(ps)
    , hardware_interface_(new ToyHardwareInterface(ps))
    , timestamp_(0)
    , timestampScale_(ps.get<int>("timestamp_scale_factor", 1))
    , rollover_subrun_interval_(ps.get<int>("rollover_subrun_interval", 0))
    , metadata_({0, 0, 0})
    , readout_buffer_(nullptr)
    , fragment_type_(static_cast<decltype(fragment_type_)>(artdaq::Fragment::InvalidFragmentType))
    , distribution_type_(static_cast<ToyHardwareInterface::DistributionType>(ps.get<int>("distribution_type")))
    , generated_fragments_per_event_(ps.get<int>("generated_fragments_per_event", 1))
    , exception_on_config_(ps.get<bool>("exception_on_config", false))
    , dies_on_config_(ps.get<bool>("dies_on_config", false))
    , lazy_mode_(ps.get<bool>("lazy_mode", false))

{
        if (lazy_mode_ && request_mode() == artdaq::RequestMode::Ignored) {
	  throw cet::exception("ToySimulator") << "The request mode has been set to \"Ignored\"; this is inconsistent with this ToySimulator's lazy mode set to \"true\"";
        }

	hardware_interface_->AllocateReadoutBuffer(&readout_buffer_);

	if (exception_on_config_)
	{
		throw cet::exception("ToySimulator") << "This is an engineered exception designed for testing purposes, set "
		                                        "by the exception_on_config FHiCL variable";
	}
	else if (dies_on_config_)
	{
		TLOG(TLVL_ERROR) << "This is an engineered process death, set by the dies_on_config FHiCL variable";
		std::exit(1);
	}

	metadata_.board_serial_number = hardware_interface_->SerialNumber() & 0xFFFF;
	metadata_.num_adc_bits = hardware_interface_->NumADCBits();
	TLOG(TLVL_INFO) << "Constructor: metadata_.unused = 0x" << std::hex << metadata_.unused
	                << " sizeof(metadata_) = " << std::dec << sizeof(metadata_);

	switch (hardware_interface_->BoardType())
	{
		case 1002:
			fragment_type_ = toFragmentType("TOY1");
			break;
		case 1003:
			fragment_type_ = toFragmentType("TOY2");
			break;
		default:
			throw cet::exception("ToySimulator") << "Unable to determine board type supplied by hardware";
	}
}

demo::ToySimulator::~ToySimulator() { hardware_interface_->FreeReadoutBuffer(readout_buffer_); }

bool demo::ToySimulator::getNext_(artdaq::FragmentPtrs& frags)
{
	if (should_stop()) { return false; }

	// ToyHardwareInterface (an instance to which "hardware_interface_"
	// is a unique_ptr object) is just one example of the sort of
	// interface a hardware library might offer. For example, other
	// interfaces might require you to allocate and free the memory used
	// to store hardware data in your generator using standard C++ tools
	// (rather than via the "AllocateReadoutBuffer" and
	// "FreeReadoutBuffer" functions provided here), or could have a
	// function which directly returns a pointer to the data buffer
	// rather than sticking the data in the location pointed to by your
	// pointer (which is what happens here with readout_buffer_)

	// 15-Nov-2019, KAB, JCF: added handling of the 'lazy' mode.
	// In this context, "lazy" is intended to mean "only generate data when
	// it is requested".  With this code, we return before doing the work
	// of filling the buffer (lazy!), and we overwrite whatever local
	// calculation of the timestamp has been done with the very specific
	// timestamp that is contained in the request.  We could also capture
	// the sequence_id from the request and use it when creating the 
	// artdaq::Fragment, but that isn't strictly necessary since the sequence_ids
	// of pull-mode fragments get overwritten when they are matched to requests
	// in CommandableFragmentGenerator.
	// For completeness, we include tests of both the GetNextRequest and
	// GetRequest methods (controlled by the LAZY_MODEL pre-processor variable).
	if (lazy_mode_) {
#define LAZY_MODEL 0
#if LAZY_MODEL == 0
		auto request = GetNextRequest();
		if (request.first == 0) {
			usleep(10);
			return true;
		}

		timestamp_ = request.second;
		TLOG(51) << "Received a request for the fragment with timestamp " << timestamp_
		         << " and sequenceId " << request.first << ". Proceeding to fill the fragment buffer, etc.";
#else
		auto requests = GetRequests();
		auto request_iterator = requests.begin();
		std::pair<artdaq::Fragment::sequence_id_t, artdaq::Fragment::timestamp_t> new_request(0,0);
		TLOG(52) << "Looping through " << requests.size() << " requests to see if there is a new one.";
		while (request_iterator != requests.end())
		{
			if (lazily_handled_requests_.find(request_iterator->first) == lazily_handled_requests_.end())
			{
				lazily_handled_requests_.insert(request_iterator->first);
				new_request = *request_iterator;
				break;
			}
			++request_iterator;
		}
		if (new_request.first == 0)
		{
			usleep(10);
			return true;
		}
		timestamp_ = new_request.second;
		TLOG(51) << "Found a new request for the fragment with timestamp " << timestamp_
		         << " and sequenceId " << new_request.first << ". Proceeding to fill the fragment buffer, etc.";
#endif
	}

	std::size_t bytes_read = 0;
	hardware_interface_->FillBuffer(readout_buffer_, &bytes_read);

	// We'll use the static factory function

	// artdaq::Fragment::FragmentBytes(std::size_t payload_size_in_bytes, sequence_id_t sequence_id,
	//  fragment_id_t fragment_id, type_t type, const T & metadata)

	// which will then return a unique_ptr to an artdaq::Fragment
	// object.

	for (auto& id : fragmentIDs())
	{
		// The offset logic below is designed to both ensure
		// backwards compatibility and to (help) avoid collisions
		// with fragment_ids from other boardreaders if more than
		// one fragment is generated per event

		std::unique_ptr<artdaq::Fragment> fragptr(
		    artdaq::Fragment::FragmentBytes(bytes_read, ev_counter(), id, fragment_type_, metadata_, timestamp_));
		frags.emplace_back(std::move(fragptr));

		if (distribution_type_ != ToyHardwareInterface::DistributionType::uninitialized)
			memcpy(frags.back()->dataBeginBytes(), readout_buffer_, bytes_read);
		else
		{
			// Must preserve the Header!
			memcpy(frags.back()->dataBeginBytes(), readout_buffer_, sizeof(ToyFragment::Header));
		}

		TLOG(50) << "getNext_ after memcpy " << bytes_read
		         << " bytes and std::move dataSizeBytes()=" << frags.back()->sizeBytes()
		         << " metabytes=" << sizeof(metadata_);
	}

	if (metricMan != nullptr)
	{ metricMan->sendMetric("Fragments Sent", ev_counter(), "Events", 3, artdaq::MetricMode::LastPoint); }

	if (rollover_subrun_interval_ > 0 && ev_counter() % rollover_subrun_interval_ == 0 && fragment_id() == 0)
	{
		bool fragmentIdZero = false;
		for (auto& id : fragmentIDs())
		{
			if (id == 0) fragmentIdZero = true;
		}
		if (fragmentIdZero)
		{
			artdaq::FragmentPtr endOfSubrunFrag(new artdaq::Fragment(static_cast<size_t>(
			    ceil(sizeof(my_rank) / static_cast<double>(sizeof(artdaq::Fragment::value_type))))));
			endOfSubrunFrag->setSystemType(artdaq::Fragment::EndOfSubrunFragmentType);

			endOfSubrunFrag->setSequenceID(ev_counter() + 1);
			endOfSubrunFrag->setTimestamp(1 + (ev_counter() / rollover_subrun_interval_));

			*endOfSubrunFrag->dataBegin() = my_rank;
			frags.emplace_back(std::move(endOfSubrunFrag));
		}
	}

	ev_counter_inc();
	timestamp_ += timestampScale_;

	return true;
}

void demo::ToySimulator::start()
{
	hardware_interface_->StartDatataking();
	timestamp_ = 0;
}

void demo::ToySimulator::stop() { hardware_interface_->StopDatataking(); }

// The following macro is defined in artdaq's GeneratorMacros.hh header
DEFINE_ARTDAQ_COMMANDABLE_GENERATOR(demo::ToySimulator)
