#include "artdaq-demo/Generators/AsciiSimulator.hh"

#include "canvas/Utilities/Exception.h"

#include "artdaq-core-demo/Overlays/AsciiFragment.hh"
#include "artdaq-core-demo/Overlays/AsciiFragmentWriter.hh"
#include "artdaq-core-demo/Overlays/FragmentType.hh"
#include "artdaq-core/Utilities/SimpleLookupPolicy.hh"
#include "artdaq/Generators/GeneratorMacros.hh"
#include "cetlib_except/exception.h"
#include "fhiclcpp/ParameterSet.h"

#include <fstream>
#include <iomanip>
#include <iostream>
#include <iterator>

#include <unistd.h>

namespace {
/**
 * \brief Convert sizeof(T) characters of a string to a number containing the ASCII representation of that string
 * \tparam T Output type
 * \param input String to convert to ASCII-encoded number
 * \return ASCII-encoded number
 */
template<typename T>
T convertToASCII(std::string input)
{
	if (input.size() < sizeof(T) / sizeof(char))
	{
		input.insert(0, sizeof(T) / sizeof(char) - input.size(), ' ');
	}
	else if (input.size() > sizeof(T) / sizeof(char))
	{
		input.erase(0, input.size() - sizeof(T) / sizeof(char));
	}

	uint64_t bigOutput = 0ull;
	//    std::ofstream outputStr ("/tmp/ASCIIConverter.bin", std::ios::out | std::ios::app | std::ios::binary );
	for (uint i = 0; i < input.length(); ++i)
	{
		// outputStr.write((char*)&input[i],sizeof(char));
		bigOutput *= 0x100;
		bigOutput += input[input.length() - i - 1];
	}

	// outputStr.close();
	return static_cast<T>(bigOutput);
}
}  // namespace

demo::AsciiSimulator::AsciiSimulator(fhicl::ParameterSet const& ps)
    : CommandableFragmentGenerator(ps)
    , throttle_usecs_(ps.get<size_t>("throttle_usecs", 100000))
    , string1_(ps.get<std::string>("string1", "All work and no play makes ARTDAQ a dull library"))
    , string2_(ps.get<std::string>("string2", "Hey, look at what ARTDAQ can do!"))
    , timestamp_(0)
    , timestampScale_(ps.get<int>("timestamp_scale_factor", 1))
{}

bool demo::AsciiSimulator::getNext_(artdaq::FragmentPtrs& frags)
{
	// JCF, 9/23/14

	// If throttle_usecs_ is greater than zero (i.e., user requests a
	// sleep interval before generating the pseudodata) then during that
	// interval perform a periodic check to see whether a stop request
	// has been received

	// Values for throttle_usecs_ and throttle_usecs_check_ will have
	// been tested for validity in constructor

	std::unique_lock<std::mutex> throttle_lock(throttle_mutex_);
	throttle_cv_.wait_for(throttle_lock, std::chrono::microseconds(throttle_usecs_), [&]() { return should_stop(); });

	if (should_stop())
	{
		return false;
	}

	// Set fragment's metadata
	size_t data_size = (ev_counter() % 2) != 0u ? string1_.length() + 2 : string2_.length() + 2;
	AsciiFragment::Metadata metadata;
	std::string size_string = "S:" + std::to_string(data_size) + ",";
	metadata.charsInLine = convertToASCII<AsciiFragment::Metadata::chars_in_line_t>(size_string);

	// And use it, along with the artdaq::Fragment header information
	// (fragment id, sequence id, and user type) to create a fragment

	// We'll use the static factory function

	// artdaq::Fragment::FragmentBytes(std::size_t payload_size_in_bytes, sequence_id_t sequence_id,
	//  fragment_id_t fragment_id, type_t type, const T & metadata)

	// which will then return a unique_ptr to an artdaq::Fragment
	// object. The advantage of this approach over using the
	// artdaq::Fragment constructor is that, if we were to want to
	// initialize the artdaq::Fragment with a nonzero-size payload (data
	// after the artdaq::Fragment header and metadata), we could provide
	// the size of the payload in bytes, rather than in units of the
	// artdaq::Fragment's RawDataType (8 bytes, as of 3/26/14). The
	// artdaq::Fragment constructor itself was not altered so as to
	// maintain backward compatibility.

	std::size_t initial_payload_size = 0;

	std::unique_ptr<artdaq::Fragment> fragptr(artdaq::Fragment::FragmentBytes(
	    initial_payload_size, ev_counter(), fragment_id(), FragmentType::ASCII, metadata, timestamp_));
	frags.emplace_back(std::move(fragptr));

	// Then any overlay-specific quantities next; will need the
	// AsciiFragmentWriter class's setter-functions for this

	AsciiFragmentWriter newfrag(*frags.back());

	newfrag.set_hdr_line_number(
	    convertToASCII<AsciiFragment::Header::line_number_t>("LN:" + std::to_string(ev_counter()) + ","));

	newfrag.resize(data_size);

	// Now, generate the payload, based on the string to use
	std::string string_to_use = (ev_counter() % 2) != 0u ? string1_ : string2_;
	string_to_use += "\r\n";

	//  std::ofstream output ("/tmp/ASCIIGenerator.bin", std::ios::out | std::ios::app | std::ios::binary );
	for (uint i = 0; i < string_to_use.length(); ++i)
	{
		// output.write((char*)&string_to_use[i],sizeof(char));
		*(newfrag.dataBegin() + i) = string_to_use[i];  // NOLINT(cppcoreguidelines-pro-bounds-pointer-arithmetic)
	}
	//  output.close();

	ev_counter_inc();
	timestamp_ += timestampScale_;

	return true;
}

// The following macro is defined in artdaq's GeneratorMacros.hh header
DEFINE_ARTDAQ_COMMANDABLE_GENERATOR(demo::AsciiSimulator)
