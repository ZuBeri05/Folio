// FSRS-6 scheduler, ported 1:1 from domain/fsrs/Fsrs.ts + Scheduling.ts.
#include "domain/fsrs.h"

#include <cmath>

#include "domain/dates.h"

namespace folio {

namespace {

// FSRS-6 default weights (same array as the HarmonyOS build).
const double W[21] = {0.212,  1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194,
                      0.001,  1.8722, 0.1666, 0.796,  1.4835, 0.0614, 0.2629,
                      1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542};

const double DECAY = -W[20];
const double FACTOR = std::pow(0.9, 1.0 / DECAY) - 1.0;

/** Overdue reviews stop accruing credit past this multiple of the planned interval. */
constexpr double kOverdueSlack = 1.5;

double clampd(double v, double lo, double hi) { return v < lo ? lo : (v > hi ? hi : v); }

int clampGrade(int grade) {
    const double g = clampd(static_cast<double>(grade), 1.0, 4.0);
    return static_cast<int>(std::lround(g));
}

bool isFiniteNumber(double v) { return std::isfinite(v); }

FsrsState clampState(const FsrsState& s) {
    FsrsState out;
    out.stability = clampd(s.stability, 0.1, 36500.0);
    out.difficulty = clampd(s.difficulty, 1.0, 10.0);
    out.state = (s.state == "new" || s.state == "learning" || s.state == "review" || s.state == "relearning")
                    ? s.state
                    : "review";
    out.lapses = s.lapses > 0 ? s.lapses : 0;
    out.scheduledDays = s.scheduledDays > 0 ? s.scheduledDays : 0;
    out.lastReviewedAt = s.lastReviewedAt;
    return out;
}

FsrsState initialState(int grade, long long now) {
    const int g = clampGrade(grade);
    FsrsState s;
    s.stability = W[g - 1];
    s.difficulty = clampd(W[4] - std::exp(W[5] * (g - 1)) + 1.0, 1.0, 10.0);
    s.state = g == 1 ? "learning" : "review";
    s.lapses = 0;
    s.scheduledDays = 0;
    s.lastReviewedAt = now;
    return s;
}

double nextDifficulty(double difficulty, int grade) {
    const double initialEasy = clampd(W[4] - std::exp(W[5] * 3.0) + 1.0, 1.0, 10.0);
    const double next = W[7] * initialEasy + (1.0 - W[7]) * (difficulty - W[6] * (grade - 3));
    return clampd(next, 1.0, 10.0);
}

double nextStability(const FsrsState& state, int grade, double elapsedDays) {
    const double r = fsrsRetrievability(state, elapsedDays);
    const double d = state.difficulty;
    const double s = state.stability;
    if (grade == 1) {
        return W[11] * std::pow(d, -W[12]) * (std::pow(s + 1.0, W[13]) - 1.0) * std::exp(W[14] * (1.0 - r));
    }
    const double hardFactor = grade == 2 ? W[15] : 1.0;
    const double easyFactor = grade == 4 ? W[16] : 1.0;
    const double growth = std::exp(W[8]) * (11.0 - d) * std::pow(s, -W[9]) *
                              (std::exp(W[10] * (1.0 - r)) - 1.0) * hardFactor * easyFactor +
                          1.0;
    return s * growth;
}

int intervalFor(double stability, double retention) {
    const double raw = stability / FACTOR * (std::pow(retention, 1.0 / DECAY) - 1.0);
    const double rounded = std::round(raw);
    return rounded < 1.0 ? 1 : static_cast<int>(rounded);
}

double safeRetention(double v) { return isFiniteNumber(v) ? clampd(v, 0.80, 0.95) : 0.90; }

int roundFsrsDays(double raw) {
    if (!isFiniteNumber(raw)) return 1;
    const double r = std::round(raw);
    return r < 1.0 ? 1 : static_cast<int>(r);
}

int safeDays(double v) { return isFiniteNumber(v) ? roundFsrsDays(v) : 1; }

int fixedIntervalFor(const StudyItem& item, int grade) {
    const int base = std::max(1, std::min(90, static_cast<int>(std::lround(static_cast<double>(item.fixedIntervalDays)))));
    if (grade == 1) return 1;
    if (grade == 2) return std::max(1, static_cast<int>(std::lround(base / 2.0)));
    if (grade == 4) return std::max(base + 1, static_cast<int>(std::lround(base * 1.5)));
    return base;
}

int capInterval(int days, int maxIntervalDays) {
    if (maxIntervalDays <= 0) return days;
    const int capped = std::min(days, std::max(1, maxIntervalDays));
    return capped;
}

/** Elapsed days with the overdue bonus capped at 1.5x the planned interval. */
double elapsedDaysFor(const StudyItem& item, long long now) {
    if (!isFiniteNumber(static_cast<double>(item.lastReviewedAt)) || item.lastReviewedAt <= 0) return 0.0;
    const double raw = std::max(0.0, std::round(static_cast<double>(startOfDay(now) - startOfDay(item.lastReviewedAt)) /
                                                static_cast<double>(kDayMs)));
    int planned = item.fsrsScheduledDays > 0 ? item.fsrsScheduledDays : item.currentIntervalDays;
    if (planned <= 0) return raw;
    const double capped = std::round(planned * kOverdueSlack);
    return std::min(raw, capped);
}

}  // namespace

double fsrsRetrievability(const FsrsState& state, double elapsedDays) {
    const double elapsed = std::max(0.0, elapsedDays);
    return std::pow(1.0 + FACTOR * elapsed / std::max(0.1, state.stability), DECAY);
}

FsrsState fsrsReview(const FsrsState& state, int grade, double elapsedDays, double retention, long long now) {
    const int g = clampGrade(grade);
    const double safe = safeRetention(retention);
    if (state.state == "new") {
        FsrsState base = initialState(g, now);
        const int interval = intervalFor(base.stability, safe);
        base.scheduledDays = interval;
        base.lastReviewedAt = now;
        return base;
    }
    const FsrsState base = clampState(state);
    const double stability = clampd(nextStability(base, g, elapsedDays), 0.1, 36500.0);
    const double difficulty = nextDifficulty(base.difficulty, g);
    const int interval = intervalFor(stability, safe);
    FsrsState out;
    out.stability = stability;
    out.difficulty = difficulty;
    out.state = g == 1 ? "relearning" : "review";
    out.lapses = base.lapses + (g == 1 ? 1 : 0);
    out.scheduledDays = interval;
    out.lastReviewedAt = now;
    return out;
}

std::vector<FsrsPreview> fsrsPreview(const FsrsState& state, double elapsedDays, double retention, long long now) {
    std::vector<FsrsPreview> out;
    for (int grade = 1; grade <= 4; ++grade) {
        const FsrsState next = fsrsReview(state, grade, elapsedDays, retention, now);
        out.push_back({grade, next.scheduledDays});
    }
    return out;
}

long long nextDueAt(long long now, int days) {
    const long long base = startOfDay(now);
    return addDays(base, std::max(1, days));
}

FsrsState fsrsStateFromItem(const StudyItem& item) {
    if (item.reviewCount <= 0) {
        FsrsState s;
        s.stability = 0.0;
        s.difficulty = 5.0;
        s.state = "new";
        s.lapses = 0;
        s.scheduledDays = 0;
        s.lastReviewedAt = item.lastReviewedAt;
        return s;
    }
    const int fallbackInterval = item.currentIntervalDays > 0 ? item.currentIntervalDays : 1;
    FsrsState s;
    s.stability = clampd(item.fsrsStability > 0.0 ? item.fsrsStability : roundFsrsDays(fallbackInterval), 0.1, 36500.0);
    s.difficulty = clampd(item.fsrsDifficulty, 1.0, 10.0);
    s.scheduledDays = item.fsrsScheduledDays > 0 ? item.fsrsScheduledDays : static_cast<int>(std::max(1.0, s.stability));
    s.state = (item.fsrsState == "learning" || item.fsrsState == "review" || item.fsrsState == "relearning")
                  ? item.fsrsState
                  : "review";
    s.lapses = item.fsrsLapses > 0 ? item.fsrsLapses : 0;
    s.lastReviewedAt = item.lastReviewedAt;
    return s;
}

FsrsScheduleResult scheduleFsrs(const StudyItem& item, int grade, long long now, double retention,
                                int maxIntervalDays) {
    const int safe = clampGrade(grade);
    FsrsScheduleResult r;
    r.curveStage = item.curveStage;
    r.rating = std::to_string(safe);
    if (item.scheduleMode == "fixed") {
        const int days = capInterval(fixedIntervalFor(item, safe), maxIntervalDays);
        r.nextAt = nextDueAt(now, days);
        r.nextIntervalDays = days;
        r.stability = item.fsrsStability;
        r.difficulty = item.fsrsDifficulty;
        r.state = item.reviewCount > 0 ? "review" : "new";
        r.lapses = item.fsrsLapses;
        r.scheduledDays = days;
        return r;
    }
    const FsrsState state = fsrsStateFromItem(item);
    const FsrsState reviewed = fsrsReview(state, safe, elapsedDaysFor(item, now), safeRetention(retention), now);
    const int days = capInterval(safeDays(reviewed.scheduledDays), maxIntervalDays);
    r.nextAt = nextDueAt(now, days);
    r.nextIntervalDays = days;
    r.stability = reviewed.stability;
    r.difficulty = reviewed.difficulty;
    r.state = reviewed.state;
    r.lapses = reviewed.lapses;
    r.scheduledDays = days;
    return r;
}

std::vector<int> previewForGrades(const StudyItem& item, long long now, double retention, int maxIntervalDays) {
    std::vector<int> out;
    if (item.scheduleMode == "fixed") {
        for (int grade = 1; grade <= 4; ++grade) {
            out.push_back(capInterval(fixedIntervalFor(item, grade), maxIntervalDays));
        }
        return out;
    }
    const FsrsState state = fsrsStateFromItem(item);
    const auto previews = fsrsPreview(state, elapsedDaysFor(item, now), safeRetention(retention), now);
    for (const auto& p : previews) {
        out.push_back(capInterval(safeDays(p.intervalDays), maxIntervalDays));
    }
    return out;
}

StudyItem postponeToTomorrow(const StudyItem& item, long long now) {
    StudyItem out = item;
    out.nextReviewAt = nextDueAt(now, 1);
    return out;
}

}  // namespace folio
