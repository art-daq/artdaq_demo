////////////////////////////////////////////////////////////////////////
// Class:       CheckIntegrity
// Module Type: analyzer
// File:        CheckIntegrity_module.cc
// Description: Prints out information about each event.
////////////////////////////////////////////////////////////////////////

#include "art/Framework/Core/EDAnalyzer.h"
#include "art/Framework/Core/ModuleMacros.h"
#include "art/Framework/Principal/Event.h"
#include "art/Framework/Principal/Handle.h"
#include "canvas/Utilities/Exception.h"

#include "artdaq-core-demo/Overlays/FragmentType.hh"
#include "artdaq-core-demo/Overlays/ToyFragment.hh"
#include "artdaq-core/Data/ContainerFragment.hh"
#include "artdaq-core/Data/Fragment.hh"

#include "TRACE/tracemf.h"  // TLOG
#define TRACE_NAME "CheckIntegrity"

#include <algorithm>
#include <cassert>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <vector>

namespace demo {
class CheckIntegrity;
}  // namespace demo

/**
 * \brief Demonstration art::EDAnalyzer which checks that all ToyFragment ADC counts are in the defined range
 */
class demo::CheckIntegrity : public art::EDAnalyzer
{
public:
	/**
	 * \brief CheckIntegrity Constructor
	 * \param pset ParameterSet used to configure CheckIntegrity
	 *
	 * CheckIntegrity has the following paramters:
	 * "raw_data_label" (Default: "daq"): The label applied to data (usually "daq")
	 * "exception_on_integrity_failure" (Default: false): Whether to throw an exception (abort processing) if an
	 * integrity issue is found
	 */
	explicit CheckIntegrity(fhicl::ParameterSet const& pset);

	/**
	 * \brief Default destructor
	 */
	~CheckIntegrity() override = default;

	/**
	 * \brief Analyze an event. Called by art for each event in run (based on command line options)
	 * \param evt The art::Event object containing ToyFragments to check
	 */
	void analyze(art::Event const& evt) override;

private:
	CheckIntegrity(CheckIntegrity const&) = delete;
	CheckIntegrity(CheckIntegrity&&) = delete;
	CheckIntegrity& operator=(CheckIntegrity const&) = delete;
	CheckIntegrity& operator=(CheckIntegrity&&) = delete;

	std::string raw_data_label_;
	bool exception_on_integrity_failure_;
};

demo::CheckIntegrity::CheckIntegrity(fhicl::ParameterSet const& pset)
    : EDAnalyzer(pset)
    , raw_data_label_(pset.get<std::string>("raw_data_label", "daq"))
    , exception_on_integrity_failure_(pset.get<bool>("exception_on_integrity_failure", false))
{}

void demo::CheckIntegrity::analyze(art::Event const& evt)
{
	artdaq::Fragments fragments;
	artdaq::FragmentPtrs containerFragments;

	std::vector<art::Handle<artdaq::Fragments>> fragmentHandles;
	evt.getManyByType(fragmentHandles);

	for (const auto& handle : fragmentHandles)
	{
		if (!handle.isValid() || handle->empty())
		{
			continue;
		}

		if (handle->front().type() == artdaq::Fragment::ContainerFragmentType)
		{
			for (const auto& cont : *handle)
			{
				artdaq::ContainerFragment contf(cont);
				if (contf.fragment_type() != demo::FragmentType::TOY1 && contf.fragment_type() != demo::FragmentType::TOY2)
				{
					break;
				}

				for (size_t ii = 0; ii < contf.block_count(); ++ii)
				{
					containerFragments.push_back(contf[ii]);
					fragments.push_back(*containerFragments.back());
				}
			}
		}
		else
		{
			if (handle->front().type() == demo::FragmentType::TOY1 || handle->front().type() == demo::FragmentType::TOY2)
			{
				for (auto frag : *handle)
				{
					fragments.emplace_back(frag);
				}
			}
		}
	}

	TLOG(TLVL_DEBUG) << "Run " << evt.run() << ", subrun " << evt.subRun() << ", event " << evt.event() << " has "
	                 << fragments.size() << " fragment(s) of type TOY1 or TOY2";

	bool err = false;
	for (const auto& frag : fragments)
	{
		// These methods take significantly more time when processing non-CurrentVersion Fragments, so cache them here
		ToyFragment bb(frag);
		auto dist_type = bb.hdr_distribution_type();

		if (bb.hdr_event_size() * sizeof(ToyFragment::Header::data_t) !=
		    frag.dataSize() * sizeof(artdaq::RawDataType))
		{
			TLOG(TLVL_ERROR) << "Error: in run " << evt.run() << ", subrun " << evt.subRun() << ", event "
			                 << evt.event() << ", seqID " << frag.sequenceID() << ", fragID " << frag.fragmentID()
			                 << ": Size mismatch!"
			                 << " ToyFragment Header reports size of "
			                 << bb.hdr_event_size() * sizeof(ToyFragment::Header::data_t)
			                 << " bytes, but Fragment reports size of "
			                 << frag.dataSize() * sizeof(artdaq::RawDataType) << " bytes.";

			if (exception_on_integrity_failure_)
			{
				throw cet::exception("CheckIntegrity")
				    << "Error: in run " << evt.run() << ", subrun " << evt.subRun() << ", event " << evt.event()
				    << ", seqID " << frag.sequenceID() << ", fragID " << frag.fragmentID() << ": Size mismatch!"
				    << " ToyFragment Header reports size of "
				    << bb.hdr_event_size() * sizeof(ToyFragment::Header::data_t)
				    << " bytes, but Fragment reports size of " << frag.dataSize() * sizeof(artdaq::RawDataType)
				    << " bytes.";
			}
			continue;
		}

		if ((frag.size() - frag.headerSizeWords() - frag.dataSize()) * sizeof(artdaq::RawDataType) !=
		    sizeof(ToyFragment::Metadata))
		{
			TLOG(TLVL_ERROR) << "Error: in run " << evt.run() << ", subrun " << evt.subRun() << ", event "
			                 << evt.event() << ", seqID " << frag.sequenceID() << ", fragID " << frag.fragmentID()
			                 << ": Metadata error!"
			                 << " ToyFragment metadata size should be " << sizeof(ToyFragment::Metadata)
			                 << " bytes, but Fragment reports size of "
			                 << (frag.size() - frag.headerSizeWords() - frag.dataSize()) *
			                        sizeof(artdaq::RawDataType)
			                 << " bytes.";
			if (exception_on_integrity_failure_)
			{
				throw cet::exception("CheckIntegrity")
				    << "Error: in run " << evt.run() << ", subrun " << evt.subRun() << ", event " << evt.event()
				    << ", seqID " << frag.sequenceID() << ", fragID " << frag.fragmentID() << ": Metadata error!"
				    << " ToyFragment metadata size should be " << sizeof(ToyFragment::Metadata)
				    << " bytes, but Fragment reports size of "
				    << (frag.size() - frag.headerSizeWords() - frag.dataSize()) * sizeof(artdaq::RawDataType)
				    << " bytes.";
			}
			continue;
		}

		{
			auto adc_iter = bb.dataBeginADCs();
			auto adc_end = bb.dataEndADCs();
			ToyFragment::adc_t expected_adc = 1;

			for (; adc_iter != adc_end; adc_iter++, expected_adc++)
			{
				if (expected_adc > demo::ToyFragment::adc_range(frag.metadata<ToyFragment::Metadata>()->num_adc_bits))
				{
					expected_adc = 0;
				}

				// ELF 7/10/18: Distribution type 2 is the monotonically-increasing one
				if (dist_type == 2 && *adc_iter != expected_adc)
				{
					TLOG(TLVL_ERROR) << "Error: in run " << evt.run() << ", subrun " << evt.subRun() << ", event "
					                 << evt.event() << ", seqID " << frag.sequenceID() << ", fragID "
					                 << frag.fragmentID() << ": expected an ADC value of " << expected_adc << ", got "
					                 << *adc_iter;
					err = true;
					if (exception_on_integrity_failure_)
					{
						throw cet::exception("CheckIntegrity")
						    << "Error: in run " << evt.run() << ", subrun " << evt.subRun() << ", event " << evt.event()
						    << ", seqID " << frag.sequenceID() << ", fragID " << frag.fragmentID()
						    << ": expected an ADC value of " << expected_adc << ", got " << *adc_iter;
					}
					break;
				}

				// ELF 7/10/18: As of now, distribution types 3 and 4 are uninitialized, and can therefore produce
				// out-of-range counts.
				if (bb.hdr_distribution_type() < 3 &&
				    *adc_iter > demo::ToyFragment::adc_range(frag.metadata<ToyFragment::Metadata>()->num_adc_bits))
				{
					TLOG(TLVL_ERROR) << "Error: in run " << evt.run() << ", subrun " << evt.subRun() << ", event "
					                 << evt.event() << ", seqID " << frag.sequenceID() << ", fragID "
					                 << frag.fragmentID() << ": " << *adc_iter
					                 << " is out-of-range for this Fragment type";
					err = true;
					if (exception_on_integrity_failure_)
					{
						throw cet::exception("CheckIntegrity")
						    << "Error: in run " << evt.run() << ", subrun " << evt.subRun() << ", event " << evt.event()
						    << ", seqID " << frag.sequenceID() << ", fragID " << frag.fragmentID() << ": " << *adc_iter
						    << " is out-of-range for this Fragment type";
					}
					break;
				}
			}
		}
	}
	if (!err)
	{
		TLOG(TLVL_DEBUG) << "In run " << evt.run() << ", subrun " << evt.subRun() << ", event " << evt.event()
		                 << ", everything is fine";
	}
}

DEFINE_ART_MODULE(demo::CheckIntegrity)  // NOLINT(performance-unnecessary-value-param)
