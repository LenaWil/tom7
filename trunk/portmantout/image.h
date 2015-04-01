
#include <vector>
#include <cstdint>
#include <string>

#include "stb_image.h"
#include "stb_image_write.h"
#include "base/logging.h"

using namespace std;

using uint8 = uint8_t;

struct ImageRGBA {
  static ImageRGBA *Load(const string &filename) {
    vector<uint8> ret;
    int width, height, bpp_unused;
    uint8 *stb_rgba = stbi_load(filename.c_str(), 
				&width, &height, &bpp_unused, 4);
    const int bytes = width * height * 4;
    ret.resize(bytes);
    if (stb_rgba == nullptr) return nullptr;
    memcpy(ret.data(), stb_rgba, bytes);
    // Does this move image data all the way in, or do we need to
    // write a move constructor manually? Better way?
    return new ImageRGBA(std::move(ret), width, height);
  }

  ImageRGBA(int width, int height)
    : width(width), height(height), rgba(vector<uint8>(width * height * 4, 0)) {}

  ImageRGBA(const vector<uint8> &rgba, int width, int height) 
    : width(width), height(height), rgba(rgba) {
    CHECK(rgba.size() == width * height * 4);
  }

  // Assumes dest alpha channel is 0xFF.
  void BlendPixelf(int x, int y, float r, float g, float b, float alpha) {
    int idx = (width * y + x) * 4;
    CHECK(idx >= 0);
    CHECK(idx + 3 < rgba.size());
    float oma = 1.0f - alpha;
    float mult = oma / 255.0f;
    float newr = rgba[idx + 0] * mult + r * alpha;
    float newg = rgba[idx + 1] * mult + g * alpha;
    float newb = rgba[idx + 2] * mult + b * alpha;
    rgba[idx + 0] = newr * 255.0;
    rgba[idx + 1] = newg * 255.0;
    rgba[idx + 2] = newb * 255.0;
    rgba[idx + 3] = 0xFF;
  }

  // Blits, using alpha and clipping.
  void Blit(const ImageRGBA &src, int srcx, int srcy, int srcw, int srch,
	    int dstx, int dsty) {
    for (int sy = srcy, dy = dsty; sy < srcy + srch; sy++, dy++) {
      if (sy < src.height && sy >= 0 &&
	  dy < this->height && dy >= 0) {
	for (int sx = srcx, dx = dstx; sx < srcx + srcw; sx++, dx++) {
	  // PERF Clipping can be faster...
	  if (sx < src.width && sx >= 0 &&
	      dx < this->width && dx >= 0) {
	    int srcidx = (sy * src.width + sx) * 4;
	    int dstidx = (dy * this->width + dx) * 4;

	    CHECK(srcidx >= 0);
	    CHECK(srcidx + 3 < src.rgba.size());
	    CHECK(dstidx >= 0);
	    CHECK(dstidx + 3 < this->rgba.size());

	    float r = src.rgba[srcidx + 0] / 255.0f;
	    float g = src.rgba[srcidx + 1] / 255.0f;
	    float b = src.rgba[srcidx + 2] / 255.0f;
	    float alpha = src.rgba[srcidx + 3] / 255.0f;
	    float oma = 1.0f - alpha;
	    float mult = oma / 255.0f;
	    float newr = this->rgba[dstidx + 0] * mult + r * alpha;
	    float newg = this->rgba[dstidx + 1] * mult + g * alpha;
	    float newb = this->rgba[dstidx + 2] * mult + b * alpha;
	    this->rgba[dstidx + 0] = newr * 255.0;
	    this->rgba[dstidx + 1] = newg * 255.0;
	    this->rgba[dstidx + 2] = newb * 255.0;
	    this->rgba[dstidx + 3] = 0xFF;
	  }
	}
      }
    }
  }

  void Save(const string &filename) {
    CHECK(rgba.size() == width * height * 4);
    stbi_write_png(filename.c_str(), width, height, 4, rgba.data(), 4 * width);
  }

  ImageRGBA *Copy() const {
    return new ImageRGBA(rgba, width, height);
  }

  const int width, height;
  vector<uint8> rgba;
};
