#pragma once

#include <string>
#include <vector>

#include "domain/models.h"

namespace folio {

struct CycleSummary {
    int segments = 0;
    int minutes = 0;
    int itemCount = 0;
    int remembered = 0;
};

struct FocusSummary {
    int minutes = 0;
    int itemCount = 0;
    int remembered = 0;
};

/** "24:35" */
std::string formatClock(long long ms);

/** Rounds a finished segment: 1 minute minimum, 0 when shorter than a minute. */
FocusSummary summarize(long long startedAt, long long endedAt, const std::vector<ReviewLog>& logs);

int todayMinutes(const std::vector<FocusSession>& sessions, long long now);
int todayCount(const std::vector<FocusSession>& sessions, long long now);

/** Monday-first buckets of minutes for the current week. */
std::vector<int> weekBuckets(const std::vector<FocusSession>& sessions, long long now);

/** Splits minutes into {hours, minutes}. */
void durationParts(int minutes, int& hours, int& mins);

/** 5 minutes normally, 15 after every fourth round. */
int breakMinutesFor(int round);

CycleSummary cycleSummary(const std::vector<FocusSession>& sessions, long long since);

}  // namespace folio
