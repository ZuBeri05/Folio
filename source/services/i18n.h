#pragma once

#include <string>

namespace folio {

struct LanguageOption {
    const char* code;
    const char* name;
    const char* locale;
};

class I18n {
public:
    static const LanguageOption kLanguages[6];

    /** t(key) with {0}/{1} substitution, falling back to English then the key. */
    static std::string t(const std::string& lang, const char* key);
    static std::string t(const std::string& lang, const char* key, const std::string& a);
    static std::string t(const std::string& lang, const char* key, const std::string& a, const std::string& b);
    static std::string t(const std::string& lang, const char* key, int a);
    static std::string t(const std::string& lang, const char* key, int a, const std::string& b);

    static std::string dateShort(const std::string& lang, long long ts);
    static std::string dateLong(const std::string& lang, long long ts);
    static std::string weekday(const std::string& lang, long long ts);
    static std::string locale(const std::string& lang);
    /** "2026年11月3日 · 星期二" in the current language. */
    static std::string todayLabel(const std::string& lang, long long now);
};

}  // namespace folio
