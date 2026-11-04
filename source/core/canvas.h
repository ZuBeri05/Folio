// Software rasterizer: anti-aliased rounded rectangles, circles, shadows and
// blurs. Everything the UI draws goes through here so the look matches the
// ArkUI original closely without a GPU pipeline.

#pragma once

#include <vector>

#include "core/math.h"
#include "gen/icons.h"

namespace folio {

class FontBook;

struct Bitmap {
    int w = 0;
    int h = 0;
    std::vector<uint8_t> px;  // RGBA8, straight alpha

    void resize(int width, int height);
    uint8_t* at(int x, int y) { return &px[(static_cast<size_t>(y) * w + x) * 4]; }
    const uint8_t* at(int x, int y) const { return &px[(static_cast<size_t>(y) * w + x) * 4]; }
};

class Canvas {
public:
    Canvas() = default;

    void attach(Bitmap* target) { target_ = target; }
    void setFontBook(FontBook* book) { fonts_ = book; }

    /**
     * Logical (vp) to physical (px) scale. All drawing helpers take vp units so
     * the UI can be laid out with the same numbers as the ArkUI original.
     */
    void setScale(float s) { scale_ = s > 0.f ? s : 1.f; }
    float scale() const { return scale_; }

    Bitmap* target() { return target_; }
    int width() const { return target_ ? target_->w : 0; }
    int height() const { return target_ ? target_->h : 0; }
    /** Visible area in vp (layout units). */
    Rect bounds() const {
        return Rect(0.f, 0.f, static_cast<float>(width()) / scale_, static_cast<float>(height()) / scale_);
    }
    /** Visible area in physical pixels, for the rasterizer's own clipping. */
    Rect pixelBounds() const {
        return Rect(0.f, 0.f, static_cast<float>(width()), static_cast<float>(height()));
    }

    void clear(const Color& c);

    void fillRoundRect(const Rect& r, float radius, const Color& c);
    void strokeRoundRect(const Rect& r, float radius, float width, const Color& c);
    void fillRect(const Rect& r, const Color& c) { fillRoundRect(r, 0.f, c); }
    void fillCircle(float cx, float cy, float radius, const Color& c);
    void strokeCircle(float cx, float cy, float radius, float width, const Color& c);
    /** Ring stroke; angles in radians measured clockwise from 12 o'clock. */
    void strokeArc(float cx, float cy, float radius, float width, float fromAngle, float toAngle,
                   const Color& c, float alpha = 1.f);
    void shadowRoundRect(const Rect& r, float radius, float blur, const Color& c, float dy);

    /** Polyline stroke with round caps/joins; points are in icon space (0..viewSize). */
    void strokePolyline(const struct PolyPoint* points, int count, const Rect& box, float viewSize,
                        float strokeWidth, const Color& c);
    /** Filled polygon set (even-odd) mapped into box. */
    void fillPolygons(const struct PolyPoint* points, int count, const Rect& box, float viewSize,
                      const Color& c);
    /** Separable box blur of what is already drawn (backdropBlur). */
    void blurRoundRect(const Rect& r, float radius, float blurVp);

    void pushClip(const Rect& r);
    void popClip();
    /** Clears leftover clip state (called once per frame). */
    void resetClip();
    Rect clip() const;
    int clipDepth() const { return static_cast<int>(clipStack_.size()); }

    void pushAlpha(float a);
    void popAlpha();
    float alpha() const { return alpha_; }

    struct TextStyle {
        float size = 14.f;  // vp
        Color color;
        bool bold = false;
        float letterSpacing = 0.f;  // vp
        int maxLines = 1;
        bool wrap = false;
        float lineHeight = 0.f;  // vp; 0 = derived from the font
        /** Scroll long single-line text instead of clipping it. */
        bool marquee = false;
        enum Align { Left, Center, Right } align = Left;
        enum VAlign { Top, Middle, Bottom } valign = Top;
    };

    /** Seconds since the app started; drives the marquee scroll. */
    void setTime(float seconds) { time_ = seconds; }

    float drawText(const Rect& r, const char* utf8, const TextStyle& style);
    float measureText(float maxWidth, const char* utf8, const TextStyle& style);
    /** Advance width of a single line, no wrapping. */
    float measureWidth(const char* utf8, const TextStyle& style);

private:
    friend struct CanvasText;
    void blendPixel(int x, int y, const Color& c, float coverage);
    void blendSpan(int y, float x0, float x1, const Color& c, float coverage);

    Bitmap* target_ = nullptr;
    FontBook* fonts_ = nullptr;
    float scale_ = 1.f;
    Rect clip_;
    std::vector<Rect> clipStack_;
    float alpha_ = 1.f;
    float time_ = 0.f;
    std::vector<float> alphaStack_;
};

}  // namespace folio