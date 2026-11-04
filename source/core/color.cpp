#include <cctype>

#include "core/math.h"

namespace folio {

namespace {

int hexVal(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

}  // namespace

Color parseColor(const char* hex, float alphaMul) {
    if (hex == nullptr || *hex == '\0') return Color(0.f, 0.f, 0.f, 0.f);
    if (*hex == '#') ++hex;
    int digits = 0;
    while (hex[digits] != '\0') ++digits;

    auto byte = [&](int index) {
        return (hexVal(hex[index]) * 16 + hexVal(hex[index + 1])) / 255.f;
    };

    if (digits == 8) {
        // ArkUI writes #AARRGGBB.
        const float a = byte(0);
        return Color(byte(2), byte(4), byte(6), a * alphaMul);
    }
    if (digits == 6) {
        return Color(byte(0), byte(2), byte(4), alphaMul);
    }
    if (digits == 3) {
        const float r = hexVal(hex[0]) / 15.f;
        const float g = hexVal(hex[1]) / 15.f;
        const float b = hexVal(hex[2]) / 15.f;
        return Color(r, g, b, alphaMul);
    }
    return Color(0.f, 0.f, 0.f, alphaMul);
}

float luminanceOf(const Color& c) {
    // Matches Index.ets subjectInk(): (r*299 + g*587 + b*114) / 1000 against 160.
    const float r = c.r * 255.f, g = c.g * 255.f, b = c.b * 255.f;
    return (r * 299.f + g * 587.f + b * 114.f) / 1000.f;
}

}  // namespace folio
