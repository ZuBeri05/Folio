// Text layout and glyph blitting, kept apart from shape rasterization.
#include <cmath>
#include <cstring>
#include <vector>

#include "core/canvas.h"
#include "core/font.h"

namespace folio {

namespace {

struct CharRun {
    uint32_t cp;
    float width;  // px
};

bool isWideScript(uint32_t cp) {
    return (cp >= 0x2E80 && cp <= 0x9FFF) || (cp >= 0xAC00 && cp <= 0xD7A3) ||
           (cp >= 0xF900 && cp <= 0xFAFF) || (cp >= 0xFF00 && cp <= 0xFF60);
}

std::vector<CharRun> decode(const char* utf8, FontFace& face, float pixelSize, float spacingPx) {
    std::vector<CharRun> out;
    const char* s = utf8;
    const char* end = utf8 + std::strlen(utf8);
    while (s < end) {
        const uint32_t cp = utf8Next(s, end);
        if (cp == 0) break;
        out.push_back({cp, face.advance(cp, pixelSize) + spacingPx});
    }
    return out;
}

struct Line {
    size_t first = 0;
    size_t last = 0;
    float width = 0.f;
};

std::vector<Line> breakLines(const std::vector<CharRun>& chars, float maxWidth) {
    std::vector<Line> lines;
    Line cur;
    float w = 0.f;
    for (size_t i = 0; i < chars.size(); ++i) {
        const uint32_t cp = chars[i].cp;
        if (cp == '\n') {
            cur.last = i;
            cur.width = w;
            lines.push_back(cur);
            cur = Line();
            cur.first = i + 1;
            w = 0.f;
            continue;
        }
        if (maxWidth > 0.f && w + chars[i].width > maxWidth && i > cur.first) {
            cur.last = i;
            cur.width = w;
            lines.push_back(cur);
            cur = Line();
            cur.first = i;
            w = 0.f;
        }
        w += chars[i].width;
    }
    cur.last = chars.size();
    cur.width = w;
    if (cur.last > cur.first || lines.empty()) lines.push_back(cur);
    return lines;
}

}  // namespace

float Canvas::measureWidth(const char* utf8, const TextStyle& style) {
    if (utf8 == nullptr || *utf8 == '\0' || fonts_ == nullptr) return 0.f;
    FontFace& face = fonts_->face(style.bold);
    const float px = style.size * scale_;
    float total = 0.f;
    const char* s = utf8;
    const char* end = utf8 + std::strlen(utf8);
    while (s < end) {
        const uint32_t cp = utf8Next(s, end);
        if (cp == 0 || cp == '\n') break;
        total += face.advance(cp, px) + style.letterSpacing * scale_;
    }
    return total / scale_;
}

float Canvas::measureText(float maxWidth, const char* utf8, const TextStyle& style) {
    if (utf8 == nullptr || *utf8 == '\0' || fonts_ == nullptr) return 0.f;
    FontFace& face = fonts_->face(style.bold);
    const float px = style.size * scale_;
    const float lh = (style.lineHeight > 0.f ? style.lineHeight : style.size * 1.32f) * scale_;
    const auto chars = decode(utf8, face, px, style.letterSpacing * scale_);
    if (!style.wrap) return lh;
    const auto lines = breakLines(chars, maxWidth * scale_);
    const int count = std::min<int>(static_cast<int>(lines.size()), std::max(1, style.maxLines));
    return lh * count / scale_;
}

float Canvas::drawText(const Rect& r, const char* utf8, const TextStyle& style) {
    if (target_ == nullptr || fonts_ == nullptr || utf8 == nullptr || *utf8 == '\0') return 0.f;
    if (r.w <= 0.f || r.h <= 0.f) return 0.f;

    FontFace& face = fonts_->face(style.bold);
    if (!face.loaded()) return 0.f;

    const float px = style.size * scale_;
    const float spacing = style.letterSpacing * scale_;
    const auto chars = decode(utf8, face, px, spacing);
    if (chars.empty()) return 0.f;

    const float lh = (style.lineHeight > 0.f ? style.lineHeight : style.size * 1.32f) * scale_;
    const float ascent = face.ascent(px);
    const float descent = face.descent(px);
    const float baselineInLine = (lh - (ascent + descent)) * 0.5f + ascent;

    std::vector<Line> lines;
    if (style.wrap) {
        lines = breakLines(chars, r.w * scale_);
    } else {
        Line l;
        l.first = 0;
        float w = 0.f;
        for (const auto& c : chars) {
            if (c.cp == '\n') break;
            w += c.width;
            l.last = l.last + 1;
        }
        l.last = std::min(l.last + 1, chars.size());
        l.width = w;
        lines.push_back(l);
    }

    const int maxLines = std::max(1, style.maxLines);
    const int count = std::min<int>(static_cast<int>(lines.size()), maxLines);
    const float totalH = lh * count;

    float top = r.y * scale_;
    if (style.valign == TextStyle::Middle) top = r.y * scale_ + (r.h * scale_ - totalH) * 0.5f;
    else if (style.valign == TextStyle::Bottom) top = r.bottom() * scale_ - totalH;

    // Marquee: long single-line text slides left in a loop, the way ArkUI
    // scrolls text whose marquee flag is set. It repeats with a gap so the wrap
    // looks seamless instead of jumping back.
    if (style.marquee) {
        float textW = 0.f;
        for (const auto& ch : chars) {
            if (ch.cp == '\n') break;
            textW += ch.width;
        }
        const float boxW = r.w * scale_;
        if (textW > boxW) {
            const float gap = px * 1.5f;
            const float span = textW + gap;
            const float speed = 32.f * scale_;  // px per second
            const float offset = std::fmod(time_ * speed, span);
            const Rect savedClipMarquee = clip_;
            clip_ = clip().intersect(Rect(r.x * scale_, r.y * scale_, boxW, r.h * scale_));
            for (int pass = 0; pass < 2; ++pass) {
                float x2 = r.x * scale_ - offset + static_cast<float>(pass) * span;
                for (const auto& ch : chars) {
                    if (ch.cp == '\n') break;
                    const Glyph* gm = face.glyph(ch.cp, px);
                    if (gm != nullptr) {
                        const int bx2 = static_cast<int>(std::lround(x2 + gm->bearingX));
                        const int by2 = static_cast<int>(std::lround(top + baselineInLine - gm->bearingY));
                        const Rect clipNow2 = clip();
                        for (int j = 0; j < gm->h; ++j) {
                            const int py2 = by2 + j;
                            if (py2 < clipNow2.y || py2 >= clipNow2.bottom()) continue;
                            for (int i2 = 0; i2 < gm->w; ++i2) {
                                const uint8_t cov2 = gm->coverage[static_cast<size_t>(j) * gm->w + i2];
                                if (cov2 == 0) continue;
                                const int pxs2 = bx2 + i2;
                                if (pxs2 < clipNow2.x || pxs2 >= clipNow2.right()) continue;
                                blendPixel(pxs2, py2, style.color, cov2 / 255.f);
                            }
                        }
                    }
                    x2 += ch.width;
                }
            }
            clip_ = savedClipMarquee;
            return totalH / scale_;
        }
    }

    // Text never spills outside its box unless wrapping/ellipsis is off and the
    // caller asked for it, so clip to the layout rect like ArkUI does.
    const Rect savedClip = clip_;
    clip_ = clip().intersect(Rect(r.x * scale_, r.y * scale_, r.w * scale_, r.h * scale_));

    for (int li = 0; li < count; ++li) {
        const Line& line = lines[li];
        float x = r.x * scale_;
        if (style.align == TextStyle::Center) x = r.x * scale_ + (r.w * scale_ - line.width) * 0.5f;
        else if (style.align == TextStyle::Right) x = r.right() * scale_ - line.width;

        const float lineTop = top + li * lh;
        for (size_t i = line.first; i < line.last && i < chars.size(); ++i) {
            const CharRun& ch = chars[i];
            if (ch.cp == '\n') break;
            // Truncate with an ellipsis when the single-line box runs out, like
            // ArkUI's maxLines(1) + textOverflow(Ellipsis).
            if (style.maxLines == 1 && !style.wrap) {
                const float rightEdge = r.right() * scale_;
                const float charEnd = x + ch.width;
                if (charEnd > rightEdge + 0.01f) {
                    const float ew = face.advance(0x2026, px) + spacing;
                    const Glyph* dots = face.glyph(0x2026, px);
                    if (dots != nullptr) {
                        const int dx = static_cast<int>(std::lround(rightEdge - ew + dots->bearingX));
                        const int dy = static_cast<int>(std::lround(lineTop + baselineInLine - dots->bearingY));
                        for (int j = 0; j < dots->h; ++j) {
                            for (int i2 = 0; i2 < dots->w; ++i2) {
                                const uint8_t cov = dots->coverage[static_cast<size_t>(j) * dots->w + i2];
                                if (cov != 0) blendPixel(dx + i2, dy + j, style.color, cov / 255.f);
                            }
                        }
                    }
                    break;
                }
            }
            const Glyph* g = face.glyph(ch.cp, px);
            if (g != nullptr) {
                // Round to whole pixels: sub-pixel placement would blur stems at
                // these sizes, and ArkUI's own text is pixel-snapped too.
                const int bx = static_cast<int>(std::lround(x + g->bearingX));
                const int by = static_cast<int>(std::lround(lineTop + baselineInLine - g->bearingY));
                const Rect clipNow = clip();
                for (int j = 0; j < g->h; ++j) {
                    const int py = by + j;
                    if (py < 0 || py >= target_->h) continue;
                    if (py < clipNow.y || py >= clipNow.bottom()) continue;
                    const uint8_t* row = &g->coverage[static_cast<size_t>(j) * g->w];
                    for (int k = 0; k < g->w; ++k) {
                        const uint8_t cov = row[k];
                        if (cov == 0) continue;
                        const int pxs = bx + k;
                        if (pxs < 0 || pxs >= target_->w) continue;
                        if (pxs < clipNow.x || pxs >= clipNow.right()) continue;
                        blendPixel(pxs, py, style.color, cov / 255.f);
                    }
                }
            }
            x += ch.width;
        }
    }

    clip_ = savedClip;
    return totalH / scale_;
}

}  // namespace folio
