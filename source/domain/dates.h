#pragma once

#include <ctime>

namespace folio {

constexpr long long kDayMs = 86400000LL;

/** Local midnight for a timestamp, matching JS `new Date().setHours(0,0,0,0)`. */
long long startOfDay(long long ts);

/** startOfDay(ts) + days, respecting DST like Date#setDate does. */
long long addDays(long long ts, int days);

/** Whole calendar days between two timestamps (b - a), clamped to >= 0. */
int daysBetween(long long from, long long to);

struct DateParts {
    int year = 0;
    int month = 0;  // 1-based
    int day = 0;
    int weekday = 0;  // 0 = Sunday
    int hour = 0;
    int minute = 0;
    int second = 0;
};

DateParts localParts(long long ts);
/** Monday-first index for "this week" maths. */
int weekIndexMondayFirst(long long ts);

}  // namespace folio
