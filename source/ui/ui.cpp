#include "ui/ui.h"

namespace folio {

void Ui::tap(const Rect& r, int action, const std::string& arg, int number) {
    if (sink_ != nullptr) {
        sink_(sinkCtx_, r, action, arg, number);
        return;
    }
    taps.push_back({r, action, arg, number});
}

const TapTarget* Ui::hitTest(float x, float y) const {
    for (auto it = taps.rbegin(); it != taps.rend(); ++it) {
        if (it->rect.contains(x, y)) return &*it;
    }
    return nullptr;
}

Canvas::TextStyle Ui::style(float size, const Color& color, bool bold) const {
    Canvas::TextStyle s;
    s.size = size;
    s.color = color;
    s.bold = bold;
    s.maxLines = 1;
    return s;
}

float Ui::text(const Rect& r, const std::string& str, float size, const Color& color, bool bold,
               Canvas::TextStyle* extra) {
    Canvas::TextStyle s = style(size, color, bold);
    if (extra != nullptr) s = *extra;
    return c_.drawText(r, str.c_str(), s);
}

float Ui::textLeft(const Rect& r, const std::string& s, float size, const Color& color, bool bold) {
    Canvas::TextStyle st = style(size, color, bold);
    st.align = Canvas::TextStyle::Left;
    st.valign = Canvas::TextStyle::Middle;
    return c_.drawText(r, s.c_str(), st);
}

float Ui::textCenter(const Rect& r, const std::string& s, float size, const Color& color, bool bold) {
    Canvas::TextStyle st = style(size, color, bold);
    st.align = Canvas::TextStyle::Center;
    st.valign = Canvas::TextStyle::Middle;
    return c_.drawText(r, s.c_str(), st);
}

float Ui::textRight(const Rect& r, const std::string& s, float size, const Color& color, bool bold) {
    Canvas::TextStyle st = style(size, color, bold);
    st.align = Canvas::TextStyle::Right;
    st.valign = Canvas::TextStyle::Middle;
    return c_.drawText(r, s.c_str(), st);
}

float Ui::measure(const std::string& s, float size, bool bold, float letterSpacing) {
    Canvas::TextStyle st = style(size, Color(0, 0, 0, 1), bold);
    st.letterSpacing = letterSpacing;
    return c_.measureWidth(s.c_str(), st);
}

Rect Ui::pillButton(const Rect& r, const std::string& label, float fontSize, const Color& bg,
                    const Color& fg, bool bold) {
    c_.fillRoundRect(r, r.h * 0.5f, bg);
    textCenter(r, label, fontSize, fg, bold);
    return r;
}

void Ui::card(const Rect& r, float radius, const Color& fill, const Color& border, float borderWidth,
              float shadowBlur, float shadowAlpha, float shadowDy) {
    if (shadowBlur > 0.f) {
        c_.shadowRoundRect(r, radius, shadowBlur, Color(0.f, 0.f, 0.f, shadowAlpha), shadowDy);
    }
    c_.fillRoundRect(r, radius, fill);
    if (borderWidth > 0.f) c_.strokeRoundRect(r, radius, borderWidth, border);
}

void Ui::beginScroll(const Rect& r, float scrollY) {
    (void)scrollY;
    c_.pushClip(r);
}

void Ui::endScroll() { c_.popClip(); }

}  // namespace folio