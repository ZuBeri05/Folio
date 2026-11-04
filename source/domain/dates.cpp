#include "domain/dates.h"

#include <cmath>

namespace folio {

namespace {

std::tm toLocal(long long ts) {
    const time_t t = static_cast<time_t>(ts / 1000);
    std::tm out{};
    localtime_r(&t, &out);
    return out;
}

long long fromLocal(const std::tm& tm) {
    std::tm copy = tm;
    copy.tm_isdst = -1;
    return static_cast<long long>(mktime(&copy)) * 1000LL;
}

}  // namespace

long long startOfDay(long long ts) {
    std::tm tm = toLocal(ts);
    tm.tm_hour = 0;
    tm.tm_min = 0;
    tm.tm_sec = 0;
    return fromLocal(tm);
}

long long addDays(long long ts, int days) {
    std::tm tm = toLocal(ts);
    tm.tm_mday += days;
    tm.tm_isdst = -1;
    return fromLocal(tm);
}

int daysBetween(long long from, long long to) {
    const long long a = startOfDay(from);
    const long long b = startOfDay(to);
    const double days = std::round(static_cast<double>(b - a) / static_cast<double>(kDayMs));
    return days < 0 ? 0 : static_cast<int>(days);
}

DateParts localParts(long long ts) {
    const std::tm tm = toLocal(ts);
    DateParts p;
    p.year = tm.tm_year + 1900;
    p.month = tm.tm_mon + 1;
    p.day = tm.tm_mday;
    p.weekday = tm.tm_wday;
    p.hour = tm.tm_hour;
    p.minute = tm.tm_min;
    p.second = tm.tm_sec;
    return p;
}

int weekIndexMondayFirst(long long ts) {
    return (localParts(ts).weekday + 6) % 7;
}

}  // namespace folio
