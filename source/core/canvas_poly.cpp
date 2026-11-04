// Polyline / polygon rasterization used for the app's line-art icons.
#include <algorithm>
#include <cmath>
#include <vector>

#include "core/canvas.h"
#include "gen/icons.h"

namespace folio {

namespace {

inline float segDist(float px, float py, float ax, float ay, float bx, float by) {
    const float dx = bx - ax;
    const float dy = by - ay;
    const float l2 = dx * dx + dy * dy;
    if (l2 <= 1e-9f) return std::sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
    float t = ((px - ax) * dx + (py - ay) * dy) / l2;
    t = t < 0.f ? 0.f : (t > 1.f ? 1.f : t);
    const float qx = ax + t * dx;
    const float qy = ay + t * dy;
    return std::sqrt((px - qx) * (px - qx) + (py - qy) * (py - qy));
}

}  // namespace

void Canvas::strokePolyline(const PolyPoint* points, int count, const Rect& box, float viewSize,
                            float strokeWidth, const Color& c) {
    if (points == nullptr || count < 2 || target_ == nullptr) return;
    const float sc = std::min(box.w, box.h) * scale_ / viewSize;

    // Flatten into pixel-space segments once, then rasterize each segment's
    // neighbourhood. Icon strokes are short, so this stays cheap.
    struct Seg {
        float ax, ay, bx, by;
    };
    std::vector<Seg> segs;
    segs.reserve(static_cast<size_t>(count));
    float px = 0.f, py = 0.f;
    for (int i = 0; i < count; ++i) {
        const float x = box.x * scale_ + points[i].x * sc;
        const float y = box.y * scale_ + points[i].y * sc;
        if (points[i].move || i == 0) {
            px = x;
            py = y;
            continue;
        }
        segs.push_back({px, py, x, y});
        px = x;
        py = y;
    }
    if (segs.empty()) return;

    const float half = strokeWidth * sc * 0.5f;
    const float reach = half + 1.f;
    const Rect clipRect = clip();
    for (const auto& s : segs) {
        const float minX = std::min(s.ax, s.bx) - reach;
        const float maxX = std::max(s.ax, s.bx) + reach;
        const float minY = std::min(s.ay, s.by) - reach;
        const float maxY = std::max(s.ay, s.by) + reach;
        const Rect area = Rect(minX, minY, maxX - minX, maxY - minY).intersect(clipRect);
        if (area.empty()) continue;
        const int x0 = static_cast<int>(std::floor(area.x));
        const int x1 = static_cast<int>(std::ceil(area.right()));
        const int y0 = static_cast<int>(std::floor(area.y));
        const int y1 = static_cast<int>(std::ceil(area.bottom()));
        for (int y = y0; y < y1; ++y) {
            for (int x = x0; x < x1; ++x) {
                const float d = segDist(x + 0.5f, y + 0.5f, s.ax, s.ay, s.bx, s.by);
                const float cov = clampf(half + 0.5f - d, 0.f, 1.f);
                if (cov > 0.004f) blendPixel(x, y, c, cov);
            }
        }
    }
}

void Canvas::fillPolygons(const PolyPoint* points, int count, const Rect& box, float viewSize,
                          const Color& c) {
    if (points == nullptr || count < 3 || target_ == nullptr) return;
    const float sc = std::min(box.w, box.h) * scale_ / viewSize;

    struct Seg {
        float x0, y0, x1, y1;
    };
    std::vector<Seg> segs;
    float px = 0.f, py = 0.f;
    for (int i = 0; i < count; ++i) {
        const float x = box.x * scale_ + points[i].x * sc;
        const float y = box.y * scale_ + points[i].y * sc;
        if (points[i].move || i == 0) {
            px = x;
            py = y;
            continue;
        }
        segs.push_back({px, py, x, y});
        px = x;
        py = y;
    }
    if (segs.empty()) return;

    const Rect area = Rect(box.x * scale_, box.y * scale_, box.w * scale_, box.h * scale_).intersect(clip());
    if (area.empty()) return;
    const int y0 = static_cast<int>(std::floor(area.y));
    const int y1 = static_cast<int>(std::ceil(area.bottom()));
    std::vector<float> xs;
    for (int y = y0; y < y1; ++y) {
        const float sy = static_cast<float>(y) + 0.5f;
        xs.clear();
        for (const auto& s : segs) {
            if ((s.y0 > sy) == (s.y1 > sy)) continue;
            const float t = (sy - s.y0) / (s.y1 - s.y0);
            xs.push_back(s.x0 + t * (s.x1 - s.x0));
        }
        if (xs.size() < 2) continue;
        std::sort(xs.begin(), xs.end());
        for (size_t k = 0; k + 1 < xs.size(); k += 2) {
            blendSpan(y, xs[k], xs[k + 1], c, 1.f);
        }
    }
}

}  // namespace folio