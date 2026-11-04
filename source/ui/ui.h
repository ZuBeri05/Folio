// Small immediate-mode helpers on top of Canvas: text styles from the ArkUI
// tokens, tappable regions, scroll containers and the shared button shapes.
#pragma once

#include <functional>
#include <string>
#include <vector>

#include "core/canvas.h"
#include "core/font.h"
#include "ui/theme.h"

namespace folio {

struct TapTarget {
    Rect rect;
    int action = 0;
    std::string arg;
    int number = 0;
};

class Ui {
public:
    Ui(Canvas& canvas, FontBook& fonts) : c_(canvas), fonts_(fonts) {}

    Canvas& canvas() { return c_; }

    /** Registers a tap region; later registrations win because they draw on top. */
    void tap(const Rect& r, int action, const std::string& arg = std::string(), int number = 0);

    /** Topmost tap target containing the point, or nullptr. */
    const TapTarget* hitTest(float x, float y) const;

    /** Text helpers that mirror the ArkUI fontSize/fontWeight usage. */
    Canvas::TextStyle style(float size, const Color& color, bool bold = false) const;
    float text(const Rect& r, const std::string& s, float size, const Color& color, bool bold = false,
               Canvas::TextStyle* extra = nullptr);
    float textLeft(const Rect& r, const std::string& s, float size, const Color& color, bool bold = false);
    float textCenter(const Rect& r, const std::string& s, float size, const Color& color, bool bold = false);
    float textRight(const Rect& r, const std::string& s, float size, const Color& color, bool bold = false);
    float measure(const std::string& s, float size, bool bold = false, float letterSpacing = 0.f);

    /** Filled pill button; returns its rect. */
    Rect pillButton(const Rect& r, const std::string& label, float fontSize, const Color& bg,
                    const Color& fg, bool bold);
    /** Rounded rect card with the app's surface color and hairline border. */
    void card(const Rect& r, float radius, const Color& fill, const Color& border, float borderWidth,
              float shadowBlur, float shadowAlpha, float shadowDy);

    /** Clips drawing to r and returns an origin for scrolled content. */
    void beginScroll(const Rect& r, float scrollY);
    void endScroll();

    void pushClip(const Rect& r) { c_.pushClip(r); }
    void popClip() { c_.popClip(); }

    FontBook& fonts() { return fonts_; }

    /** Callback so recorded taps land in the App's list in draw order. */
    using TapSink = void (*)(void* ctx, const Rect& r, int action, const std::string& arg, int number);
    void setTapSink(TapSink sink, void* ctx) {
        sink_ = sink;
        sinkCtx_ = ctx;
    }

    std::vector<TapTarget> taps;

    TapSink sink_ = nullptr;
    void* sinkCtx_ = nullptr;
    void clearTaps() { taps.clear(); }

private:
    Canvas& c_;
    FontBook& fonts_;
};

}  // namespace folio