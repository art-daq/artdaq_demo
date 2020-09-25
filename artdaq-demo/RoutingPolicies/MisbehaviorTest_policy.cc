#include "artdaq/DAQdata/Globals.hh"
#include "artdaq/RoutingPolicies/PolicyMacros.hh"
#include "artdaq/RoutingPolicies/RoutingManagerPolicy.hh"
#include "fhiclcpp/ParameterSet.h"
#include "messagefacility/MessageLogger/MessageLogger.h"

namespace demo {
/**
 * \brief A test RoutingManagerPolicy which does various "bad" things, determined by configuration
 */
class MisbehaviorTest : public artdaq::RoutingManagerPolicy
{
public:
	/**
	 * \brief MisbehaviorTest Constructor
	 * \param ps ParameterSet used to configure MisbehaviorTest
	 *
	 * \verbatim
	 * Note that only one misbehavior can be configured at a time. MisbehaviorTest will work like NoOp_policy when not
	 * misbehaving MisbehaviorTest accepts the following Parameters: "misbehave_after_n_events" (Default: 1000): The
	 * threshold after which it will start misbehaving "misbehave_pause_time_ms" (Default: 0): If greater than 0, will
	 * pause this long before sending out table updates "misbehave_send_confliting_table_data" (Default: false): If
	 * true, will send a table that contains the same sequence ID being sent to two different EventBuilders
	 * "misbehave_send_corrupt_table_data" (Default: false): If true, will send a table that contains an entry created
	 * using rand(), rand() "misbehave_overload_event_builder" (Default: false): If true, will send a large number of
	 * events to one EventBuilder \endverbatim
	 */
	explicit MisbehaviorTest(const fhicl::ParameterSet& ps);

	/**
	 * \brief MisbehaviorTest default Destructor
	 */
	~MisbehaviorTest() override = default;

	void CreateRoutingTable(artdaq::detail::RoutingPacket& table) override;
	artdaq::detail::RoutingPacketEntry CreateRouteForSequenceID(artdaq::Fragment::sequence_id_t seq, int requesting_rank) override;

private:
	MisbehaviorTest(MisbehaviorTest const&) = delete;
	MisbehaviorTest(MisbehaviorTest&&) = delete;
	MisbehaviorTest& operator=(MisbehaviorTest const&) = delete;
	MisbehaviorTest& operator=(MisbehaviorTest&&) = delete;

	artdaq::Fragment::sequence_id_t misbehave_after_;
	artdaq::Fragment::sequence_id_t misbehave_until_{0};  // For overloading EventBuilder in request mode
	size_t misbehave_pause_ms_;
	bool misbehave_conflicting_table_data_;
	bool misbehave_corrupt_table_data_;
	bool misbehave_overload_event_builder_;
};

MisbehaviorTest::MisbehaviorTest(const fhicl::ParameterSet& ps)
    : RoutingManagerPolicy(ps)
    , misbehave_after_(ps.get<size_t>("misbehave_after_n_events", 1000))
    , misbehave_pause_ms_(ps.get<size_t>("misbehave_pause_time_ms", 0))
    , misbehave_conflicting_table_data_(ps.get<bool>("misbehave_send_conflicting_table_data", false))
    , misbehave_corrupt_table_data_(ps.get<bool>("misbehave_send_corrupt_table_data", false))
    , misbehave_overload_event_builder_(ps.get<bool>("misbehave_overload_event_builder", false))
{
	srand(time(nullptr));  // NOLINT(cert-msc51-cpp)
	auto count = (misbehave_conflicting_table_data_ ? 1 : 0) + (misbehave_corrupt_table_data_ ? 1 : 0) +
	             (misbehave_overload_event_builder_ ? 1 : 0) + (misbehave_pause_ms_ > 0 ? 1 : 0);
	if (count > 1)
	{
		mf::LogWarning("MisbehaviorTest") << "Only one misbehavior is allowed at a time!";
		exit(3);
	}
}

void MisbehaviorTest::CreateRoutingTable(artdaq::detail::RoutingPacket& table)
{
	auto half = tokens_.size() / 2;
	size_t counter = 0;
	for (; counter < half; ++counter)
	{
		table.emplace_back(artdaq::detail::RoutingPacketEntry(next_sequence_id_, tokens_.at(counter)));
		next_sequence_id_++;
	}

	if (next_sequence_id_ > misbehave_after_)
	{
		if (!tokens_.empty())
		{
			if (misbehave_pause_ms_ > 0)
			{
				mf::LogError("MisbehaviorTest")
				    << "Pausing for " << misbehave_pause_ms_ << " milliseconds before sending table update";
				usleep(misbehave_pause_ms_ * 1000);
			}
			if (misbehave_conflicting_table_data_)
			{
				mf::LogError("MisbehaviorTest") << "Adding conflicting data point to output";
				table.emplace_back(next_sequence_id_, tokens_.at(counter) + 1);
			}
			if (misbehave_corrupt_table_data_)
			{
				mf::LogError("MisbehaviorTest") << "Adding random data point";
				table.emplace_back(seedAndRandom(), rand());  // NOLINT(cert-msc50-cpp)
			}
			if (misbehave_overload_event_builder_)
			{
				mf::LogError("MisbehaviorTest") << "Sending 100 events in a row to Rank " << tokens_.at(0);
				for (auto ii = 0; ii < 100; ++ii)
				{
					table.emplace_back(next_sequence_id_, tokens_.at(0));
					next_sequence_id_++;
				}
			}
			misbehave_after_ += misbehave_after_;
		}
	}

	for (; counter < tokens_.size(); ++counter)
	{
		table.emplace_back(artdaq::detail::RoutingPacketEntry(next_sequence_id_, tokens_.at(counter)));
		next_sequence_id_++;
	}
}
artdaq::detail::RoutingPacketEntry MisbehaviorTest::CreateRouteForSequenceID(artdaq::Fragment::sequence_id_t seq, int)
{
	artdaq::detail::RoutingPacketEntry output;
	if (!tokens_.empty())
	{
		if (seq > misbehave_after_ || seq < misbehave_until_)
		{
			if (seq > misbehave_until_)
			{
				misbehave_after_ += misbehave_after_;
			}
			if (misbehave_pause_ms_ > 0)
			{
				mf::LogError("MisbehaviorTest")
				    << "Pausing for " << misbehave_pause_ms_ << " milliseconds before sending table update";
				usleep(misbehave_pause_ms_ * 1000);

				auto dest = tokens_.front();  // No-Op: Use first token
				output = artdaq::detail::RoutingPacketEntry(seq, dest);
				tokens_.pop_front();
				tokens_used_since_last_update_++;
			}
			// misbehave_conflicting_table_data_ is not applicable for request mode
			if (misbehave_corrupt_table_data_)
			{
				mf::LogError("MisbehaviorTest") << "Adding random data point";
				output = artdaq::detail::RoutingPacketEntry(seedAndRandom(), rand());  // NOLINT(cert-msc50-cpp)
			}
			if (misbehave_overload_event_builder_)
			{
				output = artdaq::detail::RoutingPacketEntry(seq, tokens_.front());
				// Not removing token
				if (seq > misbehave_until_)
				{
					misbehave_until_ = seq + 100;
				}
			}
		}
		else
		{
			auto dest = tokens_.front();  // No-Op: Use first token
			output = artdaq::detail::RoutingPacketEntry(seq, dest);
			tokens_.pop_front();
			tokens_used_since_last_update_++;
		}
	}

	return output;
}
}  // namespace demo

DEFINE_ARTDAQ_ROUTING_POLICY(demo::MisbehaviorTest)