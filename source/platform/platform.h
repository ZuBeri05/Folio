// Thin wrapper over libnx: framebuffer, touch + pad input, clock, keyboard.
#pragma once

#include <string>

#include "core/canvas.h"
#include "core/math.h"

namespace folio {

/**
 * Logical design width in vp.
 *
 * The original tablet layout is tuned around 1200x800vp. The Switch panel is a
 * fixed 1280x720 (16:9, shorter than any tablet), so the UI is drawn at 1024vp
 * wide: every vp becomes 1.25 physical pixels, which lifts the original's 11.5vp
 * body text to ~14px on a 720p screen and leaves 576vp of height — just enough
 * for the composer pane to fit without clipping.
 */
constexpr float kLogicalWidth = 1024.f;

struct TouchPoint {
    bool active = false;
    float x = 0.f;  // vp
    float y = 0.f;  // vp
};

enum class PadKey { None, A, B, X, Y, Plus, Minus, L, R, ZL, ZR, Up, Down, Left, Right };

struct FrameInfo {
    float dtMs = 16.f;
    float widthVp = kLogicalWidth;
    float heightVp = 540.f;
};

class Platform {
public:
    bool init();
    void shutdown();

    /** Presents a finished RGBA8 frame. */
    void present();
    /** Pumps input and returns timing for this frame. */
    FrameInfo beginFrame();

    /** Touch sample in vp for this frame. */
    const TouchPoint& touch() const { return touch_; }
    /** True on the frame the button goes down. */
    bool pressed(PadKey key) const;
    /** True while the button is held. */
    bool held(PadKey key) const;

    static long long nowMs();

    /** Opens the system keyboard; returns false when cancelled. */
    bool requestText(const char* guide, const char* initial, std::string& out);

    bool shouldExit() const { return exitRequested_; }
    void requestExit() { exitRequested_ = true; }

    /** Physical pixels per vp. */
    float scale() const { return scale_; }
    int pixelWidth() const { return pixelWidth_; }
    int pixelHeight() const { return pixelHeight_; }

private:
    bool exitRequested_ = false;
    float scale_ = 1.f;
    int pixelWidth_ = 1280;
    int pixelHeight_ = 720;
    unsigned long long lastTick_ = 0;
    TouchPoint touch_;
    unsigned long long buttons_ = 0;
    unsigned long long buttonsPrev_ = 0;
};

Platform& platform();

/** Points the presenter at the software framebuffer being drawn into. */
void platformSetFrameBitmap(Bitmap* bitmap);

}  // namespace folio