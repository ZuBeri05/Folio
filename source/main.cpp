// Folio for Nintendo Switch: a homebrew port of the HarmonyOS app.
//
// The layout, colors, copy and motion all come from the original
// pages/Index.ets and theme/Tokens.ets; the renderer draws them with a small
// software rasterizer so the app does not need a GPU pipeline.
#include <switch.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <exception>
#include <new>
#include <string>

#include "core/canvas.h"
#include "core/font.h"
#include "data/store.h"
#include "platform/platform.h"
#include "platform/startup.h"
#include "ui/app.h"
#include "ui/ui.h"

namespace {

folio::Bitmap g_frame;
folio::Canvas g_canvas;
folio::FontBook g_fonts;
folio::App g_app;

std::string fontPath(const char* name) { return std::string("romfs:/fonts/") + name; }

/**
 * libnx already wires newlib's CLOCK_REALTIME to the console clock (including
 * the system time zone), so all this needs to do is make sure the C locale's
 * timezone is initialised before the first localtime() call.
 */
void setupClock() {
    // The console's region decides the offset; libnx exports it into the
    // environment at startup, so a single tzset() is enough.
    setenv("TZ", "CST-8", 1);
    tzset();
}

const char* runApp() {
    setupClock();
    folio::Store::init();

    if (!folio::platform().init()) {
        return "Folio: display initialization failed.";
    }
    folio::startupLog("allocate drawing buffer");
    g_frame.resize(folio::platform().pixelWidth(), folio::platform().pixelHeight());
    g_canvas.attach(&g_frame);
    folio::platformSetFrameBitmap(&g_frame);
    g_canvas.clear(folio::Color(1.f, 0.98f, 0.94f, 1.f));
    g_canvas.fillRoundRect(folio::Rect(580.f, 330.f, 120.f, 60.f), 24.f,
                          folio::Color(1.f, 0.77f, 0.19f, 1.f));
    folio::startupLog("present startup background");
    folio::platform().present();
    folio::startupLog("startup background presented");

    folio::startupLog("load fonts");
    if (!g_fonts.load(fontPath("NotoSansSC-Regular.ttf").c_str(),
                      fontPath("NotoSansSC-Bold.ttf").c_str())) {
        return "Folio: unable to read embedded fonts.";
    }
    g_canvas.setFontBook(&g_fonts);

    folio::startupLog("load application data");
    g_app.init(&g_fonts);
    folio::Ui ui(g_canvas, g_fonts);
    bool firstFrame = true;

    while (appletMainLoop() && !folio::platform().shouldExit()) {
        if (firstFrame) folio::startupLog("read first input");
        const folio::FrameInfo info = folio::platform().beginFrame();
        folio::TouchSample sample;
        sample.active = folio::platform().touch().active;
        sample.x = folio::platform().touch().x;
        sample.y = folio::platform().touch().y;
        if (firstFrame) folio::startupLog("draw first frame");
        g_app.frame(g_canvas, ui, info.dtMs, sample, info.widthVp, info.heightVp);
        if (firstFrame) folio::startupLog("present first frame");
        folio::platform().present();
        if (firstFrame) folio::startupLog("first frame presented");
        firstFrame = false;
    }
    return nullptr;
}

}  // namespace

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;

    folio::startupLog("main entered");
    const Result romfsResult = romfsInit();
    folio::startupLog("romfsInit", romfsResult);
    if (R_FAILED(romfsResult)) {
        folio::showStartupError("Folio: unable to open embedded fonts (RomFS).");
        return 1;
    }
    const char* failure = nullptr;
    try {
        failure = runApp();
    } catch (const std::bad_alloc&) {
        failure = "Folio: not enough memory to start.";
    } catch (const std::exception& error) {
        folio::startupLog(error.what());
        failure = "Folio: an error occurred during startup or rendering.";
    }
    if (failure != nullptr) folio::startupLog(failure);
    folio::platform().shutdown();
    romfsExit();
    if (failure != nullptr) folio::showStartupError(failure);
    else folio::startupLog("normal exit");
    return failure != nullptr ? 1 : 0;
}
