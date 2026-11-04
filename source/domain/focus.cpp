#include "domain/focus.h"

#include <cmath>
#include <cstdio>

#include "domain/dates.h"

namespace folio {

std::string formatClock(long long ms) {
    long long totalSeconds = (ms + 999) / 1000;  // Math.ceil(ms / 1000)
    if (totalSeconds < 0) totalSeconds = 0;
    const long long minutes = totalSeconds / 60;
    const long long seconds = totalSeconds % 60;
    char buf[32];
    std::snprintf(buf, sizeof(buf), "%02lld:%02lld", minutes, seconds);
    return buf;
}

FocusSummary summarize(long long startedAt, long long endedAt, const std::vector<ReviewLog>& logs) {
    FocusSummary out;
    for (const auto& log : logs) {
        if (log.reviewedAt >= startedAt && log.reviewedAt <= endedAt) {
            out.itemCount += 1;
            if (log.grade >= 3) out.remembered += 1;
        }
    }
    const double rawMinutes = static_cast<double>(endedAt - startedAt) / 60000.0;
    out.minutes = rawMinutes < 1.0 ? 0 : std::max(1, static_cast<int>(std::lround(rawMinutes)));
    return out;
}

int todayMinutes(const std::vector<FocusSession>& sessions, long long now) {
    const long long from = startOfDay(now);
    const long long to = addDays(from, 1);
    int total = 0;
    for (const auto& s : sessions) {
        if (s.startedAt >= from && s.startedAt < to) total += s.minutes;
    }
    return total;
}

int todayCount(const std::vector<FocusSession>& sessions, long long now) {
    const long long from = startOfDay(now);
    const long long to = addDays(from, 1);
    int count = 0;
    for (const auto& s : sessions) {
        if (s.startedAt >= from && s.startedAt < to) count += 1;
    }
    return count;
}

std::vector<int> weekBuckets(const std::vector<FocusSession>& sessions, long long now) {
    std::vector<int> buckets(7, 0);
    const long long today = startOfDay(now);
    const long long monday = addDays(today, -weekIndexMondayFirst(now));
    for (const auto& s : sessions) {
        const long long day = startOfDay(s.startedAt);
        const int index = static_cast<int>(std::lround(static_cast<double>(day - monday) / kDayMs));
        if (index >= 0 && index < 7) buckets[index] += s.minutes;
    }
    return buckets;
}

void durationParts(int minutes, int& hours, int& mins) {
    const int safe = minutes > 0 ? minutes : 0;
    hours = safe / 60;
    mins = safe % 60;
}

int breakMinutesFor(int round) {
    const int safe = round > 0 ? round : 1;
    return safe % 4 == 0 ? 15 : 5;
}

CycleSummary cycleSummary(const std::vector<FocusSession>& sessions, long long since) {
    CycleSummary out;
    for (const auto& s : sessions) {
        if (s.startedAt < since) continue;
        out.segments += 1;
        out.minutes += s.minutes;
        out.itemCount += s.itemCount;
        out.remembered += s.remembered;
    }
    return out;
}

}  // namespace folio
