// Frame entry: wire the tap sink, advance animations, draw, dispatch input.
#include "platform/platform.h"
#include "ui/app.h"

namespace folio {

namespace {

void tapSink(void* ctx, const Rect& r, int action, const std::string& arg, int number) {
    static_cast<App*>(ctx)->recordTap(r, action, arg, number);
}

}  // namespace

void App::frame(Canvas& canvas, Ui& ui, float dtMs, const TouchSample& touch, float widthVp, float heightVp) {
    vpWidth_ = widthVp;
    vpHeight_ = heightVp;
    // Same breakpoint as the original: split layout at >=840vp and landscape.
    isWide_ = widthVp >= 840.f && widthVp > heightVp * 1.05f;
    isTablet_ = widthVp >= 700.f;

    advance(dtMs);
    canvas.setScale(canvas.target() != nullptr ? static_cast<float>(canvas.target()->w) / widthVp : 1.f);

    clockSeconds_ += dtMs / 1000.f;
    canvas.setTime(clockSeconds_);
    canvas.resetClip();
    taps_.clear();
    ui.clearTaps();
    ui.setTapSink(&tapSink, this);
    draw(canvas, ui);
    ui.setTapSink(nullptr, nullptr);

    // Dispatch on a fresh touch-down only, so a finger resting on a button does
    // not repeat the action every frame.
    const bool freshTap = touch.active && !wasTouching_;
    wasTouching_ = touch.active;
    if (freshTap) {
        dispatchTap(touch.x, touch.y);
    }
}

void App::setKeyboardResult(bool ok, const std::string& text) {
    if (!ok) return;
    (void)text;
}

}  // namespace folio