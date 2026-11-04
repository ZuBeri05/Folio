// Behaviour layer: everything pages/Index.ets does besides painting.
#include <algorithm>
#include <cmath>
#include <cstdio>

#include "data/store.h"
#include "domain/dates.h"
#include "domain/focus.h"
#include "platform/platform.h"
#include "ui/app.h"

namespace folio {

namespace {

long long nowMs() { return Platform::nowMs(); }

const char* themeButtonHex(int themeIndex) {
    static const char* const accents[4] = {"#E8A21A", "#6E9BC5", "#D9826B", "#7FA88B"};
    if (themeIndex == 0) return "#FFC531";
    const int safe = (themeIndex >= 0 && themeIndex < 4) ? themeIndex : 0;
    return accents[safe];
}

}  // namespace

// ---------------------------------------------------------------- text i18n

std::string App::t(const char* key) const { return I18n::t(settings_.language, key); }
std::string App::t(const char* key, int a) const { return I18n::t(settings_.language, key, a); }
std::string App::t(const char* key, const std::string& a) const {
    return I18n::t(settings_.language, key, a);
}
std::string App::t(const char* key, const std::string& a, const std::string& b) const {
    return I18n::t(settings_.language, key, a, b);
}
std::string App::t(const char* key, int a, const std::string& b) const {
    return I18n::t(settings_.language, key, std::to_string(a), b);
}
std::string App::t(const char* key, const std::string& a, int b) const {
    return I18n::t(settings_.language, key, a, std::to_string(b));
}
std::string App::shortDate(long long ts) const { return I18n::dateShort(settings_.language, ts); }
std::string App::longDate(long long ts) const { return I18n::dateLong(settings_.language, ts); }
std::string App::weekday(long long ts) const { return I18n::weekday(settings_.language, ts); }

std::string App::navLabel(int index) const {
    static const char* keys[4] = {"navToday", "navRecords", "navCalendar", "navSettings"};
    const int safe = (index >= 0 && index < 4) ? index : 0;
    return t(keys[safe]);
}

// ---------------------------------------------------------------- lookups

const Subject& App::findSubject(const std::string& id) const {
    static const Subject fallback{"", "其他", "#8D7F6C"};
    for (const auto& s : subjects_) {
        if (s.id == id) return s;
    }
    return fallback;
}

Color App::colorOf(const std::string& hex, float alphaMul) const {
    return parseColor(hex.c_str(), alphaMul);
}

std::string App::subjectInk(const std::string& color) const {
    if (color.empty()) return "#3D2A00";
    const Color c = parseColor(color.c_str());
    return luminanceOf(c) >= 160.f ? "#3D2A00" : "#FFFFFF";
}

// ---------------------------------------------------------------- collections

std::vector<StudyItem> App::dueItems() const {
    const long long today = startOfDay(nowMs());
    std::vector<StudyItem> out;
    for (const auto& item : items_) {
        if (item.status == "active" && startOfDay(item.nextReviewAt) <= today) out.push_back(item);
    }
    std::sort(out.begin(), out.end(),
              [](const StudyItem& a, const StudyItem& b) { return a.nextReviewAt < b.nextReviewAt; });
    return out;
}

std::vector<StudyItem> App::sortedItems() const {
    std::vector<StudyItem> out = items_;
    std::sort(out.begin(), out.end(),
              [](const StudyItem& a, const StudyItem& b) { return a.createdAt > b.createdAt; });
    return out;
}

std::vector<StudyItem> App::todayCreatedItems() const {
    const long long today = startOfDay(nowMs());
    std::vector<StudyItem> out;
    for (const auto& item : items_) {
        if (startOfDay(item.createdAt) == today) out.push_back(item);
    }
    std::sort(out.begin(), out.end(),
              [](const StudyItem& a, const StudyItem& b) { return a.createdAt > b.createdAt; });
    return out;
}

std::vector<StudyItem> App::overdueItems() const {
    const long long today = startOfDay(nowMs());
    std::vector<StudyItem> out;
    for (const auto& item : items_) {
        if (item.status == "active" && startOfDay(item.nextReviewAt) < today) out.push_back(item);
    }
    return out;
}

int App::overdueDaysOf(const StudyItem& item) const {
    const long long due = startOfDay(item.nextReviewAt);
    const long long today = startOfDay(nowMs());
    if (due >= today) return 0;
    return std::max(1, daysBetween(due, nowMs()));
}

std::string App::oldestOverdueLabel() const {
    const auto list = overdueItems();
    if (list.empty()) return "";
    long long oldest = list[0].nextReviewAt;
    for (const auto& item : list) oldest = std::min(oldest, item.nextReviewAt);
    return shortDate(oldest);
}

std::vector<DayCount> App::upcoming() const {
    std::vector<DayCount> out;
    const long long base = startOfDay(nowMs());
    for (int i = 0; i < calendarDays_; ++i) {
        const long long day = addDays(base, i);
        int count = 0;
        for (const auto& item : items_) {
            if (item.status != "active") continue;
            const long long at = startOfDay(item.nextReviewAt);
            if (i == 0 ? at <= day : at == day) count += 1;
        }
        out.push_back({day, count});
    }
    return out;
}

std::vector<StudyItem> App::dayItems(long long day, bool isToday) const {
    std::vector<StudyItem> out;
    for (const auto& item : items_) {
        if (item.status != "active") continue;
        const long long at = startOfDay(item.nextReviewAt);
        if (isToday ? at <= day : at == day) out.push_back(item);
    }
    std::sort(out.begin(), out.end(),
              [](const StudyItem& a, const StudyItem& b) { return a.nextReviewAt < b.nextReviewAt; });
    return out;
}

std::string App::itemSubtitle(const StudyItem& item) const {
    const int late = overdueDaysOf(item);
    if (late > 0) return t("times", item.reviewCount) + "  ·  " + t("overdueDays", late);
    return t("times", item.reviewCount) + "  ·  " + t("next") + " " + shortDate(item.nextReviewAt);
}

// ---------------------------------------------------------------- palette

Color App::pageColors(int index, int slot) const {
    static const char* const palettes[4][4] = {
        {"#F7F2E4", "#F7F2E4", "#F7F2E4", "#F7F2E4"},
        {"#F7F2E4", "#F1F5F8", "#F2F5EE", "#F5F1F7"},
        {"#FBF3E9", "#F8F2EA", "#F4F4EA", "#F7F0F2"},
        {"#F4F5EC", "#EFF5F1", "#F1F6ED", "#F4F2EC"},
    };
    const int ti = (index >= 0 && index < 4) ? index : 0;
    const int si = (slot >= 0 && slot < 4) ? slot : 0;
    return parseColor(palettes[ti][si]);
}

Color App::themeAccent(int index) const {
    static const char* const accents[4] = {"#E8A21A", "#6E9BC5", "#D9826B", "#7FA88B"};
    const int safe = (index >= 0 && index < 4) ? index : 0;
    return parseColor(accents[safe]);
}

Color App::themeButton() const { return parseColor(themeButtonHex(settings_.themeIndex)); }

std::string App::themeInk() const { return subjectInk(themeButtonHex(settings_.themeIndex)); }

Color App::pageBg() const {
    const int index = (tab_ >= 0 && tab_ < 4) ? tab_ : 0;
    return pageColors(settings_.themeIndex, index);
}

// ---------------------------------------------------------------- grade copy

Color App::gradeColor(int grade) const {
    if (grade == 1) return parseColor("#D95F3F");
    if (grade == 2) return parseColor("#B17A12");
    if (grade == 3) return parseColor("#8F5600");
    return parseColor("#5AA469");
}

Color App::gradeTint(int grade, const char* alpha) const {
    const Color c = gradeColor(grade);
    return Color(c.r, c.g, c.b, parseColor(alpha).a);
}

std::string App::gradeLabel(int grade) const {
    if (grade == 1) return t("gradeAgain");
    if (grade == 2) return t("gradeHard");
    if (grade == 3) return t("gradeGood");
    return t("gradeEasy");
}

std::string App::gradeMeaning(int grade) const {
    if (grade == 1) return t("gradeAgainHint");
    if (grade == 2) return t("gradeHardHint");
    if (grade == 3) return t("gradeGoodHint");
    return t("gradeEasyHint");
}

std::string App::intervalText(int days) const {
    return days == 1 ? t("tomorrow") : t("daysAfter", days);
}

std::string App::gradeIntervalText(int grade) const {
    const int index = grade - 1;
    const int days = (index >= 0 && index < static_cast<int>(gradePreviewDays_.size())) ? gradePreviewDays_[index] : 1;
    return intervalText(days);
}

std::string App::legacyRating(int grade) const {
    if (grade == 1) return "forgot";
    if (grade == 2) return "fuzzy";
    return "got";
}

int App::reviewElapsedDays(const StudyItem& item, long long now) const {
    if (item.lastReviewedAt <= 0) return 0;
    return daysBetween(item.lastReviewedAt, now);
}

// ---------------------------------------------------------------- focus copy

int App::tickCount() const {
    const int minutes = focusRunning_ ? focusPlannedMinutes_ : settings_.focusMinutes;
    return std::max(1, std::min(90, minutes));
}

int App::elapsedMinutes() const {
    if (!focusRunning_) return 0;
    const long long total = static_cast<long long>(focusPlannedMinutes_) * 60000;
    const long long passed = (total - std::max(0LL, focusRemainingMs_)) / 60000;
    const int clamped = static_cast<int>(std::max(0LL, passed));
    return std::min(tickCount(), clamped);
}

float App::tickOpacity(int index) const { return index < elapsedMinutes() ? 0.14f : 0.55f; }

float App::focusRemainingPercent() const {
    const long long total = static_cast<long long>(focusPlannedMinutes_) * 60000;
    if (total <= 0) return 100.f;
    const long long left = std::max(0LL, std::min(total, focusRemainingMs_));
    return static_cast<float>(left) / static_cast<float>(total) * 100.f;
}

std::string App::focusClockText() const { return formatClock(focusRemainingMs_); }

std::string App::elapsedClockText() const {
    const long long total = static_cast<long long>(focusPlannedMinutes_) * 60000;
    return formatClock(std::max(0LL, total - focusRemainingMs_));
}

Color App::clockAccent() const {
    if (!focusRunning_) return parseColor("#FFC4B2");
    if (focusPaused_) return tokens::color(tokens::mutedSoft);
    return focusIsBreak_ ? tokens::color(tokens::blue) : tokens::color(tokens::coral);
}

float App::clockSize() const {
    const float w = vpWidth_ > 0.f ? vpWidth_ : 360.f;
    const float h = vpHeight_ > 0.f ? vpHeight_ : 720.f;
    const float shortSide = std::min(w, h);
    const float room = h - 170.f;
    return std::max(150.f, std::min(430.f, std::min(shortSide * 0.66f, room)));
}

std::string App::roundLabel() const {
    const std::string phase = focusIsBreak_ ? t("focusBreaking") : t("focusRunning");
    return t("focusRound", focusRound_) + " · " + phase;
}

std::string App::minutesLabel(int minutes) const {
    int hours = 0;
    int mins = 0;
    durationParts(minutes, hours, mins);
    if (hours <= 0) return t("minutesShort", mins);
    if (mins == 0) return t("hoursShort", hours);
    return t("hoursShort", hours) + " " + t("minutesShort", mins);
}

int App::todayFocusMinutes() const { return todayMinutes(doneSessions_, nowMs()); }
int App::todayFocusCount() const { return todayCount(doneSessions_, nowMs()); }
std::vector<int> App::weekFocus() const { return weekBuckets(doneSessions_, nowMs()); }

int App::weekBarHeight(int minutes) const {
    if (minutes <= 0) return 3;
    const auto buckets = weekFocus();
    int max = 0;
    for (int v : buckets) max = std::max(max, v);
    const int denom = std::max(30, max);
    return std::max(6, static_cast<int>(std::lround(static_cast<double>(minutes) / denom * 38.0)));
}

long long App::weekDayTs(int index) const {
    const long long now = nowMs();
    const int weekdayIndex = weekIndexMondayFirst(now);
    return startOfDay(now) + static_cast<long long>(index - weekdayIndex) * kDayMs;
}

int App::todayWeekIndex() const { return weekIndexMondayFirst(nowMs()); }

std::string App::clockLabel(long long ts) const {
    const DateParts p = localParts(ts);
    char buf[8];
    std::snprintf(buf, sizeof(buf), "%02d:%02d", p.hour, p.minute);
    return buf;
}

std::string App::curveDotLabel(int index) const {
    if (index == 0) return t("todayNode");
    StudyItem cursor = emptyItem();
    cursor.scheduleMode = "fsrs";
    long long at = nowMs();
    for (int i = 0; i < index; ++i) {
        const FsrsScheduleResult result = scheduleFsrs(cursor, 3, at, settings_.targetRetention,
                                                       settings_.maxIntervalDays);
        if (i == index - 1) return t("days", result.nextIntervalDays);
        cursor.scheduleMode = "fsrs";
        cursor.reviewCount += 1;
        cursor.lastReviewedAt = at;
        cursor.fsrsStability = result.stability;
        cursor.fsrsDifficulty = result.difficulty;
        cursor.fsrsState = result.state;
        cursor.fsrsScheduledDays = result.scheduledDays;
        cursor.fsrsLapses = result.lapses;
        cursor.currentIntervalDays = result.nextIntervalDays;
        at = result.nextAt;
    }
    return t("todayNode");
}

}  // namespace folio