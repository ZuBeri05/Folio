// Minimal stand-in for <switch.h> so platform sources can be compiled on a
// desktop for syntax checks. Not used by the .nro build.
#pragma once

#include <cstdint>
#include <cstddef>
#include <ctime>
#include <sys/time.h>

typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int32_t s32;
typedef int64_t s64;
typedef int Result;

#define R_SUCCEEDED(res) ((res) == 0)
#define R_FAILED(res) ((res) != 0)

typedef struct { int _; } NWindow;
typedef struct { int _; } ViDisplay;
typedef struct { int _; } ViLayer;
typedef struct { int _; } Framebuffer;
typedef struct { int _; } PadState;
typedef struct { u64 _; } Event;

enum { PIXEL_FORMAT_RGBA_8888 = 0 };
enum { ViServiceType_Default = 0, ViScalingMode_FitToLayer = 0, HidNpadStyleSet_NpadStandard = 0 };
enum { HidNpadButton_A = 1ULL << 0, HidNpadButton_B = 1ULL << 1, HidNpadButton_X = 1ULL << 2,
       HidNpadButton_Y = 1ULL << 3, HidNpadButton_L = 1ULL << 6, HidNpadButton_R = 1ULL << 7,
       HidNpadButton_ZL = 1ULL << 8, HidNpadButton_ZR = 1ULL << 9, HidNpadButton_Plus = 1ULL << 14,
       HidNpadButton_Minus = 1ULL << 15, HidNpadButton_Up = 1ULL << 16, HidNpadButton_Down = 1ULL << 17,
       HidNpadButton_Left = 1ULL << 18, HidNpadButton_Right = 1ULL << 19 };

struct HidTouchState {
    u64 delta_time;
    u32 attributes;
    u32 finger_id;
    u32 x;
    u32 y;
    u32 diameter_x;
    u32 diameter_y;
    u32 rotation_angle;
    u32 reserved;
};

struct HidTouchScreenState {
    u64 sampling_number;
    s32 count;
    u32 reserved;
    HidTouchState touches[16];
};

enum { TimeType_Default = 0 };
typedef struct { char name[36]; } TimeLocationName;

struct SwkbdConfig { int _[64]; };
struct ErrorApplicationConfig { int _[1024]; };
enum SwkbdType { SwkbdType_All = 8 };

inline void hidInitialize() {}
inline void hidInitializeTouchScreen() {}
inline void padInitializeDefault(PadState*) {}
inline void padConfigureInput(u32, u32) {}
inline void padUpdate(PadState*) {}
inline u64 padGetButtons(const PadState*) { return 0; }
inline size_t hidGetTouchScreenStates(HidTouchScreenState* s, size_t n) { (void)s; (void)n; return 0; }
inline NWindow* nwindowGetDefault() { static NWindow w; return &w; }
inline Result viInitialize(int) { return 0; }
inline Result viOpenDefaultDisplay(ViDisplay*) { return 0; }
inline Result viCreateLayer(ViDisplay*, ViLayer*) { return 0; }
inline Result viSetLayerScalingMode(ViLayer*, int) { return 0; }
inline Result nwindowCreateFromLayer(NWindow*, ViLayer*) { return 0; }
inline void nwindowClose(NWindow*) {}
inline Result viCloseLayer(ViLayer*) { return 0; }
inline Result viCloseDisplay(ViDisplay*) { return 0; }
inline void viExit() {}
inline Result nwindowSetDimensions(NWindow*, u32, u32) { return 0; }
inline Result framebufferCreate(Framebuffer*, NWindow*, u32, u32, u32, u32) { return 0; }
inline Result framebufferMakeLinear(Framebuffer*) { return 0; }
inline void framebufferClose(Framebuffer*) {}
inline void* framebufferBegin(Framebuffer*, u32* stride) { *stride = 0; return nullptr; }
inline void framebufferEnd(Framebuffer*) {}
inline u64 armGetSystemTick() { return 0; }
inline u64 armGetSystemTickFreq() { return 19200000; }
inline u64 armTicksToNs(u64 t) { return t; }
inline bool appletMainLoop() { return false; }
inline Result romfsInit() { return 0; }
inline void romfsExit() {}
inline u32 hosversionGet() { return 0; }
inline int appletGetAppletType() { return 0; }
inline Result errorApplicationCreate(ErrorApplicationConfig*, const char*, const char*) { return 0; }
inline Result errorApplicationShow(ErrorApplicationConfig*) { return 0; }
inline Result timeInitialize() { return 0; }
inline void timeExit() {}
inline Result timeGetCurrentTime(int, u64* t) { if (t) *t = 0; return 0; }
inline Result timeGetDeviceLocationName(TimeLocationName*) { return 0; }
inline Result swkbdCreate(SwkbdConfig*, s32) { return 0; }
inline void swkbdConfigMakePresetDefault(SwkbdConfig*) {}
inline void swkbdConfigSetType(SwkbdConfig*, SwkbdType) {}
inline void swkbdConfigSetStringLenMax(SwkbdConfig*, u32) {}
inline void swkbdConfigSetGuideText(SwkbdConfig*, const char*) {}
inline void swkbdConfigSetInitialText(SwkbdConfig*, const char*) {}
inline Result swkbdShow(SwkbdConfig*, char*, size_t) { return 1; }
inline void swkbdClose(SwkbdConfig*) {}
