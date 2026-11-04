#pragma once

#include <string>

#include "core/math.h"

namespace folio {

namespace tokens {
extern const char* const bg;
extern const char* const surface;
extern const char* const surfaceSoft;
extern const char* const ink;
extern const char* const inkSoft;
extern const char* const muted;
extern const char* const mutedSoft;
extern const char* const line;
extern const char* const lineStrong;
extern const char* const yellow;
extern const char* const yellowSoft;
extern const char* const orange;
extern const char* const coral;
extern const char* const blue;
extern const char* const pink;
extern const char* const shadow;
extern const char* const dim;
extern const char* const white;

Color color(const char* hex, float alphaMul = 1.f);
}  // namespace tokens

/**
 * Motion tokens, copied verbatim from theme/Tokens.ets: five durations and
 * seven curves. Nothing in the UI hard-codes a duration of its own.
 */
struct Motion {
    static constexpr float instant = 110.f;
    static constexpr float quick = 170.f;
    static constexpr float base = 260.f;
    static constexpr float slow = 380.f;
    static constexpr float page = 520.f;

    /** Screen-width scaling used for travel distances (phone 0.55, tablet ~1). */
    static float scale(float width);
    /** Travel distance, scaled by screen width. */
    static float travel(float base, float width);
    /** Duration in ms, shortened for short travel. */
    static float time(float base, float width);
};

}  // namespace folio
