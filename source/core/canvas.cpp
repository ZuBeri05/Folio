#include "core/canvas.h"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>

#include "core/font.h"

namespace folio {

namespace {

/** Signed distance to a rounded rect; negative inside. */
inline float sdRoundRect(float px, float py, float x, float y, float w, float h, float radius) {
    const float cx = x + w * 0.5f;
    const float cy = y + h * 0.5f;
    const float hx = w * 0.5f - radius;
    const float hy = h * 0.5f - radius;
    const float dx = std::fabs(px - cx) - hx;
    const float dy = std::fabs(py - cy) - hy;
    const float ax = dx > 0.f ? dx : 0.f;
    const float ay = dy > 0.f ? dy : 0.f;
    return std::sqrt(ax * ax + ay * ay) + std::min(std::max(dx, dy), 0.f) - radius;
}

inline float coverageOf(float d) { return clampf(0.5f - d, 0.f, 1.f); }

}  // namespace

void Bitmap::resize(int width, int height) {
    w = width;
    h = height;
    px.assign(static_cast<size_t>(w) * h * 4, 0);
}

Rect Canvas::clip() const {
    // Everything downstream of here is in physical pixels, so the fallback must
    // be the pixel bounds, not the vp layout bounds.
    if (clip_.empty()) return pixelBounds();
    return clip_.intersect(pixelBounds());
}

void Canvas::clear(const Color& c) {
    if (target_ == nullptr) return;
    const uint8_t r = toByte(c.r), g = toByte(c.g), b = toByte(c.b), a = toByte(c.a);
    uint8_t* p = target_->px.data();
    const size_t n = static_cast<size_t>(target_->w) * target_->h;
    if (a == 255) {
        for (size_t i = 0; i < n; ++i) {
            p[i * 4 + 0] = r;
            p[i * 4 + 1] = g;
            p[i * 4 + 2] = b;
            p[i * 4 + 3] = 255;
        }
        return;
    }
    for (size_t i = 0; i < n; ++i) {
        p[i * 4 + 0] = r;
        p[i * 4 + 1] = g;
        p[i * 4 + 2] = b;
        p[i * 4 + 3] = a;
    }
}

void Canvas::pushClip(const Rect& r) {
    const Rect px(r.x * scale_, r.y * scale_, r.w * scale_, r.h * scale_);
    clipStack_.push_back(clip_);
    clip_ = clip().intersect(px);
}

void Canvas::resetClip() {
    clip_ = Rect();
    clipStack_.clear();
}

void Canvas::popClip() {
    if (clipStack_.empty()) return;
    clip_ = clipStack_.back();
    clipStack_.pop_back();
}

void Canvas::pushAlpha(float a) {
    alphaStack_.push_back(alpha_);
    alpha_ *= clampf(a, 0.f, 1.f);
}

void Canvas::popAlpha() {
    if (alphaStack_.empty()) return;
    alpha_ = alphaStack_.back();
    alphaStack_.pop_back();
}

void Canvas::blendPixel(int x, int y, const Color& c, float coverage) {
    if (target_ == nullptr) return;
    if (x < 0 || y < 0 || x >= target_->w || y >= target_->h) return;
    const float a = clampf(c.a * coverage * alpha_, 0.f, 1.f);
    if (a <= 0.0005f) return;
    uint8_t* p = target_->at(x, y);
    const float dstA = p[3] / 255.f;
    const float outA = a + dstA * (1.f - a);
    if (outA <= 0.f) {
        p[0] = p[1] = p[2] = p[3] = 0;
        return;
    }
    const float k = dstA * (1.f - a);
    p[0] = toByte((c.r * a + (p[0] / 255.f) * k) / outA);
    p[1] = toByte((c.g * a + (p[1] / 255.f) * k) / outA);
    p[2] = toByte((c.b * a + (p[2] / 255.f) * k) / outA);
    p[3] = toByte(outA);
}

void Canvas::blendSpan(int y, float x0, float x1, const Color& c, float coverage) {
    if (x1 <= x0) return;
    const int ix0 = static_cast<int>(std::floor(x0));
    const int ix1 = static_cast<int>(std::ceil(x1));
    for (int x = ix0; x < ix1; ++x) {
        const float l = std::max(x0, static_cast<float>(x));
        const float r = std::min(x1, static_cast<float>(x + 1));
        if (r <= l) continue;
        blendPixel(x, y, c, coverage * (r - l));
    }
}

void Canvas::fillRoundRect(const Rect& r, float radius, const Color& c) {
    if (target_ == nullptr || r.w <= 0.f || r.h <= 0.f) return;
    const float x = r.x * scale_;
    const float y = r.y * scale_;
    const float w = r.w * scale_;
    const float h = r.h * scale_;
    const float rad = clampf(radius * scale_, 0.f, std::min(w, h) * 0.5f);
    const Rect vis = Rect(x, y, w, h).intersect(clip());
    if (vis.empty()) return;

    const float cx = x + w * 0.5f;
    const float cy = y + h * 0.5f;
    const float coreH = h * 0.5f - rad;
    const int py0 = static_cast<int>(std::floor(vis.y));
    const int py1 = static_cast<int>(std::ceil(vis.bottom()));

    for (int py = py0; py < py1; ++py) {
        const float sy = static_cast<float>(py) + 0.5f;
        const float dyc = std::fabs(sy - cy);
        if (dyc > h * 0.5f) continue;

        // Straight middle rows: an exact horizontal span plus edge AA is enough.
        if (dyc <= coreH) {
            const float l = std::max(x, vis.x);
            const float rr = std::min(x + w, vis.right());
            if (rr > l) blendSpan(py, l, rr, c, 1.f);
            continue;
        }

        // Corner band: use the signed distance so both the arc and the row ends
        // get sub-pixel coverage (a pure span fill leaves stair-stepped arcs).
        const float over = dyc - coreH;
        if (over >= rad + 1.f) continue;
        const float halfW = w * 0.5f - rad + std::sqrt(std::max(0.f, rad * rad - over * over));
        const float spanL = cx - halfW - 1.5f;
        const float spanR = cx + halfW + 1.5f;
        const int px0 = static_cast<int>(std::floor(std::max(spanL, vis.x)));
        const int px1 = static_cast<int>(std::ceil(std::min(spanR, vis.right())));
        for (int px = px0; px < px1; ++px) {
            const float d = sdRoundRect(px + 0.5f, sy, x, y, w, h, rad);
            const float cov = coverageOf(d);
            if (cov > 0.002f) blendPixel(px, py, c, cov);
        }
    }
}
void Canvas::strokeRoundRect(const Rect& r, float radius, float width, const Color& c) {
    if (target_ == nullptr || r.w <= 0.f || r.h <= 0.f || width <= 0.f) return;
    const float x = r.x * scale_;
    const float y = r.y * scale_;
    const float w = r.w * scale_;
    const float h = r.h * scale_;
    const float rad = clampf(radius * scale_, 0.f, std::min(w, h) * 0.5f);
    const float lw = width * scale_;
    const Rect vis = Rect(x - 1.f, y - 1.f, w + 2.f, h + 2.f).intersect(clip());
    if (vis.empty()) return;

    const int px0 = static_cast<int>(std::floor(vis.x));
    const int px1 = static_cast<int>(std::ceil(vis.right()));
    const int py0 = static_cast<int>(std::floor(vis.y));
    const int py1 = static_cast<int>(std::ceil(vis.bottom()));
    for (int py = py0; py < py1; ++py) {
        for (int px = px0; px < px1; ++px) {
            const float d = sdRoundRect(px + 0.5f, py + 0.5f, x, y, w, h, rad);
            const float cov = coverageOf(d) - coverageOf(d + lw);
            if (cov > 0.002f) blendPixel(px, py, c, cov);
        }
    }
}

void Canvas::fillCircle(float cx, float cy, float radius, const Color& c) {
    fillRoundRect(Rect(cx - radius, cy - radius, radius * 2.f, radius * 2.f), radius, c);
}

void Canvas::strokeCircle(float cx, float cy, float radius, float width, const Color& c) {
    if (radius <= 0.f || width <= 0.f) return;
    const float r = radius * scale_;
    const float half = width * scale_ * 0.5f;
    const float px = cx * scale_;
    const float py = cy * scale_;
    const float outer = r + half + 1.f;
    const Rect vis = Rect(px - outer, py - outer, outer * 2.f, outer * 2.f).intersect(clip());
    if (vis.empty()) return;
    const int px0 = static_cast<int>(std::floor(vis.x));
    const int px1 = static_cast<int>(std::ceil(vis.right()));
    const int py0 = static_cast<int>(std::floor(vis.y));
    const int py1 = static_cast<int>(std::ceil(vis.bottom()));
    for (int y = py0; y < py1; ++y) {
        for (int x = px0; x < px1; ++x) {
            const float dx = x + 0.5f - px;
            const float dy = y + 0.5f - py;
            const float d = std::sqrt(dx * dx + dy * dy) - r;
            const float cov = coverageOf(std::fabs(d) - half);
            if (cov > 0.002f) blendPixel(x, y, c, cov);
        }
    }
}

void Canvas::strokeArc(float cx, float cy, float radius, float width, float fromAngle, float toAngle,
                       const Color& c, float alphaMul) {
    if (radius <= 0.f || width <= 0.f) return;
    const float r = radius * scale_;
    const float half = width * scale_ * 0.5f;
    const float px = cx * scale_;
    const float py = cy * scale_;
    const float outer = r + half + 1.f;
    const Rect vis = Rect(px - outer, py - outer, outer * 2.f, outer * 2.f).intersect(clip());
    if (vis.empty()) return;

    float a0 = fromAngle;
    float a1 = toAngle;
    if (a1 < a0) a1 += 2.f * kPi;
    const float span = a1 - a0;
    if (span <= 0.0001f) return;
    const float edge = 0.9f / std::max(1.f, r);

    const int px0 = static_cast<int>(std::floor(vis.x));
    const int px1 = static_cast<int>(std::ceil(vis.right()));
    const int py0 = static_cast<int>(std::floor(vis.y));
    const int py1 = static_cast<int>(std::ceil(vis.bottom()));
    for (int y = py0; y < py1; ++y) {
        for (int x = px0; x < px1; ++x) {
            const float dx = x + 0.5f - px;
            const float dy = y + 0.5f - py;
            const float dist = std::sqrt(dx * dx + dy * dy);
            float cov = coverageOf(std::fabs(dist - r) - half);
            if (cov <= 0.002f) continue;
            float ang = std::atan2(dx, -dy);
            if (ang < 0.f) ang += 2.f * kPi;
            float rel = ang - a0;
            while (rel < 0.f) rel += 2.f * kPi;
            if (rel > span) {
                const float over = rel - span;
                if (over > edge) continue;
                cov *= 1.f - over / edge;
            }
            blendPixel(x, y, c.withAlpha(alphaMul * alpha_), cov);
        }
    }
}

void Canvas::shadowRoundRect(const Rect& r, float radius, float blur, const Color& c, float dy) {
    if (target_ == nullptr || r.w <= 0.f || r.h <= 0.f) return;
    const float x = r.x * scale_;
    const float y = r.y * scale_;
    const float w = r.w * scale_;
    const float h = r.h * scale_;
    const float rad = clampf(radius * scale_, 0.f, std::min(w, h) * 0.5f);
    const float b = blur * scale_;
    const float offY = dy * scale_;
    const Rect box(x - b, y - b + offY, w + b * 2.f, h + b * 2.f);
    const Rect vis = box.intersect(clip());
    if (vis.empty()) return;

    // Two-sigma falloff: the visual weight matches ArkUI's blur radius while
    // staying cheap to evaluate per pixel.
    const float sigma = std::max(0.8f, b * 0.42f);
    const float inv = 1.f / (2.f * sigma * sigma);
    const int px0 = static_cast<int>(std::floor(vis.x));
    const int px1 = static_cast<int>(std::ceil(vis.right()));
    const int py0 = static_cast<int>(std::floor(vis.y));
    const int py1 = static_cast<int>(std::ceil(vis.bottom()));
    for (int py = py0; py < py1; ++py) {
        for (int px = px0; px < px1; ++px) {
            const float d = sdRoundRect(px + 0.5f, py + 0.5f, x, y + offY, w, h, rad);
            // Inside the shape the card itself covers the shadow, so skip it;
            // taper from the edge outward.
            if (d <= 0.f) continue;
            const float wgt = std::exp(-(d * d) * inv);
            if (wgt > 0.003f) blendPixel(px, py, c, wgt);
        }
    }
}
void Canvas::blurRoundRect(const Rect& r, float radius, float blurVp) {
    if (target_ == nullptr || r.w <= 0.f || r.h <= 0.f) return;
    const float x = r.x * scale_;
    const float y = r.y * scale_;
    const float w = r.w * scale_;
    const float h = r.h * scale_;
    const float rad = clampf(radius * scale_, 0.f, std::min(w, h) * 0.5f);
    // Work on the intersection with the canvas so a full-screen blur cannot
    // allocate a buffer far beyond the framebuffer.
    const Rect area = Rect(x, y, w, h).intersect(pixelBounds());
    if (area.empty() || blurVp <= 0.f) return;
    const int bx0 = static_cast<int>(std::floor(area.x));
    const int by0 = static_cast<int>(std::floor(area.y));
    const int bw = static_cast<int>(std::ceil(area.w));
    const int bh = static_cast<int>(std::ceil(area.h));
    if (bw <= 0 || bh <= 0) return;
    const int rad2 = std::max(1, static_cast<int>(blurVp * scale_ * 0.75f));

    std::vector<float> buf(static_cast<size_t>(bw) * bh * 3);
    for (int j = 0; j < bh; ++j) {
        for (int i = 0; i < bw; ++i) {
            const int sx = std::min(target_->w - 1, std::max(0, bx0 + i));
            const int sy = std::min(target_->h - 1, std::max(0, by0 + j));
            const uint8_t* p = target_->at(sx, sy);
            float* o = &buf[(static_cast<size_t>(j) * bw + i) * 3];
            o[0] = p[0];
            o[1] = p[1];
            o[2] = p[2];
        }
    }

    std::vector<float> tmp(static_cast<size_t>(std::max(bw, bh)) * 3);
    const float norm = 1.f / (rad2 * 2 + 1);
    for (int pass = 0; pass < 2; ++pass) {
        for (int j = 0; j < bh; ++j) {
            float* row = &buf[static_cast<size_t>(j) * bw * 3];
            for (int c = 0; c < 3; ++c) {
                float sum = 0.f;
                for (int k = -rad2; k <= rad2; ++k) {
                    sum += row[std::min(bw - 1, std::max(0, k)) * 3 + c];
                }
                for (int i = 0; i < bw; ++i) {
                    tmp[i * 3 + c] = sum * norm;
                    sum += row[std::min(bw - 1, i + rad2 + 1) * 3 + c];
                    sum -= row[std::max(0, i - rad2) * 3 + c];
                }
            }
            for (int i = 0; i < bw; ++i) {
                row[i * 3 + 0] = tmp[i * 3 + 0];
                row[i * 3 + 1] = tmp[i * 3 + 1];
                row[i * 3 + 2] = tmp[i * 3 + 2];
            }
        }
        for (int i = 0; i < bw; ++i) {
            for (int c = 0; c < 3; ++c) {
                float sum = 0.f;
                for (int k = -rad2; k <= rad2; ++k) {
                    sum += buf[(static_cast<size_t>(std::min(bh - 1, std::max(0, k))) * bw + i) * 3 + c];
                }
                for (int j = 0; j < bh; ++j) {
                    tmp[j * 3 + c] = sum * norm;
                    sum += buf[(static_cast<size_t>(std::min(bh - 1, j + rad2 + 1)) * bw + i) * 3 + c];
                    sum -= buf[(static_cast<size_t>(std::max(0, j - rad2)) * bw + i) * 3 + c];
                }
                for (int j = 0; j < bh; ++j) {
                    buf[(static_cast<size_t>(j) * bw + i) * 3 + c] = tmp[j * 3 + c];
                }
            }
        }
    }

    const Rect vis = Rect(x, y, w, h).intersect(clip());
    if (vis.empty()) return;
    const int wx0 = static_cast<int>(std::floor(vis.x));
    const int wx1 = static_cast<int>(std::ceil(vis.right()));
    const int wy0 = static_cast<int>(std::floor(vis.y));
    const int wy1 = static_cast<int>(std::ceil(vis.bottom()));
    for (int j = wy0; j < wy1; ++j) {
        for (int i = wx0; i < wx1; ++i) {
            const float cov = coverageOf(sdRoundRect(i + 0.5f, j + 0.5f, x, y, w, h, rad));
            if (cov <= 0.002f) continue;
            const int bi = std::min(bw - 1, std::max(0, i - bx0));
            const int bj = std::min(bh - 1, std::max(0, j - by0));
            const float* s = &buf[(static_cast<size_t>(bj) * bw + bi) * 3];
            blendPixel(i, j, Color(s[0] / 255.f, s[1] / 255.f, s[2] / 255.f, cov), 1.f);
        }
    }
}

}  // namespace folio