#include "platform/startup.h"

#include <switch.h>

#include <cstdio>
#include <sys/stat.h>

namespace folio {

void startupLog(const char* message, unsigned int result) {
    FILE* output = std::fopen("sdmc:/switch/folio/startup.log", "a");
    if (output == nullptr) return;
    std::fprintf(output, "%s | result=0x%08X\n", message, result);
    std::fclose(output);
}

void showStartupError(const char* message) {
    const AppletType type = appletGetAppletType();
    if (type != AppletType_Application && type != AppletType_SystemApplication) {
        startupLog("error dialog unavailable in applet mode");
        return;
    }
    static ErrorApplicationConfig error;
    if (R_SUCCEEDED(errorApplicationCreate(&error, message,
        "Folio could not start. Check /switch/folio/startup.log on the SD card."))) {
        errorApplicationShow(&error);
    }
}

}

extern "C" void userAppInit() {
    mkdir("sdmc:/switch", 0777);
    mkdir("sdmc:/switch/folio", 0777);
    FILE* output = std::fopen("sdmc:/switch/folio/startup.log", "w");
    if (output == nullptr) return;
    std::fprintf(output, "Folio Switch startup recovery build 1\n");
    std::fprintf(output, "Firmware: 0x%08X; applet type: %u\n",
                 hosversionGet(), static_cast<unsigned int>(appletGetAppletType()));
    std::fclose(output);
}
