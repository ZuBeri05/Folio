// Small vector/color helpers shared by the renderer and the UI layer.
#pragma once

#include <math.h>
#include <stdint.h>

namespace folio {

constexpr float kPi = 3.14159265358979323846f;

struct Vec2 {
    float x = 0.f;
    float y = 0.f;

    Vec2() = default;
    Vec2(float ax, float ay) : x(ax), y(ay) {}
};

struct Rect {
    float x = 0.f;
    float y = 0.f;
    float w = 0.f;
    float h = 0.f;

    Rect() = default;
    Rect(float ax, float ay, float aw, float ah) : x(ax), y(ay), w(aw), h(ah) {}

    float right() const { return x + w; }
    float bottom() const { return y + h; }
    Vec2 center() const { return Vec2(x + w * 0.5f, y + h * 0.5f); }
    bool empty() const { return w <= 0.f || h <= 0.f; }

    Rect inset(float d) const { return Rect(x + d, y + d, w - d * 2.f, h - d * 2.f); }
    Rect inset(float dx, float dy) const { return Rect(x + dx, y + dy, w - dx * 2.f, h - dy * 2.f); }
    bool contains(float px, float py) const {
        return px >= x && py >= y && px < x + w && py < y + h;
    }
    Rect intersect(const Rect& o) const {
        const float l = x > o.x ? x : o.x;
        const float t = y > o.y ? y : o.y;
        const float r = right() < o.right() ? right() : o.right();
        const float b = bottom() < o.bottom() ? bottom() : o.bottom();
        return Rect(l, t, r - l > 0.f ? r - l : 0.f, b - t > 0.f ? b - t : 0.f);
    }
};

inline float clampf(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }
inline float lerpf(float a, float b, float t) { return a + (b - a) * t; }
inline float minf(float a, float b) { return a < b ? a : b; }
inline float maxf(float a, float b) { return a > b ? a : b; }

inline uint8_t toByte(float v) {
    const float s = v * 255.f + 0.5f;
    if (s <= 0.f) return 0;
    if (s >= 255.f) return 255;
    return static_cast<uint8_t>(s);
}

/** Straight (non-premultiplied) RGBA color in 0..1. */
struct Color {
    float r = 0.f;
    float g = 0.f;
    float b = 0.f;
    float a = 1.f;

    Color() = default;
    Color(float ar, float ag, float ab, float aa = 1.f) : r(ar), g(ag), b(ab), a(aa) {}

    static Color rgb(int r, int g, int b, float a = 1.f) {
        return Color(r / 255.f, g / 255.f, b / 255.f, a);
    }

    Color withAlpha(float alpha) const { return Color(r, g, b, a * alpha); }
    Color scaleAlpha(float f) const { return Color(r, g, b, a * f); }
};

/** Parses #RGB, #RRGGBB or #AARRGGBB (ArkUI writes alpha first). */
Color parseColor(const char* hex, float alphaMul = 1.f);

inline Color mixColor(const Color& a, const Color& b, float t) {
    return Color(lerpf(a.r, b.r, t), lerpf(a.g, b.g, t), lerpf(a.b, b.b, t), lerpf(a.a, b.a, t));
}

/** RGB (0..255 each) -> perceived brightness, matching ArkUI's subjectInk() threshold. */
float luminanceOf(const Color& c);

}  // namespace folio
