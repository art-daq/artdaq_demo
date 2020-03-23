////////////////////////////////////////////////////////////////////////
// Class:       ToyDump
// Module Type: analyzer
// File:        ToyDump_module.cc
// Description: Prints out information about each event.
////////////////////////////////////////////////////////////////////////

#include "art/Framework/Core/EDAnalyzer.h"
#include "art/Framework/Core/ModuleMacros.h"
#include "art/Framework/Principal/Event.h"
#include "art/Framework/Principal/Handle.h"
#include "canvas/Utilities/Exception.h"

#include "artdaq-core-demo/Overlays/AsciiFragment.hh"
#include "artdaq-core-demo/Overlays/FragmentType.hh"
#include "artdaq-core/Data/ContainerFragment.hh"
#include "artdaq-core/Data/Fragment.hh"

#include <algorithm>
#include <cassert>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <vector>

namespace demo {
class ASCIIDump;
}

/**
 * \brief An art::EDAnalyzer meant for decoding demo::ASCIIFragment objects
 */
class demo::ASCIIDump : public art::EDAnalyzer
{
public:
	/**
	 * \brief ASCIIDump Constructor
	 * \param pset ParameterSet used for configuring ASCIIDump. Parameter is "raw_data_label", default "daq".
	 */
	explicit ASCIIDump(fhicl::ParameterSet const& pset);

	virtual ~ASCIIDump();

	/**
	 * \brief Analyze an event. Called by art for each event in run (based on command line options)
	 * \param evt The art::Event object to dump AsciiFragments from
	 */
	void analyze(art::Event const& evt) override;

private:
	std::string raw_data_label_;
};

demo::ASCIIDump::ASCIIDump(fhicl::ParameterSet const& pset)
    : EDAnalyzer(pset), raw_data_label_(pset.get<std::string>("raw_data_label", "daq"))
{}

demo::ASCIIDump::~ASCIIDump() {}

void demo::ASCIIDump::analyze(art::Event const& evt)
{
	art::EventNumber_t eventNumber = evt.event();

	// ***********************
	// *** ASCII Fragments ***
	// ***********************

	artdaq::Fragments fragments;
	artdaq::FragmentPtrs containerFragments;
	std::vector<art::Handle<artdaq::Fragments>> fragmentHandles;
	evt.getManyByType(fragmentHandles);

	for (auto handle : fragmentHandles)
	{
		if (!handle.isValid() || handle->size() == 0) continue;

		if (handle->front().type() == artdaq::Fragment::ContainerFragmentType)
		{
			for (auto cont : *handle)
			{
				artdaq::ContainerFragment contf(cont);
				if (contf.fragment_type() != demo::FragmentType::ASCII)
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
			if (handle->front().type() == demo::FragmentType::ASCII)
			{
				for (auto frag : *handle) { fragments.emplace_back(frag); }
			}
		}
	}

	std::cout << "######################################################################" << std::endl;
	std::cout << std::endl;
	std::cout << "Run " << evt.run() << ", subrun " << evt.subRun() << ", event " << eventNumber << " has "
	          << fragments.size() << " ASCII fragment(s)" << std::endl;

	for (const auto& frag : fragments)
	{
		AsciiFragment bb(frag);

		std::cout << std::endl;
		std::cout << "Ascii fragment " << frag.fragmentID() << " is version " << frag.version() << std::endl;
		std::cout << "Ascii fragment " << frag.fragmentID() << " has " << bb.total_line_characters()
		          << " characters in the line." << std::endl;
		std::cout << std::endl;

		if (frag.hasMetadata())
		{
			std::cout << std::endl;
			std::cout << "Fragment metadata: " << std::endl;
			AsciiFragment::Metadata const* md = frag.metadata<AsciiFragment::Metadata>();
			std::cout << "Chars in line: ";
			auto mdChars = md->charsInLine;
			std::cout.write(reinterpret_cast<const char*>(&mdChars), sizeof(uint32_t) / sizeof(char));
			std::cout << std::endl;
			std::cout << std::endl;
		}

		std::ofstream output("out.bin", std::ios::out | std::ios::app | std::ios::binary);
		for (uint32_t i_adc = 0; i_adc < bb.total_line_characters(); ++i_adc)
		{ output.write((char*)(bb.dataBegin() + i_adc), sizeof(char)); }
		output.close();
		std::cout << std::endl;
		std::cout << std::endl;
	}
	std::cout << std::endl;
}

DEFINE_ART_MODULE(demo::ASCIIDump)
