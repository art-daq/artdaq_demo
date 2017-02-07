#ifndef artdaq_demo_Generators_ToyHardwareInterface_ToyHardwareInterface_hh
#define artdaq_demo_Generators_ToyHardwareInterface_ToyHardwareInterface_hh

// JCF, Mar-17-2016

// ToyHardwareInterface is meant to mimic a vendor-provided hardware
// API, usable within the the ToySimulator fragment generator. For
// purposes of realism, it's a C++03-style API, as opposed to, say,
// one based in C++11 capable of taking advantage of smart pointers,
// etc. An important point to make is that it has ownership of the
// buffer into which it dumps its data - so rather than use
// new/delete, use its functions
// AllocateReadoutBuffer/FreeReadoutBuffer

// The data it returns are ADC counts distributed according to the
// uniform distribution

#include "artdaq-core-demo/Overlays/FragmentType.hh"

#include "fhiclcpp/fwd.h"

#include <random>
#include <chrono>

class ToyHardwareInterface {

public:

  typedef uint16_t data_t;

  ToyHardwareInterface(fhicl::ParameterSet const & ps);

  void StartDatataking();
  void StopDatataking();
  void FillBuffer(char* buffer, size_t* bytes_read);

  void AllocateReadoutBuffer(char** buffer);
  void FreeReadoutBuffer(char* buffer);

  int SerialNumber() const;
  int NumADCBits() const;
  int BoardType() const;

  enum class DistributionType { uniform, gaussian, monotonic, uninitialized };

private:

  bool taking_data_;

  std::size_t nADCcounts_;
  std::size_t maxADCcounts_;
  std::size_t change_after_N_seconds_;
  int nADCcounts_after_N_seconds_; 
  bool exception_after_N_seconds_;
  bool exit_after_N_seconds_;
  bool abort_after_N_seconds_;
  demo::FragmentType fragment_type_;
  std::size_t maxADCvalue_;
  std::size_t throttle_usecs_;
  std::size_t usecs_between_sends_;
  DistributionType distribution_type_;

  using time_type = decltype(std::chrono::high_resolution_clock::now());

  const time_type fake_time_ = std::numeric_limits<time_type>::max();  

// Members needed to generate the simulated data

  std::mt19937 engine_;
  std::unique_ptr<std::uniform_int_distribution<data_t>> uniform_distn_;
  std::unique_ptr<std::normal_distribution<double>> gaussian_distn_;
  
  time_type start_time_;
  int send_calls_;
};



#endif
