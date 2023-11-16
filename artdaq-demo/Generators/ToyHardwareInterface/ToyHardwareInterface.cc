#include "artdaq-demo/Generators/ToyHardwareInterface/ToyHardwareInterface.hh"
#define TRACE_NAME "ToyHardwareInterface"
#include "artdaq-core-demo/Overlays/FragmentType.hh"
#include "artdaq-core-demo/Overlays/ToyFragment.hh"
#include "artdaq/DAQdata/Globals.hh"

#include "cetlib_except/exception.h"
#include "fhiclcpp/ParameterSet.h"

#include <unistd.h>
#include <cstdlib>
#include <iostream>
#include <random>

// JCF, Mar-17-2016

// ToyHardwareInterface is meant to mimic a vendor-provided hardware
// API, usable within the the ToySimulator fragment generator. For
// purposes of realism, it's a C++03-style API, as opposed to, say, one
// based in C++11 capable of taking advantage of smart pointers, etc.

ToyHardwareInterface::ToyHardwareInterface(fhicl::ParameterSet const& ps)
    : taking_data_(false)
    , change_after_N_seconds_(ps.get<size_t>("change_after_N_seconds", std::numeric_limits<size_t>::max()))
    , pause_after_N_seconds_(ps.get<size_t>("pause_after_N_seconds", 0))
    , exception_after_N_seconds_(ps.get<bool>("exception_after_N_seconds", false))
    , exit_after_N_seconds_(ps.get<bool>("exit_after_N_seconds", false))
    , abort_after_N_seconds_(ps.get<bool>("abort_after_N_seconds", false))
    , hang_after_N_seconds_(ps.get<bool>("hang_after_N_seconds", false))
    , fragment_type_(demo::toFragmentType(ps.get<std::string>("fragment_type")))
    , maxADCvalue_(static_cast<size_t>(pow(2, NumADCBits()) - 1))  // MUST be after "fragment_type"
    , distribution_type_(static_cast<DistributionType>(ps.get<int>("distribution_type")))
    , configured_rates_()
    , engine_(ps.get<int64_t>("random_seed", 314159))
    , uniform_distn_(new std::uniform_int_distribution<data_t>(0, maxADCvalue_))
    , gaussian_distn_(new std::normal_distribution<double>(0.5 * maxADCvalue_, 0.1 * maxADCvalue_))
    , start_time_(fake_time_)
    , rate_start_time_(fake_time_)
    , rate_send_calls_(0)
    , serial_number_((*uniform_distn_)(engine_))
{
	bool planned_disruption = exception_after_N_seconds_ || exit_after_N_seconds_ || abort_after_N_seconds_;

	if (planned_disruption && change_after_N_seconds_ == std::numeric_limits<size_t>::max())
	{
		throw cet::exception("HardwareInterface") << "A FHiCL parameter designed to create a disruption has been "  // NOLINT(cert-err60-cpp)
		                                             "set, so \"change_after_N_seconds\" should be set as well";
	}

	if (ps.has_key("nADCcounts") || !ps.has_key("rate_table"))
	{
		// OLD Config style
		auto counts1 = ps.get<size_t>("nADCcounts", 40);
		auto counts2 = ps.get<size_t>("nADCcounts_after_N_seconds", counts1);

		auto throttle = ps.get<size_t>("throttle_usecs", 100000);
		auto between = ps.get<size_t>("usecs_between_sends", 0);
		auto wait = throttle + between;
		auto rate = 1000000 / wait;

		RateInfo before;
		before.size_bytes = counts1 * sizeof(data_t) + sizeof(demo::ToyFragment::Header);
		before.rate_hz = rate;
		before.duration = change_after_N_seconds_ != std::numeric_limits<size_t>::max() 
			? std::chrono::microseconds(1000000 * change_after_N_seconds_) 
			: std::chrono::microseconds(1000000);
		configured_rates_.push_back(before);

		if (change_after_N_seconds_ != std::numeric_limits<size_t>::max())
		{
			RateInfo after;
			after.size_bytes = counts2 * sizeof(data_t) + sizeof(demo::ToyFragment::Header);
			after.rate_hz = rate;
			after.duration = std::chrono::microseconds(1000000 * change_after_N_seconds_);
			configured_rates_.push_back(after);
		}
	}
	else
	{
		// NEW Config style
		auto fhicl_rates = ps.get<std::vector<fhicl::ParameterSet>>("rate_table");

		for (auto& pps : fhicl_rates)
		{
			RateInfo this_rate;
			this_rate.size_bytes = pps.get<size_t>("size_bytes");
			this_rate.rate_hz = pps.get<size_t>("rate_hz");
			this_rate.duration = std::chrono::microseconds(pps.get<size_t>("duration_us", 1000000));
			configured_rates_.push_back(this_rate);
		}
	}

	bool first = true;
	for (auto& rate : configured_rates_) {
		TLOG(TLVL_INFO) << (first ? "W" : ", then w") << "ill generate " << rate.size_bytes << " B Fragments at " << rate.rate_hz << " Hz for " << rate.duration.count() << " us";
		first = false;
	}

	current_rate_ = configured_rates_.begin();
}

// JCF, Mar-18-2017

// "StartDatataking" is meant to mimic actions one would take when
// telling the hardware to start sending data - the uploading of
// values to registers, etc.

void ToyHardwareInterface::StartDatataking()
{
	taking_data_ = true;
	rate_send_calls_ = 0;
	current_rate_ = configured_rates_.begin();
	start_time_ = std::chrono::steady_clock::now();
	rate_start_time_ = start_time_;
}

void ToyHardwareInterface::StopDatataking()
{
	taking_data_ = false;
	start_time_ = fake_time_;
	rate_start_time_ = fake_time_;
}

void ToyHardwareInterface::FillBuffer(char* buffer, size_t* bytes_read)
{
	TLOG(TLVL_TRACE) << "FillBuffer BEGIN";
	if (taking_data_)
	{
		auto elapsed_secs_since_datataking_start = artdaq::TimeUtils::GetElapsedTime(start_time_);
		if (elapsed_secs_since_datataking_start < 0) elapsed_secs_since_datataking_start = 0;

		if (static_cast<size_t>(elapsed_secs_since_datataking_start) >= change_after_N_seconds_)
		{
			if (abort_after_N_seconds_)
			{
				TLOG(TLVL_ERROR) << "Engineered Abort!";
				std::abort();
			}
			else if (exit_after_N_seconds_)
			{
				TLOG(TLVL_ERROR) << "Engineered Exit!";
				std::exit(1);
			}
			else if (exception_after_N_seconds_)
			{
				TLOG(TLVL_ERROR) << "Engineered Exception!";
				throw cet::exception("HardwareInterface")  // NOLINT(cert-err60-cpp)
				    << "This is an engineered exception designed for testing purposes";
			}
			else if (hang_after_N_seconds_)
			{
				TLOG(TLVL_ERROR) << "Pretending that the hardware has hung! Variable name for gdb: hardwareIsHung";
				volatile bool hardwareIsHung = true;
				// Pretend the hardware hangs
				while (hardwareIsHung)
				{
					usleep(10000);
				}
			}

			if ((pause_after_N_seconds_ != 0u) && (static_cast<size_t>(elapsed_secs_since_datataking_start) % change_after_N_seconds_ == 0))
			{
				TLOG(TLVL_DEBUG + 3) << "pausing " << pause_after_N_seconds_ << " seconds";
				sleep(pause_after_N_seconds_);
				TLOG(TLVL_DEBUG + 3) << "resuming after pause of " << pause_after_N_seconds_ << " seconds";
			}
		}

		TLOG(TLVL_DEBUG + 3) << "FillBuffer: Setting bytes_read to " << sizeof(demo::ToyFragment::Header) + bytes_to_nWords_(current_rate_->size_bytes) * sizeof(data_t);
		*bytes_read = sizeof(demo::ToyFragment::Header) + bytes_to_nWords_(current_rate_->size_bytes) * sizeof(data_t);
		TLOG(TLVL_DEBUG + 3) << "FillBuffer: Making the fake data, starting with the header";

		// Can't handle a fragment whose size isn't evenly divisible by
		// the demo::ToyFragment::Header::data_t type size in bytes
		// std::cout << "Bytes to read: " << *bytes_read << ", sizeof(data_t): " <<
		// sizeof(demo::ToyFragment::Header::data_t) << std::endl;
		assert(*bytes_read % sizeof(demo::ToyFragment::Header::data_t) == 0);

		auto* header = reinterpret_cast<demo::ToyFragment::Header*>(buffer);  // NOLINT(cppcoreguidelines-pro-type-reinterpret-cast)

		header->event_size = *bytes_read / sizeof(demo::ToyFragment::Header::data_t);
		header->trigger_number = 99;
		header->distribution_type = static_cast<uint8_t>(distribution_type_);

		TLOG(TLVL_DEBUG + 3) << "FillBuffer: Generating nADCcounts ADC values ranging from 0 to max based on the desired distribution";

		std::function<data_t()> generator;
		data_t gen_seed = 0;

		switch (distribution_type_)
		{
			case DistributionType::uniform:
				generator = [&]() { return static_cast<data_t>((*uniform_distn_)(engine_)); };
				break;

			case DistributionType::gaussian:
				generator = [&]() {
					do
					{
						gen_seed = static_cast<data_t>(std::round((*gaussian_distn_)(engine_)));
					} while (gen_seed > maxADCvalue_);
					return gen_seed;
				};
				break;

			case DistributionType::monotonic: {
				generator = [&]() {
					if (++gen_seed > maxADCvalue_)
					{
						gen_seed = 0;
					}
					return gen_seed;
				};
			}
			break;

			case DistributionType::uninitialized:
			case DistributionType::uninit2:
				break;

			default:
				throw cet::exception("HardwareInterface") << "Unknown distribution type specified";  // NOLINT(cert-err60-cpp)
		}

		if (distribution_type_ != DistributionType::uninitialized && distribution_type_ != DistributionType::uninit2)
		{
			TLOG(TLVL_DEBUG + 3) << "FillBuffer: Calling generate_n";
			std::generate_n(reinterpret_cast<data_t*>(reinterpret_cast<demo::ToyFragment::Header*>(buffer) + 1),  // NOLINT(cppcoreguidelines-pro-type-reinterpret-cast,cppcoreguidelines-pro-bounds-pointer-arithmetic)
			                bytes_to_nWords_(current_rate_->size_bytes), generator);
		}
	}
	else
	{
		throw cet::exception("ToyHardwareInterface") << "Attempt to call FillBuffer when not sending data";  // NOLINT(cert-err60-cpp)
	}

	auto now = std::chrono::steady_clock::now();
	auto next = next_trigger_time_();

	if (next > now)
	{
		std::this_thread::sleep_until(next_trigger_time_());
	}
	++rate_send_calls_;
	TLOG(TLVL_TRACE) << "FillBuffer END";
}

void ToyHardwareInterface::AllocateReadoutBuffer(char** buffer)
{
	*buffer = reinterpret_cast<char*>(  // NOLINT(cppcoreguidelines-pro-type-reinterpret-cast)
	    new uint8_t[sizeof(demo::ToyFragment::Header) + maxADCcounts_() * sizeof(data_t)]);
}

void ToyHardwareInterface::FreeReadoutBuffer(const char* buffer) { delete[] buffer; }

int ToyHardwareInterface::BoardType() const
{
	// Pretend that the "BoardType" is some vendor-defined integer which
	// differs from the fragment_type_ we want to use as developers (and
	// which must be between 1 and 224, inclusive) so add an offset
	return static_cast<int>(fragment_type_) + 1000;
}

std::chrono::microseconds ToyHardwareInterface::rate_to_delay_(std::size_t hz) { return std::chrono::microseconds(static_cast<int>(1000000.0 / hz)); }

std::chrono::steady_clock::time_point ToyHardwareInterface::next_trigger_time_()
{
	auto next_time = rate_start_time_ + (rate_send_calls_ + 1) * rate_to_delay_(current_rate_->rate_hz);
	if (next_time > rate_start_time_ + current_rate_->duration)
	{
		if (++current_rate_ == configured_rates_.end()) current_rate_ = configured_rates_.begin();
		rate_send_calls_ = 0;
		rate_start_time_ = next_time;
	}
	return next_time;
}

size_t ToyHardwareInterface::bytes_to_nWords_(size_t bytes)
{
	if (bytes < sizeof(demo::ToyFragment::Header)) return 0;
	return (bytes - sizeof(demo::ToyFragment::Header)) / sizeof(data_t) + ((bytes - sizeof(demo::ToyFragment::Header)) % sizeof(data_t) == 0 ? 0 : 1);
}

size_t ToyHardwareInterface::maxADCcounts_()
{
	size_t max_bytes = 0;
	for (auto& rate : configured_rates_)
	{
		if (rate.size_bytes > max_bytes) max_bytes = rate.size_bytes;
	}
	return bytes_to_nWords_(max_bytes);
}

int ToyHardwareInterface::NumADCBits() const
{
	switch (fragment_type_)
	{
		case demo::FragmentType::TOY1:
			return 12;
			break;
		case demo::FragmentType::TOY2:
			return 14;
			break;
		default:
			throw cet::exception("ToyHardwareInterface") << "Unknown board type " << fragment_type_ << " ("  // NOLINT(cert-err60-cpp)
			                                             << demo::fragmentTypeToString(fragment_type_) << ").\n";
	};
}

int ToyHardwareInterface::SerialNumber() const
{
	// Serial number is generated from the uniform distribution on initialization of the class
	return serial_number_;
}
