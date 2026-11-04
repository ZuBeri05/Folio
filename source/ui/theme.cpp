#include "ui/theme.h"

#include <algorithm>

namespace folio {

namespace tokens {

const char* const bg = "#F7F2E4";
const char* const surface = "#D9FFFDF8";
const char* const surfaceSoft = "#B3FFFDF8";
const char* const ink = "#2C251D";
const char* const inkSoft = "#4B4032";
const char* const muted = "#8D7F6C";
const char* const mutedSoft = "#B2A48F";
const char* const line = "#1A5E4B30";
const char* const lineStrong = "#2B5E4B30";
const char* const yellow = "#FFC531";
const char* const yellowSoft = "#FFF3C9";
const char* const orange = "#FF8A2A";
const char* const coral = "#FF6542";
const char* const blue = "#7E9FB5";
const char* const pink = "#D98F87";
const char* const shadow = "#14000000";
const char* const dim = "#660B0806";
const char* const white = "#FFFFFF";

Color color(const char* hex, float alphaMul) { return parseColor(hex, alphaMul); }

}  // namespace tokens

float Motion::scale(float width) {
    if (!(width > 0.f)) return 1.f;
    const float s = width / 1000.f;
    return std::max(0.55f, std::min(1.15f, s));
}

float Motion::travel(float baseV, float width) {
    const float v = baseV * scale(width);
    return std::round(v * 10.f) / 10.f;
}

float Motion::time(float baseV, float width) {
    const float k = 0.86f + 0.24f * scale(width);
    return std::round(baseV * k);
}

}  // namespace folio
