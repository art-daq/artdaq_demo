///////////////////////////////////////////////////////////////////////////////
// P.Murat: a 0-th order example of a DQM client using ROOT web-based graphics
//          cloned from  WFViewer_module.cc w/o much thought
//          the only purpose is to demonstrate the use of the web-based GUI
// - creates two canvases with the following URLs:
//   http://127.0.0.1:8877/win1/
//   http://127.0.0.1:8877/win2/
// key points: 
// - create a TApplication running in batch more and using a certain URL
// - call gSystem->ProcessEvents() once per event 
//
// for illustration only, save histograms once in the end of the run 
// (an online application has to do it periodically during the run)
///////////////////////////////////////////////////////////////////////////////
#include "TRACE/tracemf.h"
#define TRACE_NAME "DemoViewer"

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

#include <TApplication.h>
#include <TSystem.h>
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
#include <unordered_map>
#include <vector>

#include "tracemf.h"
#define TRACE_NAME "DemoViewer"

namespace demo {
/**
 * \brief An example art analysis module which plots events both as histograms and event snapshots (plot of ADC value vs ADC number)
 */
class DemoViewer : public art::EDAnalyzer {
public:
	/**
	 * \brief DemoViewer Constructor
	 * \param p ParameterSet used to configure DemoViewer
	 *
	 * \verbatim
	 * DemoViewer accepts the following Parameters:
	 * "prescale" (REQUIRED): DemoViewer will only redraw historgrams once per this many events
	 * "num_x_plots": (Default: size_t::MAX_VALUE): Maximum number of columns of plots
	 * "num_y_plots": (Default: size_t::MAX_VALUE): Maximum number of rows of plots
	 * "raw_data_label": (Default: "daq"): Label under which artdaq data is stored
	 * "fragment_ids": (REQUIRED): List of ids to process. Fragment IDs are assigned by BoardReaders.
	 * "fileName": (Default: artdaqdemo_onmon.root): File name for output, if
	 * "write_to_file": (Default: false): Whether to write output histograms to "fileName"
	 * \endverbatim
	 */
	explicit DemoViewer(fhicl::ParameterSet const& p);

	~DemoViewer() override;

	void analyze(art::Event const& e) override;

	void beginJob()                   override;
	void beginRun(art::Run const&  e) override;
	void endRun  (art::Run const&  e) override;

private:
	DemoViewer(DemoViewer const&) = delete;
	DemoViewer(DemoViewer&&) = delete;
	DemoViewer& operator=(DemoViewer const&) = delete;
	DemoViewer& operator=(DemoViewer&&) = delete;

	TCanvas*                  _hCanvas;
	TCanvas*                  _gCanvas;
	std::vector<Double_t>     x_;
	int                       prescale_;
	art::RunNumber_t          current_run_;

	size_t                    max_num_x_plots_;
	size_t                    max_num_y_plots_;
	std::size_t               num_x_plots_;
	std::size_t               num_y_plots_;

	std::string               raw_data_label_;

	std::unordered_map<artdaq::Fragment::fragment_id_t, TGraph*> graphs_;
	std::unordered_map<artdaq::Fragment::fragment_id_t, TH1D*> histograms_;

	std::map<artdaq::Fragment::fragment_id_t, std::size_t> id_to_index_;

	std::string    outputFileName_;
	TFile*         fFile_;
	bool           writeOutput_;
	bool           newCanvas_;
	bool           dynamicMode_;

	TApplication*  _app;


	void getXYDims_ ();
	void bookCanvas_();
};

  //-----------------------------------------------------------------------------
DemoViewer::DemoViewer(fhicl::ParameterSet const& ps)
    : art::EDAnalyzer  (ps)
    , prescale_        (ps.get<int>        ("prescale"))
    , current_run_     (0)
    , max_num_x_plots_ (ps.get<std::size_t>("num_x_plots", std::numeric_limits<std::size_t>::max()))
    , max_num_y_plots_ (ps.get<std::size_t>("num_y_plots", std::numeric_limits<std::size_t>::max()))
    , num_x_plots_     (0)
    , num_y_plots_     (0)
    , raw_data_label_  (ps.get<std::string>("raw_data_label", "daq"))
    , graphs_          ()
    , histograms_      ()
    , outputFileName_  (ps.get<std::string>("fileName", "artdaqdemo_onmon.root"))
    , writeOutput_     (ps.get<bool>       ("write_to_file", false))
    , newCanvas_       (true)
    , dynamicMode_     (ps.get<bool>       ("dynamic_mode", true))
{
	gStyle->SetOptStat("irm");
	gStyle->SetMarkerStyle(22);
	gStyle->SetMarkerColor(4);

	if (ps.has_key("fragment_ids")) {
		auto fragment_ids = ps.get<std::vector<artdaq::Fragment::fragment_id_t>>("fragment_ids");
		for (auto& id : fragment_ids) {
			auto index = id_to_index_.size();
			id_to_index_[id] = index;
		}
	}
}
  //-----------------------------------------------------------------------------
void DemoViewer::beginJob() {

  int           tmp_argc(2);
  char**        tmp_argv;

  tmp_argv    = new char*[2];
  tmp_argv[0] = new char[100];
  tmp_argv[1] = new char[100];

  strcpy(tmp_argv[0],"-b");
  strcpy(tmp_argv[1],"--web=server:8877");

  _app = new TApplication("DemoViewer", &tmp_argc, tmp_argv);

  // app->Run()
  // app_->Run(true);
  delete [] tmp_argv;
}

//-----------------------------------------------------------------------------
void DemoViewer::getXYDims_() {
	// Enforce positive maxes
	if (max_num_x_plots_ == 0) max_num_x_plots_ = std::numeric_limits<size_t>::max();
	if (max_num_y_plots_ == 0) max_num_y_plots_ = std::numeric_limits<size_t>::max();

	num_x_plots_ = num_y_plots_ = static_cast<std::size_t>(ceil(sqrt(id_to_index_.size())));

	// Do trivial check first to avoid multipling max * max -> undefined
	if (id_to_index_.size() > max_num_x_plots_ && id_to_index_.size() > max_num_x_plots_ * max_num_y_plots_) {
		num_x_plots_ = max_num_x_plots_;
		num_y_plots_ = max_num_y_plots_;
		auto max     = num_x_plots_ * num_y_plots_;
		auto it      = id_to_index_.begin();
		while (it != id_to_index_.end()) {
			if   (it->second >= max)  it = id_to_index_.erase(it); 
			else            				++it;
		}
	}

	// Some predefined "nice looking" plotscapes...

	if (max_num_x_plots_ >= 4 && max_num_y_plots_ >= 2)
	{
		switch (id_to_index_.size())
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
				break;
		}
	}
	else
	{
		// Make sure we fit within specifications
		while (num_x_plots_ > max_num_x_plots_)
		{
			num_x_plots_--;
			num_y_plots_ = static_cast<size_t>(ceil(id_to_index_.size() / num_x_plots_));
		}
	}
	TLOG(TLVL_DEBUG) << "id count: " << id_to_index_.size() << ", num_x_plots_: " << num_x_plots_ << " / " << max_num_x_plots_ << ", num_y_plots_: " << num_y_plots_ << " / " << max_num_y_plots_;
}

//-----------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------
void DemoViewer::bookCanvas_() {
	newCanvas_ = false;
	getXYDims_();

  _hCanvas = new TCanvas("wf0");
  _hCanvas->Divide(num_x_plots_, num_y_plots_);
  _hCanvas->SetTitle("ADC Value Distribution");
  _hCanvas->Update();

  _gCanvas = new TCanvas("wf1");
  _gCanvas->Divide(num_x_plots_, num_y_plots_);
  _gCanvas->SetTitle("ADC Values, Event Snapshot");
  _gCanvas->Update();
}

//-----------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------
DemoViewer::~DemoViewer() {
	// We're going to let ROOT's own garbage collection deal with histograms and Canvases...
	for (auto& histogram : histograms_) 	{
		histogram.second = nullptr;
	}
	histograms_.clear();
	for (auto& graph : graphs_) {
		graph.second = nullptr;
	}
	graphs_.clear();

	_hCanvas = nullptr;
	_gCanvas = nullptr;
	fFile_ = nullptr;
}


//-----------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------
void DemoViewer::analyze(art::Event const& e) {
	static std::size_t evt_cntr = -1;
	evt_cntr++;

	// John F., 1/22/14 -- there's probably a more elegant way of
	// collecting fragments of various types using ART interface code;
	// will investigate. Right now, we're actually re-creating the
	// fragments locally

	artdaq::Fragments    fragments;
	artdaq::FragmentPtrs containerFragments;

	std::vector<art::Handle<artdaq::Fragments>> fragmentHandles;
	fragmentHandles = e.getMany<std::vector<artdaq::Fragment>>();

	for (const auto& handle : fragmentHandles) 	{
		if (!handle.isValid() || handle->empty()) {
			continue;
		}

		if (handle->front().type() == artdaq::Fragment::ContainerFragmentType) {
			for (const auto& cont : *handle) {
				artdaq::ContainerFragment contf(cont);
        auto ftype = contf.fragment_type();
				if (ftype != FragmentType::TOY1 && ftype != FragmentType::TOY2) break;

				for (size_t ii = 0; ii < contf.block_count(); ++ii) 				{
					containerFragments.push_back(contf[ii]);
					fragments.push_back(*containerFragments.back());
					if (newCanvas_ && !id_to_index_.count(fragments.back().fragmentID())) 					{
						auto index = id_to_index_.size();
						id_to_index_[fragments.back().fragmentID()] = index;
					}
				}
			}
		}
		else {
			for (auto frag : *handle) 			{
				fragments.emplace_back(frag);
				if (newCanvas_ && !id_to_index_.count(fragments.back().fragmentID())) 				{
					auto index = id_to_index_.size();
					id_to_index_[fragments.back().fragmentID()] = index;
				}
			}
		}
	}

	if (newCanvas_) {
		bookCanvas_();
	}

	// John F., 1/5/14

	// Here, we loop over the fragments passed to the analyze
	// function. A warning is flashed if either (A) the fragments aren't
	// all from the same event, or (B) there's an unexpected number of
	// fragments given the number of boardreaders and the number of
	// fragments per board

	// For every Nth event, where N is the "prescale" setting, plot the
	// distribution of ADC counts from each board_id / fragment_id
	// combo. 
	// also , plot, for the Nth event, a graph of the ADC values
	// across all channels in each board_id / fragment_id combo

	artdaq::Fragment::sequence_id_t expected_sequence_id = std::numeric_limits<artdaq::Fragment::sequence_id_t>::max();

	for (const auto& frag : fragments) 	{
		std::unique_ptr<ToyFragment> toyPtr;

		if (expected_sequence_id == std::numeric_limits<artdaq::Fragment::sequence_id_t>::max()) {
			expected_sequence_id = frag.sequenceID(); 
		}

		if (expected_sequence_id != frag.sequenceID()) {
			TLOG(TLVL_WARNING) << "Warning in DemoViewer: expected fragment with sequence ID " << expected_sequence_id
			                   << ", received one with sequence ID " << frag.sequenceID();
		}

		auto fragtype                = static_cast<FragmentType>(frag.type());
		std::size_t max_adc_count    = std::numeric_limits<std::size_t>::max();
		std::size_t total_adc_values = std::numeric_limits<std::size_t>::max();

		switch (fragtype) {
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
      throw cet::exception("Error in DemoViewer: unknown fragment type supplied");
		}

		artdaq::Fragment::fragment_id_t fid = frag.fragmentID();
		if (id_to_index_.count(fid) == 0u) {
			TLOG(TLVL_WARNING) << "Warning in DemoViewer: unexpected Fragment with fragment id " << std::to_string(fid)
			                   << " encountered!";
			continue;
		}

		std::size_t ind = id_to_index_[fid];

		// If a histogram doesn't exist for this board_id / fragment_id combo, create it

		if (histograms_.count(fid) == 0 || histograms_[fid] == nullptr) {
			histograms_[fid] = new TH1D(Form("Fragment_%d_hist",fid),"",max_adc_count+1,-0.5,max_adc_count+0.5);
			histograms_[fid]->SetTitle(Form("Frag %d, Type %s",fid, fragmentTypeToString(fragtype).c_str()));
			histograms_[fid]->GetXaxis()->SetTitle("ADC value");

      _hCanvas->cd(ind + 1);
      histograms_[fid]->Draw();
		}

		switch (fragtype) {
			case FragmentType::TOY1:
			case FragmentType::TOY2:
				for (auto val = toyPtr->dataBeginADCs(); val != toyPtr->dataEndADCs(); ++val) {
					histograms_[fid]->Fill(*val);
				}
				break;

			default:
				TLOG(TLVL_ERROR) << "Error in DemoViewer: unknown fragment type supplied";
				throw cet::exception("Error in DemoViewer: unknown fragment type supplied");
		}

		if (((evt_cntr % prescale_ - 1) != 0u) && prescale_ > 1) continue;

                                        // Create the graph's x-axis

    if (x_.size() != total_adc_values) {
      x_.resize(total_adc_values);
      std::iota(x_.begin(), x_.end(), 0);
    }

			// If the graph doesn't exist, create it. Not sure whether to
			// make it an error if the total_adc_values is new

    if (graphs_.count(fid) == 0 || graphs_[fid] == nullptr ||
        static_cast<std::size_t>(graphs_[fid]->GetN()) != total_adc_values) {

      graphs_[fid] = new TGraph(total_adc_values);
      graphs_[fid]->SetName(Form("Fragment_%d_graph", fid));
      graphs_[fid]->SetLineColor(4);
      std::copy(x_.begin(), x_.end(), graphs_[fid]->GetX());
        
      _gCanvas->cd(ind + 1);
      graphs_[fid]->Draw("ALP");
    }

			// Get the data from the fragment
    switch (fragtype) {
    case FragmentType::TOY1:
    case FragmentType::TOY2: {
      std::copy(toyPtr->dataBeginADCs(), toyPtr->dataBeginADCs() + total_adc_values, graphs_[fid]->GetY()); 
    }
      break;

    default:
      TLOG(TLVL_ERROR)  << "Error in DemoViewer: unknown fragment type supplied";
      throw cet::exception("Error in DemoViewer: unknown fragment type supplied");  // NOLINT(cert-err60-cpp)
    }
  }

  gSystem->ProcessEvents(); 
}

//-----------------------------------------------------------------------------
void DemoViewer::beginRun(art::Run const& e) {
	if (e.run() == current_run_) return;
	current_run_ = e.run();

	_hCanvas = nullptr;
	_gCanvas = nullptr;
	for (auto& x : graphs_    ) x.second = nullptr;
	for (auto& x : histograms_) x.second = nullptr;

	newCanvas_ = true;
	if (!dynamicMode_) bookCanvas_();
}

//-----------------------------------------------------------------------------
void DemoViewer::endRun(art::Run const& e) {
	if (e.run() == current_run_) return;
	current_run_ = e.run();

  if (writeOutput_) {
		fFile_ = new TFile(outputFileName_.c_str(), "RECREATE");

    _hCanvas->Write("wf0", TObject::kOverwrite);
    if (_gCanvas != nullptr) {
      _gCanvas->Write("wf1", TObject::kOverwrite);
    }
    fFile_->Write();
  }
}

DEFINE_ART_MODULE(DemoViewer)  // NOLINT(performance-unnecessary-value-param)
}  // namespace demo
