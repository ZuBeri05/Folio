#pragma once

#include <string>
#include <vector>

#include "domain/models.h"

namespace folio {

/** One FSRS-6 memory state, identical to Fsrs.ts. */
struct FsrsState {
    double stability = 0.0;
    double difficulty = 5.0;
    std::string state = "new";
    int lapses = 0;
    int scheduledDays = 0;
    long long lastReviewedAt = 0;
};

struct FsrsPreview {
    int grade = 3;
    int intervalDays = 1;
};

struct FsrsScheduleResult {
    long long nextAt = 0;
    int nextIntervalDays = 1;
    int curveStage = 0;
    std::string rating;
    double stability = 0.0;
    double difficulty = 5.0;
    std::string state = "new";
    int lapses = 0;
    int scheduledDays = 0;
};

double fsrsRetrievability(const FsrsState& state, double elapsedDays);
FsrsState fsrsReview(const FsrsState& state, int grade, double elapsedDays, double retention, long long now);
std::vector<FsrsPreview> fsrsPreview(const FsrsState& state, double elapsedDays, double retention, long long now);

/** "Due at midnight N days from now", the original nextDueAt(). */
long long nextDueAt(long long now, int days);

FsrsState fsrsStateFromItem(const StudyItem& item);
FsrsScheduleResult scheduleFsrs(const StudyItem& item, int grade, long long now, double retention,
                                int maxIntervalDays);
std::vector<int> previewForGrades(const StudyItem& item, long long now, double retention, int maxIntervalDays);
StudyItem postponeToTomorrow(const StudyItem& item, long long now);

}  // namespace folio
