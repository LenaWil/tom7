
#ifndef __WAVESAVE_H
#define __WAVESAVE_H

#include <string>
#include <vector>
#include <utility>

struct WaveSave {

  static bool SaveStereo(const std::string &filename,
                         const std::vector<std::pair<float, float>> &samples,
                         int samples_per_sec);

};

#endif
