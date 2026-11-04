#pragma once

#include <string>
#include <vector>

namespace folio {

struct Subject {
    std::string id;
    std::string name;
    std::string color;  // "#RRGGBB"
};

struct StudyItem {
    std::string id;
    std::string subjectId;
    std::string title;
    long long createdAt = 0;
    std::string scheduleMode = "fsrs";
    int curveStage = 0;
    int fixedIntervalDays = 3;
    int currentIntervalDays = 1;
    long long nextReviewAt = 0;
    long long lastReviewedAt = 0;
    int reviewCount = 0;
    std::string status = "active";
    double fsrsStability = 0.0;
    double fsrsDifficulty = 5.0;
    std::string fsrsState = "new";
    int fsrsScheduledDays = 0;
    int fsrsLapses = 0;
    int fsrsVersion = 6;
};

struct ReviewLog {
    std::string id;
    std::string itemId;
    long long reviewedAt = 0;
    std::string rating;
    int previousIntervalDays = 0;
    int nextIntervalDays = 0;
    long long nextReviewAt = 0;
    int grade = 0;
    double stabilityBefore = 0.0;
    double stabilityAfter = 0.0;
    double difficultyBefore = 0.0;
    double difficultyAfter = 0.0;
    int elapsedDays = 0;
    int scheduledDays = 0;
};

/** One pomodoro segment. */
struct FocusSession {
    std::string id;
    long long startedAt = 0;
    long long endedAt = 0;
    int plannedMinutes = 25;
    int minutes = 0;
    int itemCount = 0;
    int remembered = 0;
    bool completed = false;
    bool isBreak = false;
    int round = 1;
    long long cycleStart = 0;
};

struct Settings {
    bool reminderEnabled = true;
    std::string reminderTime = "20:00";
    int themeIndex = 0;
    std::string language = "zh";
    double targetRetention = 0.9;
    int maxIntervalDays = 180;  // 0 = unlimited
    int focusMinutes = 25;
};

struct AppData {
    int schemaVersion = 2;
    std::vector<Subject> subjects;
    std::vector<StudyItem> items;
    std::vector<ReviewLog> logs;
    std::vector<FocusSession> focusSessions;
    bool hasActiveFocus = false;
    FocusSession activeFocus;
    Settings settings;
};

/** Palette the app picks from when adding a subject, in order. */
extern const char* const kSubjectColors[16];

std::string newId();
StudyItem emptyItem();
AppData createDefaultData();

}  // namespace folio
