// Folio for Nintendo Switch: a homebrew port of the HarmonyOS app.
//
// The layout, colours, copy and motion all come from the original
// pages/Index.ets and theme/Tokens.ets; the renderer draws them with a small
// software rasterizer so the app does not need a GPU pipeline.
#include <switch.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <string>

#include "core/canvas.h"
#include "core/font.h"
#include "data/store.h"
#include "platform/platform.h"
#include "ui/app.h"
#include "ui/ui.h"

namespace {

folio::Bitmap g_frame;
folio::Canvas g_canvas;
folio::FontBook g_fonts;
folio::App g_app;
folio::Ui* g_ui = nullptr;

std::string fontPath(const char* name) { return std::string("romfs:/fonts/") + name; }

/**
 * libnx does not wire the C clock to the system clock by default; the app uses
 * local time for every date, so point newlib at the console's timezone first.
 */
void setupClock() {
    if (R_SUCCEEDED(timeInitialize())) {
        u64 timestamp = 0;
        if (R_SUCCEEDED(timeGetCurrentTime(TimeType_Default, &timestamp))) {
            // newlib reads the RTC through the SNTP-less path; seeding via
            // clock_settime keeps dates right even if the kernel clock is off.
            const time_t t = static_cast<time_t>(timestamp);
            struct timeval tv;
            tv.tv_sec = t;
            tv.tv_usec = 0;
            settimeofday(&tv, nullptr);
        }
        timeExit();
    }
    setenv("TZ", "UTC-8", 1);
    tzset();
}

void shutdown() {
    delete g_ui;
    g_ui = nullptr;
    folio::platform().shutdown();
}

}  // namespace

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;

    romfsInit();
    setupClock();
    folio::Store::init();

    if (!folio::platform().init()) {
        return 1;
    }
    g_frame.resize(folio::platform().pixelWidth(), folio::platform().pixelHeight());
    g_canvas.attach(&g_frame);
    folio::platformSetFrameBitmap(&g_frame);

    if (!g_fonts.load(fontPath("NotoSansSC-Regular.ttf").c_str(),
                      fontPath("NotoSansSC-Bold.ttf").c_str())) {
        // Without a font there is nothing to show; bail out rather than render
        // a blank screen the user cannot diagnose.
        return 1;
    }
    g_canvas.setFontBook(&g_fonts);

    g_app.init(&g_fonts);
    g_ui = new folio::Ui(g_canvas, g_fonts);

    while (appletMainLoop() && !folio::platform().shouldExit()) {
        const folio::FrameInfo info = folio::platform().beginFrame();
        folio::App::TouchSample sample;
        sample.active = folio::platform().touch().active;
        sample.x = folio::platform().touch().x;
        sample.y = folio::platform().touch().y;
        g_app.frame(g_canvas, *g_ui, info.dtMs, sample, info.widthVp, info.heightVp);
        folio::platform().present();
    }

    shutdown();
    romfsExit();
    return 0;
}