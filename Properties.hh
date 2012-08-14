#ifndef ds50daq_Compression_Properties_hh
#define ds50daq_Compression_Properties_hh

/*
  domain is [-20,140] mV, range is [0,2^12] counts
  points are (-20,0) and (140,2^12)

  look up attributes and constexpr in C++11 as a better way to do this
*/

#include "ds50daq/DAQ/DS50Types.hh"

extern "C" {
#include <stdint.h>
}

#include <vector>

#if defined(__GCCXML__) || !defined(__GXX_EXPERIMENTAL_CXX0X__)
#define Constexpr /**/
#else
#define Constexpr constexpr
#endif

namespace ds50 {
  Constexpr uint64_t reg_size_bits = (sizeof(reg_type) * 8);
  Constexpr uint64_t chunk_size_bytes = 1 << 16;
  Constexpr uint64_t chunk_size_counts = chunk_size_bytes / sizeof(adc_type);
  Constexpr uint64_t chunk_size_regs = chunk_size_bytes / sizeof(reg_type);

  size_t bitCountToBytes(reg_type bits);

  template <size_t N> struct Properties_t;

  typedef Properties_t<12> Properties;
}

inline size_t ds50::bitCountToBytes(reg_type bits)
{
  return (bits / reg_size_bits + ((bits % reg_size_bits) == 0 ? 0 : 1)) * sizeof(reg_type);
}

template <size_t N>
struct ds50::Properties_t {
  Constexpr static adc_type count_max() { return 1 << N; }
  Constexpr static adc_type count_min() { return 0; }

  Constexpr static double signal_low() { return -20.; }
  Constexpr static double signal_high() { return 140.; }
  Constexpr static double adc_low() { return count_min(); }
  Constexpr static double adc_high() { return (double)(count_max()); }

  Constexpr static double m() { return (adc_high() - adc_low()) / (signal_high() - signal_low()); }
  Constexpr static double b() { return -signal_low() * m(); }

  static adc_type signalToADC(double sig) {
    double x = sig < signal_low() ? signal_low() : sig > signal_high() ? signal_high() : sig;
    return (adc_type)(m() * x + b());
  }

  static double ADCToSignal(adc_type counts) {
    return ((double)counts - b()) / m();
  }

};

#if defined(__GCCXML__) || !defined(__GXX_EXPERIMENTAL_CXX0X__)
#undef Constexpr
#endif

#endif /* ds50daq_Compression_Properties_hh */
