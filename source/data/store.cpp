#include "data/store.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <sys/stat.h>

#include "data/json.h"

namespace folio {

namespace {

std::string g_dir = "sdmc:/switch/folio";
std::string g_path = "sdmc:/switch/folio/data.json";

const Json& member(const Json& obj, const char* key) { return obj[key]; }

std::string readString(const Json& obj, const char* key, const std::string& fallback) {
    return member(obj, key).asString(fallback);
}

double readNumber(const Json& obj, const char* key, double fallback) {
    return member(obj, key).asNumber(fallback);
}

bool readBool(const Json& obj, const char* key, bool fallback) {
    return member(obj, key).asBool(fallback);
}

Json itemToJson(const StudyItem& item) {
    Json o = Json::object();
    o["id"] = Json::string(item.id);
    o["subjectId"] = Json::string(item.subjectId);
    o["title"] = Json::string(item.title);
    o["createdAt"] = Json::number(static_cast<double>(item.createdAt));
    o["scheduleMode"] = Json::string(item.scheduleMode);
    o["curveStage"] = Json::number(item.curveStage);
    o["fixedIntervalDays"] = Json::number(item.fixedIntervalDays);
    o["currentIntervalDays"] = Json::number(item.currentIntervalDays);
    o["nextReviewAt"] = Json::number(static_cast<double>(item.nextReviewAt));
    o["lastReviewedAt"] = Json::number(static_cast<double>(item.lastReviewedAt));
    o["reviewCount"] = Json::number(item.reviewCount);
    o["status"] = Json::string(item.status);
    o["fsrsStability"] = Json::number(item.fsrsStability);
    o["fsrsDifficulty"] = Json::number(item.fsrsDifficulty);
    o["fsrsState"] = Json::string(item.fsrsState);
    o["fsrsScheduledDays"] = Json::number(item.fsrsScheduledDays);
    o["fsrsLapses"] = Json::number(item.fsrsLapses);
    o["fsrsVersion"] = Json::number(item.fsrsVersion);
    return o;
}

StudyItem itemFromJson(const Json& o) {
    StudyItem item;
    item.id = readString(o, "id", "");
    item.subjectId = readString(o, "subjectId", "");
    item.title = readString(o, "title", "");
    item.createdAt = static_cast<long long>(readNumber(o, "createdAt", 0));
    item.scheduleMode = readString(o, "scheduleMode", "fsrs");
    item.curveStage = static_cast<int>(readNumber(o, "curveStage", 0));
    item.fixedIntervalDays = static_cast<int>(readNumber(o, "fixedIntervalDays", 3));
    item.currentIntervalDays = static_cast<int>(readNumber(o, "currentIntervalDays", 1));
    item.nextReviewAt = static_cast<long long>(readNumber(o, "nextReviewAt", 0));
    item.lastReviewedAt = static_cast<long long>(readNumber(o, "lastReviewedAt", 0));
    item.reviewCount = static_cast<int>(readNumber(o, "reviewCount", 0));
    item.status = readString(o, "status", "active");
    item.fsrsStability = readNumber(o, "fsrsStability", 0);
    item.fsrsDifficulty = readNumber(o, "fsrsDifficulty", 5);
    item.fsrsState = readString(o, "fsrsState", "new");
    item.fsrsScheduledDays = static_cast<int>(readNumber(o, "fsrsScheduledDays", 0));
    item.fsrsLapses = static_cast<int>(readNumber(o, "fsrsLapses", 0));
    item.fsrsVersion = static_cast<int>(readNumber(o, "fsrsVersion", 6));
    return item;
}

Json logToJson(const ReviewLog& log) {
    Json o = Json::object();
    o["id"] = Json::string(log.id);
    o["itemId"] = Json::string(log.itemId);
    o["reviewedAt"] = Json::number(static_cast<double>(log.reviewedAt));
    o["rating"] = Json::string(log.rating);
    o["previousIntervalDays"] = Json::number(log.previousIntervalDays);
    o["nextIntervalDays"] = Json::number(log.nextIntervalDays);
    o["nextReviewAt"] = Json::number(static_cast<double>(log.nextReviewAt));
    o["grade"] = Json::number(log.grade);
    o["stabilityBefore"] = Json::number(log.stabilityBefore);
    o["stabilityAfter"] = Json::number(log.stabilityAfter);
    o["difficultyBefore"] = Json::number(log.difficultyBefore);
    o["difficultyAfter"] = Json::number(log.difficultyAfter);
    o["elapsedDays"] = Json::number(log.elapsedDays);
    o["scheduledDays"] = Json::number(log.scheduledDays);
    return o;
}

ReviewLog logFromJson(const Json& o) {
    ReviewLog log;
    log.id = readString(o, "id", "");
    log.itemId = readString(o, "itemId", "");
    log.reviewedAt = static_cast<long long>(readNumber(o, "reviewedAt", 0));
    log.rating = readString(o, "rating", "");
    log.previousIntervalDays = static_cast<int>(readNumber(o, "previousIntervalDays", 0));
    log.nextIntervalDays = static_cast<int>(readNumber(o, "nextIntervalDays", 0));
    log.nextReviewAt = static_cast<long long>(readNumber(o, "nextReviewAt", 0));
    log.grade = static_cast<int>(readNumber(o, "grade", 0));
    log.stabilityBefore = readNumber(o, "stabilityBefore", 0);
    log.stabilityAfter = readNumber(o, "stabilityAfter", 0);
    log.difficultyBefore = readNumber(o, "difficultyBefore", 0);
    log.difficultyAfter = readNumber(o, "difficultyAfter", 0);
    log.elapsedDays = static_cast<int>(readNumber(o, "elapsedDays", 0));
    log.scheduledDays = static_cast<int>(readNumber(o, "scheduledDays", 0));
    return log;
}

Json sessionToJson(const FocusSession& s, bool includeActiveFields) {
    Json o = Json::object();
    o["id"] = Json::string(s.id);
    o["startedAt"] = Json::number(static_cast<double>(s.startedAt));
    o["endedAt"] = Json::number(static_cast<double>(s.endedAt));
    o["plannedMinutes"] = Json::number(s.plannedMinutes);
    o["minutes"] = Json::number(s.minutes);
    o["itemCount"] = Json::number(s.itemCount);
    o["remembered"] = Json::number(s.remembered);
    o["completed"] = Json::boolean(s.completed);
    if (includeActiveFields) {
        o["isBreak"] = Json::boolean(s.isBreak);
        o["round"] = Json::number(s.round);
        o["cycleStart"] = Json::number(static_cast<double>(s.cycleStart));
    }
    return o;
}

FocusSession sessionFromJson(const Json& o) {
    FocusSession s;
    s.id = readString(o, "id", "");
    s.startedAt = static_cast<long long>(readNumber(o, "startedAt", 0));
    s.endedAt = static_cast<long long>(readNumber(o, "endedAt", 0));
    s.plannedMinutes = static_cast<int>(readNumber(o, "plannedMinutes", 25));
    s.minutes = static_cast<int>(readNumber(o, "minutes", 0));
    s.itemCount = static_cast<int>(readNumber(o, "itemCount", 0));
    s.remembered = static_cast<int>(readNumber(o, "remembered", 0));
    s.completed = readBool(o, "completed", false);
    s.isBreak = readBool(o, "isBreak", false);
    s.round = static_cast<int>(readNumber(o, "round", 1));
    s.cycleStart = static_cast<long long>(readNumber(o, "cycleStart", 0));
    return s;
}

}  // namespace

bool Store::init() {
    // The preview harness (and any future tooling) can redirect the save file.
    if (const char* override = std::getenv("FOLIO_DATA_DIR")) {
        g_dir = override;
        g_path = g_dir + "/data.json";
    }
    mkdir("sdmc:/switch", 0777);
    mkdir(g_dir.c_str(), 0777);
    return true;
}

const std::string& Store::path() { return g_path; }

AppData fromJson(const std::string& text) {
    AppData data = createDefaultData();
    if (text.empty()) return data;
    bool ok = false;
    const Json root = Json::parse(text, &ok);
    if (!ok || !root.isObject()) return data;

    data.schemaVersion = static_cast<int>(readNumber(root, "schemaVersion", 2));
    data.subjects.clear();
    const Json& subjects = root["subjects"];
    for (const auto& s : subjects.items()) {
        Subject subject;
        subject.id = readString(s, "id", "");
        subject.name = readString(s, "name", "");
        subject.color = readString(s, "color", "#8D7F6C");
        if (!subject.id.empty()) data.subjects.push_back(subject);
    }
    if (data.subjects.empty()) data.subjects = createDefaultData().subjects;

    const Json& items = root["items"];
    for (const auto& i : items.items()) data.items.push_back(itemFromJson(i));
    const Json& logs = root["logs"];
    for (const auto& l : logs.items()) data.logs.push_back(logFromJson(l));
    const Json& sessions = root["focusSessions"];
    for (const auto& s : sessions.items()) data.focusSessions.push_back(sessionFromJson(s));

    const Json& active = root["activeFocus"];
    if (active.isObject()) {
        data.hasActiveFocus = true;
        data.activeFocus = sessionFromJson(active);
    } else {
        data.hasActiveFocus = false;
    }

    const Json& settings = root["settings"];
    if (settings.isObject()) {
        data.settings.reminderEnabled = readBool(settings, "reminderEnabled", true);
        data.settings.reminderTime = readString(settings, "reminderTime", "20:00");
        data.settings.themeIndex = static_cast<int>(readNumber(settings, "themeIndex", 0));
        data.settings.language = readString(settings, "language", "zh");
        data.settings.targetRetention = readNumber(settings, "targetRetention", 0.9);
        data.settings.maxIntervalDays = static_cast<int>(readNumber(settings, "maxIntervalDays", 180));
        data.settings.focusMinutes = static_cast<int>(readNumber(settings, "focusMinutes", 25));
        if (data.settings.focusMinutes < 1) data.settings.focusMinutes = 25;
    }
    return data;
}

AppData Store::load() {
    FILE* f = std::fopen(g_path.c_str(), "rb");
    if (f == nullptr) return createDefaultData();
    std::string text;
    char buffer[8192];
    size_t n = 0;
    while ((n = std::fread(buffer, 1, sizeof(buffer), f)) > 0) {
        text.append(buffer, n);
    }
    std::fclose(f);
    return fromJson(text);
}

bool Store::save(const AppData& data) {
    const std::string text = toJson(data);
    const std::string tmp = g_path + ".tmp";
    FILE* f = std::fopen(tmp.c_str(), "wb");
    if (f == nullptr) return false;
    const size_t written = std::fwrite(text.data(), 1, text.size(), f);
    std::fclose(f);
    if (written != text.size()) return false;
    std::remove(g_path.c_str());
    return std::rename(tmp.c_str(), g_path.c_str()) == 0;
}

std::string toJson(const AppData& data) {
    Json root = Json::object();
    root["schemaVersion"] = Json::number(data.schemaVersion);

    Json subjects = Json::array();
    for (const auto& s : data.subjects) {
        Json o = Json::object();
        o["id"] = Json::string(s.id);
        o["name"] = Json::string(s.name);
        o["color"] = Json::string(s.color);
        subjects.push(o);
    }
    root["subjects"] = subjects;

    Json items = Json::array();
    for (const auto& i : data.items) items.push(itemToJson(i));
    root["items"] = items;

    Json logs = Json::array();
    for (const auto& l : data.logs) logs.push(logToJson(l));
    root["logs"] = logs;

    Json sessions = Json::array();
    for (const auto& s : data.focusSessions) sessions.push(sessionToJson(s, false));
    root["focusSessions"] = sessions;

    if (data.hasActiveFocus) {
        root["activeFocus"] = sessionToJson(data.activeFocus, true);
    } else {
        root["activeFocus"] = Json();
    }

    Json settings = Json::object();
    settings["reminderEnabled"] = Json::boolean(data.settings.reminderEnabled);
    settings["reminderTime"] = Json::string(data.settings.reminderTime);
    settings["subjectTimes"] = Json::array();
    settings["themeIndex"] = Json::number(data.settings.themeIndex);
    settings["language"] = Json::string(data.settings.language);
    settings["targetRetention"] = Json::number(data.settings.targetRetention);
    settings["maxIntervalDays"] = Json::number(data.settings.maxIntervalDays);
    settings["focusMinutes"] = Json::number(data.settings.focusMinutes);
    root["settings"] = settings;

    return root.dump(2);
}

}  // namespace folio
