// Desktop preview harness: renders the Switch UI offscreen to a PNG so the
// layout can be checked without hardware. Not part of the .nro build.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <sys/stat.h>
#include <vector>

#include "core/canvas.h"
#include "core/font.h"
#include "data/store.h"
#include "domain/dates.h"
#include "platform/platform.h"
#include "ui/app.h"
#include "ui/ui.h"

#ifndef FOLIO_HOST
#define FOLIO_HOST 1
#endif

// ---------------------------------------------------------------------------
// Host stubs for the platform layer (the real one talks to libnx).
// ---------------------------------------------------------------------------
namespace folio {

namespace {
long long g_now = 1762300000000LL;
}

long long Platform::nowMs() { return g_now; }

Platform& platform() {
    static Platform p;
    return p;
}

bool Platform::init() { return true; }
void Platform::shutdown() {}
void Platform::present() {}

FrameInfo Platform::beginFrame() {
    FrameInfo info;
    info.dtMs = 16.f;
    info.widthVp = 1280.f;
    info.heightVp = 720.f;
    return info;
}

bool Platform::pressed(PadKey) const { return false; }
bool Platform::held(PadKey) const { return false; }
bool Platform::requestText(const char*, const char*, std::string&) { return false; }
void platformSetFrameBitmap(Bitmap*) {}

}  // namespace folio

static void writePng(const folio::Bitmap& bmp, const char* path) {
    // Minimal PNG writer (no zlib dependency: stored deflate blocks).
    std::vector<unsigned char> raw;
    raw.reserve(static_cast<size_t>(bmp.h) * (bmp.w * 4 + 1));
    for (int y = 0; y < bmp.h; ++y) {
        raw.push_back(0);
        for (int x = 0; x < bmp.w; ++x) {
            const unsigned char* p = bmp.at(x, y);
            // Composite over the page background so the PNG is opaque.
            const float a = p[3] / 255.f;
            raw.push_back(static_cast<unsigned char>(p[0]));
            raw.push_back(static_cast<unsigned char>(p[1]));
            raw.push_back(static_cast<unsigned char>(p[2]));
            raw.push_back(255);
            (void)a;
        }
    }

    auto crc32 = [](const unsigned char* data, size_t len) {
        static unsigned table[256];
        static bool init = false;
        if (!init) {
            for (unsigned n = 0; n < 256; ++n) {
                unsigned c = n;
                for (int k = 0; k < 8; ++k) c = (c & 1) ? 0xEDB88320u ^ (c >> 1) : c >> 1;
                table[n] = c;
            }
            init = true;
        }
        unsigned c = 0xFFFFFFFFu;
        for (size_t i = 0; i < len; ++i) c = table[(c ^ data[i]) & 0xFF] ^ (c >> 8);
        return c ^ 0xFFFFFFFFu;
    };

    std::vector<unsigned char> z;
    z.push_back(0x78);
    z.push_back(0x01);
    size_t offset = 0;
    while (offset < raw.size()) {
        const size_t chunk = std::min<size_t>(65535, raw.size() - offset);
        const bool last = offset + chunk >= raw.size();
        z.push_back(last ? 1 : 0);
        z.push_back(static_cast<unsigned char>(chunk & 0xFF));
        z.push_back(static_cast<unsigned char>((chunk >> 8) & 0xFF));
        z.push_back(static_cast<unsigned char>(~chunk & 0xFF));
        z.push_back(static_cast<unsigned char>((~chunk >> 8) & 0xFF));
        z.insert(z.end(), raw.begin() + offset, raw.begin() + offset + chunk);
        offset += chunk;
    }
    unsigned s1 = 1, s2 = 0;
    for (unsigned char c : raw) {
        s1 = (s1 + c) % 65521;
        s2 = (s2 + s1) % 65521;
    }
    const unsigned adler = (s2 << 16) | s1;
    z.push_back(static_cast<unsigned char>((adler >> 24) & 0xFF));
    z.push_back(static_cast<unsigned char>((adler >> 16) & 0xFF));
    z.push_back(static_cast<unsigned char>((adler >> 8) & 0xFF));
    z.push_back(static_cast<unsigned char>(adler & 0xFF));

    auto be32 = [](std::vector<unsigned char>& out, unsigned v) {
        out.push_back((v >> 24) & 0xFF);
        out.push_back((v >> 16) & 0xFF);
        out.push_back((v >> 8) & 0xFF);
        out.push_back(v & 0xFF);
    };

    std::vector<unsigned char> png = {0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A};
    auto chunk = [&](const char* type, const std::vector<unsigned char>& data) {
        be32(png, static_cast<unsigned>(data.size()));
        const size_t start = png.size();
        png.insert(png.end(), type, type + 4);
        png.insert(png.end(), data.begin(), data.end());
        const unsigned c = crc32(&png[start], png.size() - start);
        be32(png, c);
    };
    std::vector<unsigned char> ihdr;
    be32(ihdr, bmp.w);
    be32(ihdr, bmp.h);
    ihdr.push_back(8);
    ihdr.push_back(6);
    ihdr.push_back(0);
    ihdr.push_back(0);
    ihdr.push_back(0);
    chunk("IHDR", ihdr);
    chunk("IDAT", z);
    chunk("IEND", {});

    FILE* f = std::fopen(path, "wb");
    if (f == nullptr) return;
    std::fwrite(png.data(), 1, png.size(), f);
    std::fclose(f);
}

int main(int argc, char** argv) {
    const int w = argc > 1 ? std::atoi(argv[1]) : 1280;
    const int h = argc > 2 ? std::atoi(argv[2]) : 720;
    const char* out = argc > 3 ? argv[3] : "preview.png";
    const int tab = argc > 4 ? std::atoi(argv[4]) : 0;
    const int frames = argc > 5 ? std::atoi(argv[5]) : 90;
    // Mirrors Platform::init(): vp = panel pixels / (panel width / logical width).
    const float logicalWidth = w / (static_cast<float>(w) / folio::kLogicalWidth);
    const float logicalHeight = h / (static_cast<float>(w) / folio::kLogicalWidth);

    folio::Bitmap bmp;
    bmp.resize(w, h);
    folio::Canvas canvas;
    canvas.attach(&bmp);

    folio::FontBook fonts;
    if (!fonts.load("res/fonts/NotoSansSC-Regular.ttf", "res/fonts/NotoSansSC-Bold.ttf")) {
        std::fprintf(stderr, "font load failed\n");
        return 1;
    }
    canvas.setFontBook(&fonts);

    // Seed a save file so the populated states (cards, timeline, review queue)
    // can be inspected without doing it by hand on hardware.
    folio::Store::init();
    const char* seed = std::getenv("FOLIO_SEED");
    if (seed != nullptr) {
        folio::AppData data = folio::createDefaultData();
        const long long now = folio::Platform::nowMs();
        const char* titles[] = {"导数的几何意义", "现在完成时的用法与过去完成时在虚拟语气中的差异对比", "矛盾的普遍性", "数据结构：红黑树"};
        const char* subjects[] = {"math", "english", "politics", "major"};
        for (int i = 0; i < 4; ++i) {
            folio::StudyItem item;
            item.id = "seed" + std::to_string(i);
            item.subjectId = subjects[i];
            item.title = titles[i];
            item.createdAt = now - static_cast<long long>(i) * 86400000LL;
            item.scheduleMode = "fsrs";
            item.currentIntervalDays = 1 + i;
            item.nextReviewAt = folio::startOfDay(now) - static_cast<long long>(i) * 86400000LL;
            item.lastReviewedAt = i == 0 ? 0 : now - 86400000LL;
            item.reviewCount = i;
            item.fsrsStability = 2.0 + i;
            item.fsrsDifficulty = 5.0;
            item.fsrsState = i == 0 ? "new" : "review";
            item.fsrsScheduledDays = 1 + i;
            data.items.push_back(item);
        }
        folio::FocusSession s;
        s.id = "fs1";
        s.startedAt = folio::startOfDay(now);
        s.endedAt = now;
        s.plannedMinutes = 25;
        s.minutes = 25;
        s.itemCount = 3;
        s.remembered = 2;
        s.completed = true;
        data.focusSessions.push_back(s);
        folio::Store::save(data);
    }

    folio::Ui ui(canvas, fonts);
    folio::App app;
    app.init(&fonts);

    folio::TouchSample none;
    for (int i = 0; i < frames; ++i) {
        app.frame(canvas, ui, 16.f, none, logicalWidth, logicalHeight);
    }
    if (tab != 0) {
        // Tap the rail entry for the requested tab, then settle.
        const float scale = static_cast<float>(w) / logicalWidth;
        folio::TouchSample tap;
        tap.active = true;
        tap.x = (6.f + 56.f);
        tap.y = 56.f + tab * 122.f + 44.f;
        app.frame(canvas, ui, 16.f, tap, logicalWidth, logicalHeight);
        none.active = false;
        for (int i = 0; i < 60; ++i) app.frame(canvas, ui, 16.f, none, logicalWidth, logicalHeight);
        (void)scale;
    }
    std::printf("clip depth after frame: %d\n", canvas.clipDepth());
    writePng(bmp, out);
    std::printf("wrote %s (%dx%d)\n", out, w, h);
    return 0;
}
