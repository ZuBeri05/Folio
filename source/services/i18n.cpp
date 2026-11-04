#include "services/i18n.h"

#include <cstdio>
#include <cstring>
#include <unordered_map>

#include "domain/dates.h"
#include "gen/i18n_tables.h"

namespace folio {

const LanguageOption I18n::kLanguages[6] = {
    {"zh", "中文", "zh-CN"},
    {"en", "English", "en-US"},
    {"ja", "日本語", "ja-JP"},
    {"ko", "한국어", "ko-KR"},
    {"fr", "Français", "fr-FR"},
    {"es", "Español", "es-ES"},
};

namespace {

using Table = std::unordered_map<std::string, std::string>;

Table buildTable(const char* const (*rows)[2], size_t count) {
    Table out;
    out.reserve(count * 2);
    for (size_t i = 0; i < count; ++i) {
        out.emplace(rows[i][0], rows[i][1]);
    }
    return out;
}

template <size_t N>
Table buildTable(const char* const (&rows)[N][2]) {
    return buildTable(reinterpret_cast<const char* const (*)[2]>(rows), N);
}

const Table& tableFor(const std::string& lang) {
    static const Table zh = buildTable(k_zh);
    static const Table en = buildTable(k_en);
    static const Table ja = buildTable(k_ja);
    static const Table ko = buildTable(k_ko);
    static const Table fr = buildTable(k_fr);
    static const Table es = buildTable(k_es);
    if (lang == "en") return en;
    if (lang == "ja") return ja;
    if (lang == "ko") return ko;
    if (lang == "fr") return fr;
    if (lang == "es") return es;
    return zh;
}

void replaceAll(std::string& s, const char* needle, const std::string& value) {
    size_t pos = 0;
    while ((pos = s.find(needle, pos)) != std::string::npos) {
        s.replace(pos, std::strlen(needle), value);
        pos += value.size();
    }
}

const char* const kMonthsEn[12] = {"January", "February", "March",     "April",   "May",      "June",
                                   "July",    "August",   "September", "October", "November", "December"};
const char* const kMonthsJa[12] = {"1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"};
const char* const kMonthsKo[12] = {"1월", "2월", "3월", "4월", "5월", "6월", "7월", "8월", "9월", "10월", "11월", "12월"};
const char* const kMonthsFr[12] = {"janvier", "février", "mars",     "avril",    "mai",      "juin",
                                   "juillet", "août",    "septembre", "octobre", "novembre", "décembre"};
const char* const kMonthsEs[12] = {"enero",   "febrero", "marzo",    "abril",   "mayo",     "junio",
                                   "julio",   "agosto",  "septiembre", "octubre", "noviembre", "diciembre"};
const char* const kMonthsZh[12] = {"1 月", "2 月", "3 月", "4 月", "5 月", "6 月",
                                   "7 月", "8 月", "9 月", "10 月", "11 月", "12 月"};

const char* const kWeekdaysEn[7] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
const char* const kWeekdaysJa[7] = {"日", "月", "火", "水", "木", "金", "土"};
const char* const kWeekdaysKo[7] = {"일", "월", "화", "수", "목", "금", "토"};
const char* const kWeekdaysFr[7] = {"dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."};
const char* const kWeekdaysEs[7] = {"dom", "lun", "mar", "mié", "jue", "vie", "sáb"};
const char* const kWeekdaysZh[7] = {"周日", "周一", "周二", "周三", "周四", "周五", "周六"};

const char* const* monthsFor(const std::string& lang) {
    if (lang == "en") return kMonthsEn;
    if (lang == "ja") return kMonthsJa;
    if (lang == "ko") return kMonthsKo;
    if (lang == "fr") return kMonthsFr;
    if (lang == "es") return kMonthsEs;
    return kMonthsZh;
}

const char* const* weekdaysFor(const std::string& lang) {
    if (lang == "en") return kWeekdaysEn;
    if (lang == "ja") return kWeekdaysJa;
    if (lang == "ko") return kWeekdaysKo;
    if (lang == "fr") return kWeekdaysFr;
    if (lang == "es") return kWeekdaysEs;
    return kWeekdaysZh;
}

std::string pad2(int v) {
    char buf[8];
    std::snprintf(buf, sizeof(buf), "%02d", v);
    return buf;
}

}  // namespace

std::string I18n::t(const std::string& lang, const char* key) {
    const Table& table = tableFor(lang);
    auto it = table.find(key);
    if (it != table.end() && !it->second.empty()) return it->second;
    static const Table& en = tableFor("en");
    auto fallback = en.find(key);
    if (fallback != en.end()) return fallback->second;
    return key;
}

std::string I18n::t(const std::string& lang, const char* key, const std::string& a) {
    std::string value = t(lang, key);
    replaceAll(value, "{0}", a);
    return value;
}

std::string I18n::t(const std::string& lang, const char* key, const std::string& a, const std::string& b) {
    std::string value = t(lang, key);
    replaceAll(value, "{0}", a);
    replaceAll(value, "{1}", b);
    return value;
}

std::string I18n::t(const std::string& lang, const char* key, int a) {
    return t(lang, key, std::to_string(a));
}

std::string I18n::t(const std::string& lang, const char* key, int a, const std::string& b) {
    return t(lang, key, std::to_string(a), b);
}

std::string I18n::dateShort(const std::string& lang, long long ts) {
    const DateParts p = localParts(ts);
    if (lang == "zh") return pad2(p.month) + "." + pad2(p.day);
    if (lang == "fr" || lang == "es") return pad2(p.day) + "/" + pad2(p.month);
    return pad2(p.month) + "/" + pad2(p.day);
}

std::string I18n::dateLong(const std::string& lang, long long ts) {
    const DateParts p = localParts(ts);
    const std::string month = monthsFor(lang)[p.month - 1];
    const std::string day = std::to_string(p.day);
    if (lang == "en") return month + " " + day;
    if (lang == "fr") return day + " " + month;
    if (lang == "es") return day + " de " + month;
    if (lang == "ko") return month + " " + day + "일";
    if (lang == "ja") return month + day + "日";
    return month + " " + day + " 日";
}

std::string I18n::weekday(const std::string& lang, long long ts) {
    return weekdaysFor(lang)[localParts(ts).weekday];
}

std::string I18n::locale(const std::string& lang) {
    for (const auto& option : kLanguages) {
        if (lang == option.code) return option.locale;
    }
    return "zh-CN";
}

std::string I18n::todayLabel(const std::string& lang, long long now) {
    const DateParts p = localParts(now);
    // Mirrors localizedToday(): Intl long date with the comma swapped for a dot.
    const std::string wd = weekdaysFor(lang)[p.weekday];
    const std::string month = monthsFor(lang)[p.month - 1];
    if (lang == "en") {
        return wd + ", " + month + " " + std::to_string(p.day) + ", " + std::to_string(p.year) +
               "  ·  " + wd;
    }
    if (lang == "ja") {
        return std::to_string(p.year) + "年" + std::to_string(p.month) + "月" + std::to_string(p.day) + "日" +
               "  ·  " + wd + "曜日";
    }
    if (lang == "ko") {
        return std::to_string(p.year) + "년 " + std::to_string(p.month) + "월 " + std::to_string(p.day) +
               "일  ·  " + wd + "요일";
    }
    if (lang == "fr") {
        return std::to_string(p.day) + " " + monthsFor(lang)[p.month - 1] + " " + std::to_string(p.year) +
               "  ·  " + wd;
    }
    if (lang == "es") {
        return std::to_string(p.day) + " de " + monthsFor(lang)[p.month - 1] + " de " +
               std::to_string(p.year) + "  ·  " + wd;
    }
    return std::to_string(p.year) + "年" + std::to_string(p.month) + "月" + std::to_string(p.day) + "日" +
           wd;
}

}  // namespace folio
