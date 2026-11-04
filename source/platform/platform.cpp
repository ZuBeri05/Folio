#include "platform/platform.h"
#include "platform/startup.h"

#include <switch.h>

#include <cstring>
#include <ctime>

namespace folio {

namespace {

Framebuffer g_fb;
ViDisplay g_display;
ViLayer g_layer;
NWindow g_window;
bool g_viReady = false;
bool g_displayReady = false;
bool g_layerReady = false;
bool g_windowReady = false;
bool g_fbReady = false;
Bitmap* g_frame = nullptr;
unsigned long long g_freq = 0;
PadState g_pad;

}  // namespace

Platform& platform() {
    static Platform instance;
    return instance;
}

long long Platform::nowMs() {
    timespec current{};
    if (clock_gettime(CLOCK_REALTIME, &current) != 0) return 0;
    return static_cast<long long>(current.tv_sec) * 1000LL + current.tv_nsec / 1000000LL;
}

bool Platform::init() {
    startupLog("configure input");
    padConfigureInput(1, HidNpadStyleSet_NpadStandard);
    hidInitializeTouchScreen();
    padInitializeDefault(&g_pad);
    g_freq = armGetSystemTickFreq();
    lastTick_ = armGetSystemTick();

    auto check = [](const char* stage, Result result) {
        startupLog(stage, result);
        return R_SUCCEEDED(result);
    };
    if (!check("viInitialize", viInitialize(ViServiceType_Default))) return false;
    g_viReady = true;
    if (!check("viOpenDefaultDisplay", viOpenDefaultDisplay(&g_display))) return false;
    g_displayReady = true;
    if (!check("viCreateLayer", viCreateLayer(&g_display, &g_layer))) return false;
    g_layerReady = true;
    if (!check("viSetLayerScalingMode", viSetLayerScalingMode(&g_layer, ViScalingMode_FitToLayer))) return false;
    if (!check("nwindowCreateFromLayer", nwindowCreateFromLayer(&g_window, &g_layer))) return false;
    g_windowReady = true;
    const u32 width = 1280;
    const u32 height = 720;
    if (!check("framebufferCreate", framebufferCreate(&g_fb, &g_window, width, height, PIXEL_FORMAT_RGBA_8888, 2))) {
        return false;
    }
    g_fbReady = true;
    if (!check("framebufferMakeLinear", framebufferMakeLinear(&g_fb))) {
        return false;
    }
    pixelWidth_ = static_cast<int>(width);
    pixelHeight_ = static_cast<int>(height);
    // One vp is (panel width / logical width) pixels, so the whole UI scales up.
    scale_ = static_cast<float>(width) / kLogicalWidth;
    return true;
}

void Platform::shutdown() {
    g_frame = nullptr;
    if (g_fbReady) {
        framebufferClose(&g_fb);
        g_fbReady = false;
    }
    if (g_windowReady) {
        nwindowClose(&g_window);
        g_windowReady = false;
    }
    if (g_layerReady) {
        viCloseLayer(&g_layer);
        g_layerReady = false;
    }
    if (g_displayReady) {
        viCloseDisplay(&g_display);
        g_displayReady = false;
    }
    if (g_viReady) {
        viExit();
        g_viReady = false;
    }
}

void Platform::present() {
    if (!g_fbReady || g_frame == nullptr) return;
    u32 stride = 0;
    auto* dst = static_cast<u8*>(framebufferBegin(&g_fb, &stride));
    if (dst != nullptr) {
        const int w = pixelWidth_;
        const int h = pixelHeight_;
        for (int y = 0; y < h; ++y) {
            std::memcpy(dst + static_cast<size_t>(y) * stride, g_frame->at(0, y), static_cast<size_t>(w) * 4);
        }
        framebufferEnd(&g_fb);
    }
}

FrameInfo Platform::beginFrame() {
    padUpdate(&g_pad);
    buttonsPrev_ = buttons_;
    buttons_ = padGetButtons(&g_pad);

    HidTouchScreenState state{};
    if (hidGetTouchScreenStates(&state, 1) > 0 && state.count > 0) {
        touch_.active = true;
        touch_.x = static_cast<float>(state.touches[0].x) / scale_;
        touch_.y = static_cast<float>(state.touches[0].y) / scale_;
    } else {
        touch_.active = false;
    }

    const unsigned long long now = armGetSystemTick();
    float dtMs = 16.6f;
    if (g_freq > 0) {
        dtMs = static_cast<float>(armTicksToNs(now - lastTick_) / 1000.0) / 1000.f;
    }
    lastTick_ = now;
    if (dtMs > 100.f) dtMs = 100.f;

    FrameInfo info;
    info.dtMs = dtMs;
    info.widthVp = static_cast<float>(pixelWidth_) / scale_;
    info.heightVp = static_cast<float>(pixelHeight_) / scale_;

    if ((buttons_ & HidNpadButton_Plus) != 0) {
        exitRequested_ = true;
    }
    return info;
}

namespace {

unsigned long long maskFor(PadKey key) {
    switch (key) {
        case PadKey::A: return HidNpadButton_A;
        case PadKey::B: return HidNpadButton_B;
        case PadKey::X: return HidNpadButton_X;
        case PadKey::Y: return HidNpadButton_Y;
        case PadKey::Plus: return HidNpadButton_Plus;
        case PadKey::Minus: return HidNpadButton_Minus;
        case PadKey::L: return HidNpadButton_L;
        case PadKey::R: return HidNpadButton_R;
        case PadKey::ZL: return HidNpadButton_ZL;
        case PadKey::ZR: return HidNpadButton_ZR;
        case PadKey::Up: return HidNpadButton_Up;
        case PadKey::Down: return HidNpadButton_Down;
        case PadKey::Left: return HidNpadButton_Left;
        case PadKey::Right: return HidNpadButton_Right;
        default: return 0;
    }
}

}  // namespace

bool Platform::pressed(PadKey key) const {
    const unsigned long long mask = maskFor(key);
    if (mask == 0) return false;
    return ((~buttonsPrev_) & buttons_ & mask) != 0;
}

bool Platform::held(PadKey key) const {
    const unsigned long long mask = maskFor(key);
    if (mask == 0) return false;
    return (buttons_ & mask) != 0;
}

bool Platform::requestText(const char* guide, const char* initial, std::string& out) {
    SwkbdConfig config;
    if (R_FAILED(swkbdCreate(&config, 0))) return false;
    swkbdConfigMakePresetDefault(&config);
    swkbdConfigSetType(&config, SwkbdType_All);
    swkbdConfigSetStringLenMax(&config, 200);
    if (guide != nullptr) swkbdConfigSetGuideText(&config, guide);
    if (initial != nullptr && *initial != 0) swkbdConfigSetInitialText(&config, initial);

    char buffer[512] = {0};
    const Result rc = swkbdShow(&config, buffer, sizeof(buffer));
    swkbdClose(&config);
    if (R_FAILED(rc) || buffer[0] == 0) return false;
    out = buffer;
    return true;
}

void platformSetFrameBitmap(Bitmap* bitmap) { g_frame = bitmap; }

}  // namespace folio
