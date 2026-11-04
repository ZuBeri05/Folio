#include "ui/anim.h"

#include <algorithm>

namespace folio {

const Curve kDecel{0.05f, 0.7f, 0.1f, 1.f};
const Curve kAccel{0.3f, 0.f, 1.f, 1.f};
const Curve kStandard{0.2f, 0.f, 0.f, 1.f};

namespace {

float bezierAxis(float t, float p1, float p2) {
    const float u = 1.f - t;
    return 3.f * u * u * t * p1 + 3.f * u * t * t * p2 + t * t * t;
}

float bezierSlope(float t, float p1, float p2) {
    const float u = 1.f - t;
    return 3.f * u * u * p1 + 6.f * u * t * (p2 - p1) + 3.f * t * t * (1.f - p2);
}

}  // namespace

float cubicBezier(float p1x, float p1y, float p2x, float p2y, float t) {
    if (t <= 0.f) return 0.f;
    if (t >= 1.f) return 1.f;
    // Solve for the parameter u where bezierX(u) == t.
    float u = t;
    for (int i = 0; i < 8; ++i) {
        const float x = bezierAxis(u, p1x, p2x) - t;
        if (std::fabs(x) < 1e-5f) break;
        const float d = bezierSlope(u, p1x, p2x);
        if (std::fabs(d) < 1e-6f) break;
        u -= x / d;
        u = std::max(0.f, std::min(1.f, u));
    }
    return bezierAxis(u, p1y, p2y);
}

void Anim::set(float v) {
    value_ = from_ = to_ = v;
    active_ = false;
    delay_ = 0.f;
    elapsed_ = 0.f;
    velocity_ = 0.f;
}

void Anim::cubic(float target, float durationMs, float p1x, float p1y, float p2x, float p2y) {
    cubicDelayed(target, durationMs, p1x, p1y, p2x, p2y, 0.f);
}

void Anim::cubicDelayed(float target, float durationMs, float p1x, float p1y, float p2x, float p2y,
                        float delayMs) {
    if (target == to_ && active_) return;
    if (target == value_ && delayMs <= 0.f) {
        to_ = target;
        active_ = false;
        return;
    }
    from_ = value_;
    to_ = target;
    duration_ = durationMs > 0.f ? durationMs : 1.f;
    p1x_ = p1x;
    p1y_ = p1y;
    p2x_ = p2x;
    p2y_ = p2y;
    elapsed_ = 0.f;
    delay_ = delayMs;
    springMode_ = false;
    active_ = true;
}

void Anim::spring(float target, float stiffness, float damping) {
    if (target == to_ && active_) return;
    from_ = value_;
    to_ = target;
    stiffness_ = stiffness;
    damping_ = damping;
    elapsed_ = 0.f;
    delay_ = 0.f;
    springMode_ = true;
    active_ = true;
    velocity_ = 0.f;
}

float Anim::tick(float dtMs) {
    if (!active_) return value_;
    if (delay_ > 0.f) {
        delay_ -= dtMs;
        if (delay_ > 0.f) return value_;
        dtMs = -delay_;
        delay_ = 0.f;
    }
    if (springMode_) {
        // Critically-underdamped spring integrated semi-implicitly at 240Hz.
        const int steps = std::max(1, static_cast<int>(std::ceil(dtMs / 4.f)));
        const float h = dtMs / steps;
        for (int i = 0; i < steps; ++i) {
            const float force = -stiffness_ * (value_ - to_) - damping_ * velocity_;
            velocity_ += force * 0.001f * h;
            value_ += velocity_ * 0.001f * h;
        }
        if (std::fabs(value_ - to_) < 0.0006f && std::fabs(velocity_) < 0.02f) {
            value_ = to_;
            active_ = false;
        }
        return value_;
    }
    elapsed_ += dtMs;
    const float t = std::min(1.f, elapsed_ / duration_);
    value_ = from_ + (to_ - from_) * cubicBezier(p1x_, p1y_, p2x_, p2y_, t);
    if (t >= 1.f) {
        value_ = to_;
        active_ = false;
    }
    return value_;
}

}  // namespace folio