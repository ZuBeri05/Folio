#include "services/i18n.h"

#include <cstdio>
#include <string>

int main() {
    const long long timestamp = 1793750400000LL;
    const char* languages[] = {"zh", "en", "ja", "ko", "fr", "es"};
    const char* expected[] = {
        "2026年11月4日周三",
        "Wed, November 4, 2026  ·  Wed",
        "2026年11月4日  ·  水曜日",
        "2026년 11월 4일  ·  수요일",
        "4 novembre 2026  ·  mer.",
        "4 de noviembre de 2026  ·  mié"
    };
    for (int pass = 0; pass < 100; ++pass) {
        for (int index = 0; index < 6; ++index) {
            const std::string actual = folio::I18n::todayLabel(languages[index], timestamp);
            if (actual != expected[index]) {
                std::fprintf(stderr, "%s startup date: %s\n", languages[index], actual.c_str());
                return 1;
            }
        }
    }
    std::puts("Startup dates passed for all six languages.");
    return 0;
}
