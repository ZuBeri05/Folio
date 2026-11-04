#pragma once

#include <cmath>

#include "core/math.h"

namespace folio {

/** A value animated from/to with a curve; retargeting continues from where it is. */
class Anim {
public:
    enum class CurveKind { Cubic, Spring };

    Anim() = default;
    explicit Anim(float v) : from_(v), to_(v), value_(v) {}

    float value() const { return value_; }
    bool active() const { return active_; }

    /** Snaps without animating. */
    void set(float v);

    /** Starts a cubic-bezier transition. */
    void cubic(float target, float durationMs, float p1x, float p1y, float p2x, float p2y);
    /** Starts a spring transition; duration comes from the physics. */
    void spring(float target, float stiffness, float damping);

    /** Starts a transition with an optional delay, like animateTo({delay}). */
    void cubicDelayed(float target, float durationMs, float p1x, float p1y, float p2x, float p2y, float delayMs);

    /** Advances by dtMs and returns the new value. */
    float tick(float dtMs);

    /** Jump straight to the current target. */
    void snapToTarget() { value_ = to_; active_ = false; }

private:
    float from_ = 0.f;
    float to_ = 0.f;
    float value_ = 0.f;
    float elapsed_ = 0.f;
    float delay_ = 0.f;
    float duration_ = 0.f;
    float velocity_ = 0.f;
    bool active_ = false;
    bool springMode_ = false;
    float p1x_ = 0.f, p1y_ = 0.f, p2x_ = 0.f, p2y_ = 0.f;
    float stiffness_ = 180.f;
    float damping_ = 26.f;
};

/** Cubic bezier easing solver (Newton with bisection fallback), like CSS. */
float cubicBezier(float p1x, float p1y, float p2x, float p2y, float t);

/// The seven named curves from theme/Tokens.ets.
struct Curve {
    float p1x, p1y, p2x, p2y;
};

/** Decelerate: fast start, slow finish. Entering. */
extern const Curve kDecel;
/** Accelerate: slow start, fast exit. Leaving. */
extern const Curve kAccel;
/** Standard: same-screen transitions. */
extern const Curve kStandard;

// Spring presets from interpolatingSpring(0, 1, stiffness, damping).
constexpr float kSettleStiffness = 180.f;
constexpr float kSettleDamping = 26.f;
constexpr float kSnapStiffness = 420.f;
constexpr float kSnapDamping = 34.f;
constexpr float kBounceStiffness = 340.f;
constexpr float kBounceDamping = 20.f;

}  // namespace folio