#include "TRACE/tracemf.h"
#define TRACE_NAME "WFViewer"

#include "art/Framework/Core/EDAnalyzer.h"
#include "art/Framework/Core/ModuleMacros.h"
#include "art/Framework/Principal/Event.h"
#include "art/Framework/Principal/Handle.h"
#include "art/Framework/Principal/Run.h"
#include "canvas/Utilities/InputTag.h"
#include "cetlib_except/exception.h"

#include "artdaq-core/Data/ContainerFragment.hh"
#include "artdaq-core/Data/Fragment.hh"

#include "artdaq-core-demo/Overlays/FragmentType.hh"
#include "artdaq-core-demo/Overlays/ToyFragment.hh"

#include <TAxis.h>
#include <TCanvas.h>
#include <TFile.h>
#include <TGraph.h>
#include <TH1D.h>
#include <TRootCanvas.h>
#include <TStyle.h>

#include <algorithm>
#include <functional>
#include <initializer_list>
#include <iostream>
#include <limits>
#include <memory>
#include <numeric>
#include <sstream>
#include <vector>

#include "tracemf.h"
#define TRACE_NAME "WFViewer"

namespace demo {
/**
 * \brief An example art analysis module which plots events both as histograms and event snapshots (plot of ADC value vs ADC number)
 */
class WFViewer : public art::EDAnalyzer
{
public:
	/**
	 * \brief WFViewer Constructor
	 * \param p ParameterSet used to configure WFViewer
	 *
	 * \verbatim
	 * WFViewer accepts the following Parameters:
	 * "prescale" (REQUIRED): WFViewer will only redraw historgrams once per this many events
	 * "digital_sum_only" (Default: false): Only create the histogram, not the event snapshot
	 * "num_x_plots": (Default: size_t::MAX_VALUE): Maximum number of columns of plots
	 * "num_y_plots": (Default: size_t::MAX_VALUE): Maximum number of rows of plots
	 * "raw_data_label": (Default: "daq"): Label under which artdaq data is stored
	 * "fragment_ids": (REQUIRED): List of ids to process. Fragment IDs are assigned by BoardReaders.
	 * "fileName": (Default: artdaqdemo_onmon.root): File name for output, if
	 * "write_to_file": (Default: false): Whether to write output histograms to "fileName"
	 * \endverbatim
	 */
	explicit WFViewer(fhicl::ParameterSet const& p);

	/**
	 * \brief WFViewer Destructor
	 */
	~WFViewer() override;

	/**
	 * \brief Analyze an event. Called by art for each event in run (based on command line options)
	 * \param e The art::Event object to process, and display if it passes the prescale
	 */
	void analyze(art::Event const& e) override;

	/**
	 * \brief Art calls this function at the beginning of the run. Used for set-up of ROOT histogram objects
	 * and to open the output file if one is specified.
	 */
	void beginRun(art::Run const& /*e*/) override;

private:
	WFViewer(WFViewer const&) = delete;
	WFViewer(WFViewer&&) = delete;
	WFViewer& operator=(WFViewer const&) = delete;
	WFViewer& operator=(WFViewer&&) = delete;

	TCanvas* histogram_canvas_;
	TCanvas* graph_canvas_;
	std::vector<Double_t> x_;
	int prescale_;
	bool digital_sum_only_;
	art::RunNumber_t current_run_;

	std::size_t num_x_plots_;
	std::size_t num_y_plots_;

	std::string raw_data_label_;
	std::vector<artdaq::Fragment::fragment_id_t> fragment_ids_;

	std::vector<TGraph*> graphs_;
	std::vector<TH1D*> histograms_;

	std::map<artdaq::Fragment::fragment_id_t, std::size_t> id_to_index_;
	std::string outputFileName_;
	TFile* fFile_;
	bool writeOutput_;
};
}  // namespace demo

demo::WFViewer::WFViewer(fhicl::ParameterSet const& ps)
    : art::EDAnalyzer(ps)
    , prescale_(ps.get<int>("prescale"))
    , digital_sum_only_(ps.get<bool>("digital_sum_only", false))
    , current_run_(0)
    , num_x_plots_(ps.get<std::size_t>("num_x_plots", std::numeric_limits<std::size_t>::max()))
    , num_y_plots_(ps.get<std::size_t>("num_y_plots", std::numeric_limits<std::size_t>::max()))
    , raw_data_label_(ps.get<std::string>("raw_data_label", "daq"))
    , fragment_ids_(ps.get<std::vector<artdaq::Fragment::fragment_id_t>>("fragment_ids"))
    , graphs_(fragment_ids_.size())
    , histograms_(fragment_ids_.size())
    , outputFileName_(ps.get<std::string>("fileName", "artdaqdemo_onmon.root"))
    , writeOutput_(ps.get<bool>("write_to_file", false))
{
	if (num_x_plots_ == std::numeric_limits<std::size_t>::max() ||
	    num_y_plots_ == std::numeric_limits<std::size_t>::max())
	{
		switch (fragment_ids_.size())
		{
			case 1:
				num_x_plots_ = num_y_plots_ = 1;
				break;
			case 2:
				num_x_plots_ = 2;
				num_y_plots_ = 1;
				break;
			case 3:
			case 4:
				num_x_plots_ = 2;
				num_y_plots_ = 2;
				break;
			case 5:
			case 6:
				num_x_plots_ = 3;
				num_y_plots_ = 2;
				break;
			case 7:
			case 8:
				num_x_plots_ = 4;
				num_y_plots_ = 2;
				break;
			default:
				num_x_plots_ = num_y_plots_ = static_cast<std::size_t>(ceil(sqrt(fragment_ids_.size())));
		}
	}

	// id_to_index_ will translate between a fragment's ID and where in
	// the vector of graphs and histograms it's located

	for (std::size_t i_f = 0; i_f < fragment_ids_.size(); ++i_f)
	{
		id_to_index_[fragment_ids_[i_f]] = i_f;
	}

	gStyle->SetOptStat("irm");
	gStyle->SetMarkerStyle(22);
	gStyle->SetMarkerColor(4);
}

demo::WFViewer::~WFViewer()
{
	// We're going to let ROOT's own garbage collection deal with histograms and Canvases...
	for (auto& histogram : histograms_)
	{
		histogram = nullptr;
	}
	for (auto& graph : graphs_)
	{
		graph = nullptr;
	}

	histogram_canvas_ = nullptr;
	graph_canvas_ = nullptr;
	fFile_ = nullptr;
}

void demo::WFViewer::analyze(art::Event const& e)
{
	static std::size_t evt_cntr = -1;
	evt_cntr++;

	// John F., 1/22/14 -- there's probably a more elegant way of
	// collecting fragments of various types using ART interface code;
	// will investigate. Right now, we're actually re-creating the
	// fragments locally

	artdaq::Fragments fragments;
	artdaq::FragmentPtrs containerFragments;

	std::vector<art::Handle<artdaq::Fragments>> fragmentHandles;
#if ART_HEX_VERSION < 0x30900
	e.getManyByType(fragmentHandles);
#else
	fragmentHandles = e.getMany<std::vector<artdaq::Fragment>>();
#endif

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

	// John F., 1/5/14

	// Here, we loop over the fragments passed to the analyze
	// function. A warning is flashed if either (A) the fragments aren't
	// all from the same event, or (B) there's an unexpected number of
	// fragments given the number of boardreaders and the number of
	// fragments per board

	// For every Nth event, where N is the "prescale" setting, plot the
	// distribution of ADC counts from each board_id / fragment_id
	// combo. Also, if "digital_sum_only" is set to false in the FHiCL
	// string, then plot, for the Nth event, a graph of the ADC values
	// across all channels in each board_id / fragment_id combo

	artdaq::Fragment::sequence_id_t expected_sequence_id = std::numeric_limits<artdaq::Fragment::sequence_id_t>::max();

	//  for (std::size_t i = 0; i < fragments.size(); ++i) {
	for (const auto& frag : fragments)
	{
		// Pointers to the types of fragment overlays WFViewer can handle;
		// only one will be used per fragment, of course

		std::unique_ptr<ToyFragment> toyPtr;

		//  const auto& frag( fragments[i] );  // Basically a shorthand

		//    if (i == 0)
		if (expected_sequence_id == std::numeric_limits<artdaq::Fragment::sequence_id_t>::max())
		{
			expected_sequence_id = frag.sequenceID();
		}

		if (expected_sequence_id != frag.sequenceID())
		{
			TLOG(TLVL_WARNING) << "Warning in WFViewer: expected fragment with sequence ID " << expected_sequence_id
			                   << ", received one with sequence ID " << frag.sequenceID();
		}

		auto fragtype = static_cast<FragmentType>(frag.type());
		std::size_t max_adc_count = std::numeric_limits<std::size_t>::max();
		std::size_t total_adc_values = std::numeric_limits<std::size_t>::max();

		switch (fragtype)
		{
			case FragmentType::TOY1:
				toyPtr = std::make_unique<ToyFragment>(frag);
				total_adc_values = toyPtr->total_adc_values();
				max_adc_count = static_cast<size_t>(pow(2, frag.template metadata<ToyFragment::Metadata>()->num_adc_bits) - 1);
				break;
			case FragmentType::TOY2:
				toyPtr = std::make_unique<ToyFragment>(frag);
				total_adc_values = toyPtr->total_adc_values();
				max_adc_count = static_cast<size_t>(pow(2, frag.template metadata<ToyFragment::Metadata>()->num_adc_bits) - 1);
				break;
			default:
				throw cet::exception("Error in WFViewer: unknown fragment type supplied");
		}

		artdaq::Fragment::fragment_id_t fragment_id = frag.fragmentID();
		if (id_to_index_.count(fragment_id) == 0u)
		{
			TLOG(TLVL_WARNING) << "Warning in WFViewer: unexpected Fragment with fragment_id " << std::to_string(fragment_id)
			                   << " encountered!";
			continue;
		}
		std::size_t ind = id_to_index_[fragment_id];

		// If a histogram doesn't exist for this board_id / fragment_id combo, create it

		if (histograms_[ind] == nullptr)
		{
			histograms_[ind] =
			    new TH1D(Form("Fragment_%d_hist", fragment_id), "", max_adc_count + 1, -0.5, max_adc_count + 0.5);

			histograms_[ind]->SetTitle(
			    Form("Frag %d, Type %s", fragment_id, fragmentTypeToString(fragtype).c_str()));
			histograms_[ind]->GetXaxis()->SetTitle("ADC value");
		}

		// For every event, fill the histogram (prescale is ignored here)

		// Is there some way to templatize an ART module? If not, we're
		// stuck with this switch code...

		switch (fragtype)
		{
			case FragmentType::TOY1:
			case FragmentType::TOY2:
				for (auto val = toyPtr->dataBeginADCs(); val != toyPtr->dataEndADCs(); ++val)
				{
					histograms_[ind]->Fill(*val);
				}
				break;

			default:
				TLOG(TLVL_ERROR) << "Error in WFViewer: unknown fragment type supplied";
				throw cet::exception("Error in WFViewer: unknown fragment type supplied");
		}

		if (((evt_cntr % prescale_ - 1) != 0u) && prescale_ > 1)
		{
			continue;
		}

		// If we pass the prescale, then if we're not going with
		// digital_sum_only, plot the ADC counts for this particular event/board/fragment_id

		if (!digital_sum_only_)
		{
			// Create the graph's x-axis

			if (x_.size() != total_adc_values)
			{
				x_.resize(total_adc_values);

				std::iota(x_.begin(), x_.end(), 0);
			}

			// If the graph doesn't exist, create it. Not sure whether to
			// make it an error if the total_adc_values is new

			if ((graphs_[ind] == nullptr) || static_cast<std::size_t>(graphs_[ind]->GetN()) != total_adc_values)
			{
				graphs_[ind] = new TGraph(total_adc_values);
				graphs_[ind]->SetName(Form("Fragment_%d_graph", fragment_id));
				graphs_[ind]->SetLineColor(4);
				std::copy(x_.begin(), x_.end(), graphs_[ind]->GetX());
			}

			// Get the data from the fragment

			// Is there some way to templatize an ART module? If not, we're stuck with this awkward switch code...

			switch (fragtype)
			{
				case FragmentType::TOY1:
				case FragmentType::TOY2:
				{
					std::copy(toyPtr->dataBeginADCs(), toyPtr->dataBeginADCs() + total_adc_values, graphs_[ind]->GetY());  // NOLINT(cppcoreguidelines-pro-bounds-pointer-arithmetic)
				}
				break;

				default:
					TLOG(TLVL_ERROR) << "Error in WFViewer: unknown fragment type supplied";
					throw cet::exception("Error in WFViewer: unknown fragment type supplied");  // NOLINT(cert-err60-cpp)
			}

			// And now prepare the graphics without actually drawing anything yet

			graph_canvas_->cd(ind + 1);
			auto* pad = static_cast<TVirtualPad*>(graph_canvas_->GetPad(ind + 1));

			Double_t lo_x, hi_x, lo_y, hi_y, dummy;

			graphs_[ind]->GetPoint(0, lo_x, dummy);
			graphs_[ind]->GetPoint(graphs_[ind]->GetN() - 1, hi_x, dummy);

			lo_x -= 0.5;
			hi_x += 0.5;

			lo_y = -0.5;
			hi_y = max_adc_count + 0.5;

			TH1F* padframe = static_cast<TH1F*>(pad->DrawFrame(lo_x, lo_y, hi_x, hi_y));
			padframe->SetTitle(Form("Frag %d, Type %s, SeqID %d", static_cast<int>(fragment_id),
			                        fragmentTypeToString(fragtype).c_str(),
			                        static_cast<int>(expected_sequence_id)));
			padframe->GetXaxis()->SetTitle("ADC #");
			pad->SetGrid();
			padframe->Draw("SAME");
		}

		// Draw the histogram

		histogram_canvas_->cd(ind + 1);
		histograms_[ind]->Draw();

		histogram_canvas_->Modified();
		histogram_canvas_->Update();

		// And, if desired, the Nth event's ADC counts

		if (!digital_sum_only_)
		{
			graph_canvas_->cd(ind + 1);

			graphs_[ind]->Draw("PSAME");

			graph_canvas_->Modified();
			graph_canvas_->Update();
		}

		if (writeOutput_)
		{
			histogram_canvas_->Write("wf0", TObject::kOverwrite);
			if (graph_canvas_ != nullptr)
			{
				graph_canvas_->Write("wf1", TObject::kOverwrite);
			}
			fFile_->Write();
		}
	}
}

void demo::WFViewer::beginRun(art::Run const& e)
{
	if (e.run() == current_run_)
	{
		return;
	}
	current_run_ = e.run();

	if (writeOutput_)
	{
		fFile_ = new TFile(outputFileName_.c_str(), "RECREATE");
		fFile_->cd();
	}

	for (auto& x : graphs_)
	{
		x = nullptr;
	}
	for (auto& x : histograms_)
	{
		x = nullptr;
	}

	{
		histogram_canvas_ = new TCanvas("wf0");
		histogram_canvas_->Divide(num_x_plots_, num_y_plots_);
		histogram_canvas_->Update();
		dynamic_cast<TRootCanvas*>(histogram_canvas_->GetCanvasImp())->DontCallClose();
		histogram_canvas_->SetTitle("ADC Value Distribution");
	}
	if (!digital_sum_only_)
	{
		graph_canvas_ = new TCanvas("wf1");
		graph_canvas_->Divide(num_x_plots_, num_y_plots_);
		graph_canvas_->Update();
		dynamic_cast<TRootCanvas*>(graph_canvas_->GetCanvasImp())->DontCallClose();
		graph_canvas_->SetTitle("ADC Values, Event Snapshot");
	}

	if (writeOutput_)
	{
		histogram_canvas_->Write();
		if (graph_canvas_ != nullptr)
		{
			graph_canvas_->Write();
		}
	}
}

DEFINE_ART_MODULE(demo::WFViewer)  // NOLINT(performance-unnecessary-value-param)
