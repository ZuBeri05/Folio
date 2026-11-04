#include "domain/models.h"

#include <cstdio>
#include <cstdlib>
#include <ctime>

namespace folio {

const char* const kSubjectColors[16] = {
    "#E8A21A", "#4A90D9", "#D95F3F", "#8E7CC3", "#5AA469", "#E07A5F", "#7A8B99", "#3FA7A3",
    "#C77DBB", "#6C7BD9", "#D4A72C", "#7FA650", "#C46A8A", "#5B8CBF", "#9A7B4F", "#8C9A5B",
};

std::string newId() {
    // Mirrors newId(): base-36 timestamp plus six random base-36 digits.
    static const char* digits = "0123456789abcdefghijklmnopqrstuvwxyz";
    const unsigned long long now = static_cast<unsigned long long>(time(nullptr));
    std::string out;
    unsigned long long v = now;
    char buffer[16];
    int n = 0;
    do {
        buffer[n++] = digits[v % 36];
        v /= 36;
    } while (v > 0 && n < 15);
    while (n > 0) out.push_back(buffer[--n]);
    for (int i = 0; i < 6; ++i) out.push_back(digits[rand() % 36]);
    return out;
}

StudyItem emptyItem() {
    StudyItem item;
    item.scheduleMode = "curve";
    item.fsrsDifficulty = 5.0;
    return item;
}

AppData createDefaultData() {
    AppData data;
    data.schemaVersion = 2;
    data.subjects = {
        {"math", "数学", "#E8A21A"},
        {"english", "英语", "#4A90D9"},
        {"politics", "政治", "#D95F3F"},
        {"major", "专业课", "#8E7CC3"},
    };
    data.settings.reminderEnabled = true;
    data.settings.reminderTime = "20:00";
    data.settings.themeIndex = 0;
    data.settings.language = "zh";
    data.settings.targetRetention = 0.9;
    data.settings.maxIntervalDays = 180;
    data.settings.focusMinutes = 25;
    return data;
}

}  // namespace folio
