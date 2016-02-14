#ifndef __MATRICES_H
#define __MATRICES_H

// Some basic matrix/vector math. Probably dead code (might even have
// bugs since I was getting weird results when I abandoned this
// approach).

struct Mat33 {
  Mat33(float a, float b, float c,
	float d, float e, float f,
	float g, float h, float i) :
    a(a), b(b), c(c),
    d(d), e(e), f(f),
    g(g), h(h), i(i) {}
  
  float
    a = 0.0f, b = 0.0f, c = 0.0f,
    d = 0.0f, e = 0.0f, f = 0.0f,
    g = 0.0f, h = 0.0f, i = 0.0f;
};

inline Mat33 Mul33(const Mat33 &m, const Mat33 &n) {
  return Mat33(
      m.a*n.a + m.b*n.d + m.c*n.g, m.a*n.b + m.b*n.e + m.c*n.h, m.a*n.c + m.b*n.f + m.c*n.i,
      m.d*n.a + m.e*n.d + m.f*n.g, m.d*n.b + m.e*n.e + m.f*n.h, m.d*n.c + m.e*n.f + m.f*n.i,
      m.g*n.a + m.h*n.d + m.i*n.g, m.g*n.b + m.h*n.e + m.i*n.h, m.g*n.c + m.h*n.f + m.i*n.i);
}

inline Mat33 RotYaw(float a) {
  const float cosa = cosf(a);
  const float sina = sinf(a);
  return Mat33(cosa, -sina, 0.0f,
	       sina, cosa,  0.0f,
	       0.0f, 0.0f,  1.0f);
}

inline Mat33 RotPitch(float a) {
  const float cosa = cosf(a);
  const float sina = sinf(a);
  return Mat33(cosa,  0.0f, sina,
	       0.0f,  1.0f, 0.0f,
	       -sina, 0.0f, cosa);
}

inline Mat33 RotRoll(float a) {
  const float cosa = cosf(a);
  const float sina = sinf(a);
  return Mat33(1.0f, 0.0f, 0.0f,
	       0.0f, cosa, -sina,
	       0.0f, sina, cosa);
}

struct Vec3 {
  Vec3(float x, float y, float z) : x(x), y(y), z(z) {}
  const float *Floats() const { return (float*)this; }
  float x = 0.0f, y = 0.0f, z = 0.0f;
};
static_assert(sizeof (Vec3) == 3 * sizeof (float), "packing");

struct Vec2 {
  Vec2(float x, float y) : x(x), y(y) {}
  const float *Floats() const { return (float*)this; }
  float x = 0.0f, y = 0.0f;
};
static_assert(sizeof (Vec2) == 2 * sizeof (float), "packing");

inline Vec3 Mat33TimesVec3(const Mat33 &m, const Vec3 &v) {
  return Vec3(m.a * v.x + m.b * v.y + m.c * v.z,
              m.d * v.x + m.e * v.y + m.f * v.z,
              m.g * v.x + m.h * v.y + m.i * v.z);
}

inline Vec3 Vec3Minus(const Vec3 &a, const Vec3 &b) {
  return Vec3(a.x - b.x, a.y - b.y, a.z - b.z);
}

inline Vec3 Vec3Plus(const Vec3 &a, const Vec3 &b) {
  return Vec3(a.x + b.x, a.y + b.y, a.z + b.z);
}

inline Vec2 Vec2Plus(const Vec2 &a, const Vec2 &b) {
  return Vec2(a.x + b.x, a.y + b.y);
}

inline Vec3 ScaleVec3(const Vec3 &v, float s) {
  return Vec3(v.x * s, v.y * s, v.x * s);
}

inline Vec2 ScaleVec2(const Vec2 &v, float s) {
  return Vec2(v.x * s, v.y * s);
}

// d is the point, e is the eye
inline Vec2 Project2D(const Vec3 &d, const Vec3 &e) {
  const float f = e.z / d.z;
  return Vec2(f * d.x - e.x, f * d.y - e.y);
}

inline bool InfiniteVec2(const Vec2 &a) {
  return isinf(a.x) || isinf(a.y);
}

#endif
