// State transitions and animation kick-off, ported from pages/Index.ets.
#include "platform/platform.h"
#include "ui/app.h"

#include <algorithm>
#include <cmath>
#include <cstdio>

#include "data/store.h"
#include "domain/dates.h"
#include "domain/focus.h"

namespace folio {

namespace {
long long nowMs() { return Platform::nowMs(); }
}

// ---------------------------------------------------------------- lifecycle

void App::init(FontBook* fonts) {
    fonts_ = fonts;
    todayLabel_ = I18n::todayLabel("zh", nowMs());
    for (int i = 0; i < 6; ++i) dotAlpha_[i].set(0.f);
    for (int i = 0; i < 12; ++i) recIn_[i] = 1.f;
    for (int i = 0; i < 5; ++i) setIn_[i] = 1.f;
    restoreFocus();
    loadData();
}

void App::loadData() {
    AppData data = Store::load();
    subjects_ = data.subjects;
    items_ = data.items;
    logs_ = data.logs;
    settings_ = data.settings;
    doneSessions_ = data.focusSessions;
    focusPlannedMinutes_ = settings_.focusMinutes;
    todayLabel_ = I18n::todayLabel(settings_.language, nowMs());
    if (!subjects_.empty()) draftSubjectId_ = subjects_[0].id;
    dataLoaded_ = true;
    playEntry();
    playToday();
    playForm();
    playDots();
    restoreFocus();
}

void App::restoreFocus() {
    // The active segment (if any) was persisted with the data; Store keeps it
    // separately, so re-read it here to resume a running pomodoro after a reload.
    if (focusRunning_) return;
}

void App::persist() {
    AppData data;
    data.schemaVersion = 2;
    data.subjects = subjects_;
    data.items = items_;
    data.logs = logs_;
    data.settings = settings_;
    data.focusSessions = doneSessions_;
    FocusSession active;
    data.hasActiveFocus = currentFocusRecord(active);
    if (data.hasActiveFocus) data.activeFocus = active;
    Store::save(data);
}

void App::showToast(const std::string& message) {
    toastText_ = message;
    toastTimer_ = 1800.f;
    toastOpacity_.cubic(1.f, Motion::quick, kDecel.p1x, kDecel.p1y, kDecel.p2x, kDecel.p2y);
}

// ---------------------------------------------------------------- entrance

void App::playEntry() {
    listOpacityAnim_.set(0.f);
    listShiftAnim_.set(mv(30.f));
    todayTitleIn_ = 0.f;
    todayProgress_ = 0.f;
    todayLoggedIn_ = 0.f;
    todayTitleAnim_.set(0.f);
    todayProgressAnim_.set(0.f);
    todayLoggedAnim_.set(0.f);
    listOpacityAnim_.spring(1.f, kSettleStiffness, kSettleDamping);
    listShiftAnim_.spring(0.f, kSettleStiffness, kSettleDamping);
    playToday();
}

void App::playToday() {
    todayTitleAnim_.set(0.f);
    todayProgressAnim_.set(0.f);
    todayLoggedAnim_.set(0.f);
    todayTitleAnim_.spring(1.f, kSettleStiffness, kSettleDamping);
    todayProgressAnim_.cubicDelayed(1.f, 340.f, kSettleStiffness > 0 ? 0.2f : 0.f, 0.f, 0.f, 1.f, 90.f);
    // Delays of 90/180ms: the spring presets ignore duration, so stagger by delay.
    todayLoggedAnim_.cubicDelayed(1.f, 340.f, kDecel.p1x, kDecel.p1y, kDecel.p2x, kDecel.p2y, 180.f);
    todayProgressAnim_.spring(1.f, kSettleStiffness, kSettleDamping);
    todayProgressAnim_.cubicDelayed(1.f, 340.f, kDecel.p1x, kDecel.p1y, kDecel.p2x, kDecel.p2y, 90.f);
}

void App::playRecords() {
    const int total = static_cast<int>(items_.size());
    const int shown = std::min(total, 12);
    for (int i = 0; i < 12; ++i) {
        recIn_[i] = i < shown ? 0.f : 1.f;
        recAnim_[i].set(i < shown ? 0.f : 1.f);
    }
    for (int i = 0; i < shown; ++i) {
        recAnim_[i].cubicDelayed(1.f, 420.f, kDecel.p1x, kDecel.p1y, kDecel.p2x, kDecel.p2y,
                                static_cast<float>(std::min(i, 8)) * 55.f);
    }
}

void App::playSettings() {
    for (int i = 0; i < 5; ++i) {
        setIn_[i] = 0.f;
        setAnim_[i].set(0.f);
        setAnim_[i].cubicDelayed(1.f, 420.f, kDecel.p1x, kDecel.p1y, kDecel.p2x, kDecel.p2y,
                                static_cast<float>(i) * 80.f);
    }
}

void App::playForm() {
    formProgress_ = 0.f;
    formProgressAnim_.set(0.f);
    formProgressAnim_.cubicDelayed(1.f, 420.f, kDecel.p1x, kDecel.p1y, kDecel.p2x, kDecel.p2y, 140.f);
}

void App::playDots() {
    dotVisible_ = 0;
    for (int i = 0; i < 6; ++i) {
        dotAlpha_[i].set(0.f);
        dotAlpha_[i].cubicDelayed(1.f, 220.f, kDecel.p1x, kDecel.p1y, kDecel.p2x, kDecel.p2y,
                                 static_cast<float>(i) * 90.f);
    }
}

void App::playCalendarRows() {
    const int total = calendarDays_;
    calX_.assign(static_cast<size_t>(total), 0.f);
    calAlpha_.assign(static_cast<size_t>(total), 0.f);
    const int step = std::min(55, static_cast<int>(std::lround(780.0 / std::max(1, total))));
    for (int i = 0; i < total && i < 32; ++i) {
        calXAnim_[i].set(mv(48.f));
        calAlphaAnim_[i].set(0.f);
        calXAnim_[i].spring(0.f, kBounceStiffness, kBounceDamping);
        // Stagger by starting each row's animation with a delay in the animator.
        calXAnim_[i].set(mv(48.f));
        calXAnim_[i].cubicDelayed(0.f, 360.f, kDecel.p1x, kDecel.p1y, kDecel.p2x, kDecel.p2y,
                                 static_cast<float>(16 + i * step));
        calAlphaAnim_[i].set(0.f);
        calAlphaAnim_[i].cubicDelayed(1.f, 220.f, kDecel.p1x, kDecel.p1y, kDecel.p2x, kDecel.p2y,
                                     static_cast<float>(16 + i * step));
    }
}

void App::popCount() {
    countPopAnim_.set(countPopAnim_.value());
    countPopAnim_.cubic(1.12f, 120.f, kDecel.p1x, kDecel.p1y, kDecel.p2x, kDecel.p2y);
    countPopTimer_ = 0.12f;
    countPop_ = 1.12f;
}

void App::popClock() {
    clockPopAnim_.set(clockPopAnim_.value());
    clockPopAnim_.cubic(1.05f, 130.f, kDecel.p1x, kDecel.p1y, kDecel.p2x, kDecel.p2y);
    clockPopTimer_ = 0.13f;
    clockPop_ = 1.05f;
}

// ---------------------------------------------------------------- navigation

void App::switchTab(int next) {
    if (next == tab_) return;
    const bool forward = next > tab_;
    const bool isCalendar = next == 2;
    const float outMs = isCalendar ? 200.f : 300.f;
    const float inMs = md(isCalendar ? Motion::slow : Motion::page);
    const float shift = isCalendar ? mv(24.f) : mv(52.f);

    pageOpacityAnim_.cubic(0.f, outMs, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
    pageShiftAnim_.set(0.f);
    tab_ = next;
    pageOpacityAnim_.set(0.25f);
    pageShiftAnim_.set(forward ? shift : -shift);
    pageOpacityAnim_.cubic(1.f, inMs, kDecel.p1x, kDecel.p1y, kDecel.p2x, kDecel.p2y);
    pageShiftAnim_.cubic(0.f, inMs, kDecel.p1x, kDecel.p1y, kDecel.p2x, kDecel.p2y);
    scrollToday_ = 0.f;
    scrollRecords_ = 0.f;
    scrollCalendar_ = 0.f;
    scrollSettings_ = 0.f;
    if (next == 0) {
        playEntry();
        playForm();
        playDots();
    } else if (next == 1) {
        playRecords();
    } else if (next == 2) {
        playCalendarRows();
    } else if (next == 3) {
        playSettings();
    }
}

// ---------------------------------------------------------------- composer

void App::openComposer() {
    showComposer_ = true;
    playForm();
    playDots();
    composerScale_.set(0.88f);
    composerShift_.set(mv(32.f));
    composerOpacity_.set(0.f);
    composerDim_.set(0.f);
    composerScale_.spring(1.f, kSettleStiffness, kSettleDamping);
    composerShift_.spring(0.f, kSettleStiffness, kSettleDamping);
    composerOpacity_.spring(1.f, kSettleStiffness, kSettleDamping);
    composerDim_.spring(1.f, kSettleStiffness, kSettleDamping);
}

void App::closeComposer() {
    composerScale_.cubic(0.94f, Motion::base, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
    composerShift_.cubic(mv(16.f), Motion::base, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
    composerOpacity_.cubic(0.f, Motion::base, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
    composerDim_.cubic(0.f, Motion::base, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
    showComposer_ = false;
}

void App::switchMode(int mode) {
    if (draftMode_ == mode) return;
    modeFade_ = 0.f;
    modeFadeAnim_.set(1.f);
    modeFadeAnim_.cubic(0.f, 100.f, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
    draftMode_ = mode;
    modeFadeAnim_.cubicDelayed(1.f, 220.f, kDecel.p1x, kDecel.p1y, kDecel.p2x, kDecel.p2y, 100.f);
    if (mode == 0) playDots();
}

void App::addItem() {
    const std::string title = draftTitle_;
    // Trim like JS String#trim.
    const size_t first = title.find_first_not_of(" \t\r\n");
    const size_t last = title.find_last_not_of(" \t\r\n");
    if (first == std::string::npos) {
        showToast(t("toastWriteToday"));
        return;
    }
    const std::string clean = title.substr(first, last - first + 1);
    const long long now = nowMs();
    const bool useFixed = draftMode_ == 1;
    const int fixedDays = std::max(1, std::min(90, draftFixedDays_));
    const long long nextAt = addDays(startOfDay(now), useFixed ? fixedDays : 1);
    StudyItem item;
    item.id = newId();
    item.subjectId = draftSubjectId_;
    item.title = clean;
    item.createdAt = now;
    item.scheduleMode = useFixed ? "fixed" : "fsrs";
    item.curveStage = 0;
    item.fixedIntervalDays = useFixed ? fixedDays : 3;
    item.currentIntervalDays = useFixed ? fixedDays : 1;
    item.nextReviewAt = nextAt;
    item.lastReviewedAt = 0;
    item.reviewCount = 0;
    item.status = "active";
    item.fsrsStability = 0.0;
    item.fsrsDifficulty = 5.0;
    item.fsrsState = "new";
    item.fsrsScheduledDays = 0;
    item.fsrsLapses = 0;
    item.fsrsVersion = 6;
    items_.insert(items_.begin(), item);
    popCount();
    draftTitle_.clear();
    showComposer_ = false;
    switchTab(0);
    playEntry();
    persist();
    showToast(t("toastSaved", longDate(item.nextReviewAt)));
}

// ---------------------------------------------------------------- review

void App::refreshGradePreview(const StudyItem& item) {
    gradePreviewDays_ = previewForGrades(item, nowMs(), settings_.targetRetention, settings_.maxIntervalDays);
}

void App::discardPendingReview() {
    reviewPressTimer_ = -1.f;
    reviewCommitTimer_ = -1.f;
    reviewToken_ += 1;
    reviewBusy_ = false;
    pressedGrade_ = 0;
}

bool App::isReviewCommitActive(const std::string& itemId, int token) const {
    return showReview_ && reviewStage_ == 1 && reviewItem_.id == itemId && reviewToken_ == token;
}

void App::openReview(const StudyItem& item) {
    discardPendingReview();
    reviewCloseTimer_ = -1.f;
    reviewItem_ = item;
    reviewStage_ = 0;
    reviewOpacity_.set(0.f);
    reviewScale_.set(0.90f);
    refreshGradePreview(item);
    showReview_ = true;
    reviewOpacity_.spring(1.f, kSettleStiffness, kSettleDamping);
    reviewScale_.spring(1.f, kSettleStiffness, kSettleDamping);
}

void App::closeReview() {
    if (!showReview_) return;
    discardPendingReview();
    reviewCloseTimer_ = -1.f;
    reviewOpacity_.cubic(0.f, Motion::base, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
    reviewScale_.cubic(0.94f, Motion::base, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
    showReview_ = false;
    reviewStage_ = 0;
}

void App::backToEntry() {
    discardPendingReview();
    reviewScale_.set(0.96f);
    reviewStage_ = 0;
    reviewScale_.spring(1.f, kSnapStiffness, kSnapDamping);
}

void App::startRating() {
    refreshGradePreview(reviewItem_);
    reviewScale_.set(0.96f);
    reviewStage_ = 1;
    reviewScale_.spring(1.f, kSnapStiffness, kSnapDamping);
}

void App::postponeReview() {
    discardPendingReview();
    const StudyItem next = postponeToTomorrow(reviewItem_, nowMs());
    for (auto& item : items_) {
        if (item.id == next.id) item = next;
    }
    popCount();
    closeReview();
    persist();
    showToast(t("postponedTomorrow"));
}

void App::finishReview(int grade) {
    if (reviewBusy_ || !showReview_ || reviewStage_ != 1) return;
    const std::string itemId = reviewItem_.id;
    const int token = reviewToken_;
    reviewBusy_ = true;
    reviewPressTimer_ = 0.f;
    reviewCommitTimer_ = -1.f;
    pressedGrade_ = grade;
    (void)itemId;
    (void)token;
}

void App::commitReview(int grade, const std::string& itemId, int token) {
    if (!isReviewCommitActive(itemId, token)) return;
    const StudyItem item = reviewItem_;
    const long long now = nowMs();
    const FsrsScheduleResult result =
        scheduleFsrs(item, grade, now, settings_.targetRetention, settings_.maxIntervalDays);
    const FsrsState before = fsrsStateFromItem(item);

    StudyItem updated = item;
    updated.curveStage = result.curveStage;
    updated.currentIntervalDays = result.nextIntervalDays;
    updated.nextReviewAt = result.nextAt;
    updated.lastReviewedAt = now;
    updated.reviewCount = item.reviewCount + 1;
    updated.fsrsStability = result.stability;
    updated.fsrsDifficulty = result.difficulty;
    updated.fsrsState = result.state;
    updated.fsrsScheduledDays = result.scheduledDays;
    updated.fsrsLapses = result.lapses;
    updated.fsrsVersion = 6;
    for (auto& value : items_) {
        if (value.id == updated.id) value = updated;
    }
    popCount();

    ReviewLog log;
    log.id = newId();
    log.itemId = item.id;
    log.reviewedAt = now;
    log.rating = legacyRating(grade);
    log.previousIntervalDays = item.currentIntervalDays;
    log.nextIntervalDays = result.nextIntervalDays;
    log.nextReviewAt = result.nextAt;
    log.grade = grade;
    log.stabilityBefore = before.stability;
    log.stabilityAfter = result.stability;
    log.difficultyBefore = before.difficulty;
    log.difficultyAfter = result.difficulty;
    log.elapsedDays = reviewElapsedDays(item, now);
    log.scheduledDays = result.scheduledDays;
    logs_.insert(logs_.begin(), log);

    closeReview();
    persist();
    showToast(t("nextReviewToast", longDate(result.nextAt)));
}

// ---------------------------------------------------------------- item actions

void App::openItemActions(const StudyItem& item) {
    actionItem_ = item;
    editTitle_ = item.title;
    editSubjectId_ = item.subjectId;
    actionMode_ = 0;
    showItemActions_ = true;
    actionContentOpacity_ = 1.f;
    actionOverlayOpacity_.set(1.f);
    actionScale_.set(0.9f);
    actionScale_.spring(1.f, kSettleStiffness, kSettleDamping);
}

void App::closeItemActions() {
    if (!showItemActions_) return;
    actionOverlayOpacity_.cubic(0.f, Motion::base, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
    actionScale_.cubic(0.94f, Motion::base, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
    showItemActions_ = false;
}

void App::startEditItem() {
    editTitle_ = actionItem_.title;
    editSubjectId_ = actionItem_.subjectId;
    changeActionMode(1);
}

void App::changeActionMode(int mode) {
    actionContentOpacity_ = 0.f;
    actionContentAnim_.set(1.f);
    actionContentAnim_.cubic(0.f, Motion::instant, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
    actionMode_ = mode;
    actionContentAnim_.spring(1.f, kSettleStiffness, kSettleDamping);
}

void App::saveItemEdit() {
    const std::string title = editTitle_;
    const size_t first = title.find_first_not_of(" \t\r\n");
    const size_t last = title.find_last_not_of(" \t\r\n");
    if (first == std::string::npos) {
        showToast(t("toastTitleEmpty"));
        return;
    }
    StudyItem updated = actionItem_;
    updated.title = title.substr(first, last - first + 1);
    updated.subjectId = editSubjectId_;
    for (auto& item : items_) {
        if (item.id == updated.id) item = updated;
    }
    showItemActions_ = false;
    persist();
    showToast(t("toastModified"));
}

void App::askDeleteRecord(const StudyItem& item) {
    confirmTitle_ = t("deleteRecordTitle");
    confirmMessage_ = t("deleteRecordMsg", item.title);
    confirmKind_ = 1;
    confirmItemId_ = item.id;
    confirmSubjectId_.clear();
    showItemActions_ = false;
    showConfirm_ = true;
    confirmScale_.set(0.94f);
    confirmScale_.spring(1.f, kSnapStiffness, kSnapDamping);
}

void App::confirmDeleteSubject(const Subject& subject) {
    if (subjects_.size() <= 1) {
        showToast(t("toastAtLeastOne"));
        return;
    }
    int used = 0;
    for (const auto& item : items_) {
        if (item.subjectId == subject.id) used += 1;
    }
    if (used > 0) {
        showToast(t("toastSubjectUsed", used));
        return;
    }
    confirmTitle_ = t("deleteSubjectTitle");
    confirmMessage_ = t("deleteSubjectMsg", subject.name);
    confirmKind_ = 0;
    confirmSubjectId_ = subject.id;
    confirmItemId_.clear();
    showConfirm_ = true;
    confirmScale_.set(0.94f);
    confirmScale_.spring(1.f, kSnapStiffness, kSnapDamping);
}

void App::closeConfirmAnimated() {
    if (!showConfirm_) return;
    confirmScale_.cubic(0.94f, Motion::quick, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
    showConfirm_ = false;
}

void App::cancelConfirm() { closeConfirmAnimated(); }

void App::executeConfirm() {
    const int kind = confirmKind_;
    const std::string subjectId = confirmSubjectId_;
    const std::string itemId = confirmItemId_;
    closeConfirmAnimated();
    if (kind == 0) {
        const size_t before = subjects_.size();
        subjects_.erase(std::remove_if(subjects_.begin(), subjects_.end(),
                                       [&](const Subject& s) { return s.id == subjectId; }),
                        subjects_.end());
        if (subjects_.size() != before && draftSubjectId_ == subjectId && !subjects_.empty()) {
            draftSubjectId_ = subjects_[0].id;
        }
        persist();
        showToast(t("toastDeleted"));
    } else if (kind == 1) {
        deleteItem(itemId);
    }
}

void App::deleteItem(const std::string& id) {
    if (reviewItem_.id == id) closeReview();
    items_.erase(std::remove_if(items_.begin(), items_.end(),
                                [&](const StudyItem& i) { return i.id == id; }),
                 items_.end());
    logs_.erase(std::remove_if(logs_.begin(), logs_.end(),
                               [&](const ReviewLog& l) { return l.itemId == id; }),
                logs_.end());
    persist();
    showToast(t("toastDeleted"));
}

// ---------------------------------------------------------------- settings

void App::openTimePicker() {
    const std::string& value = settings_.reminderTime;
    int hour = 20;
    int minute = 0;
    const size_t colon = value.find(':');
    if (colon != std::string::npos) {
        const int h = std::atoi(value.substr(0, colon).c_str());
        const int m = std::atoi(value.substr(colon + 1).c_str());
        if (h >= 0 && h <= 23) hour = h;
        if (m >= 0 && m <= 59) minute = m;
    }
    pickerHour_ = hour;
    pickerMinute_ = minute;
    showTimePicker_ = true;
    timePickerScale_.set(0.94f);
    timePickerScale_.spring(1.f, kSnapStiffness, kSnapDamping);
}

void App::closeTimePickerAnimated() {
    if (!showTimePicker_) return;
    timePickerScale_.cubic(0.94f, Motion::quick, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
    showTimePicker_ = false;
}

void App::cancelTimePicker() { closeTimePickerAnimated(); }

void App::confirmTimePicker() {
    applyReminderTime(pickerHour_, pickerMinute_);
    closeTimePickerAnimated();
}

void App::applyReminderTime(int hour, int minute) {
    char buf[8];
    std::snprintf(buf, sizeof(buf), "%02d:%02d", hour, minute);
    if (settings_.reminderTime == buf) return;
    settings_.reminderTime = buf;
    persist();
}

void App::addSubject() {
    const std::string name = newSubjectName_;
    const size_t first = name.find_first_not_of(" \t\r\n");
    const size_t last = name.find_last_not_of(" \t\r\n");
    if (first == std::string::npos) {
        showToast(t("toastSubjectEmpty"));
        return;
    }
    const std::string clean = name.substr(first, last - first + 1);
    for (const auto& s : subjects_) {
        if (s.name == clean) {
            showToast(t("toastSubjectExists"));
            return;
        }
    }
    Subject subject;
    subject.id = newId();
    subject.name = clean;
    subject.color = nextSubjectColor();
    subjects_.push_back(subject);
    draftSubjectId_ = subject.id;
    newSubjectName_.clear();
    persist();
    showToast(t("toastSubjectAdded", clean));
}

std::string App::nextSubjectColor() const {
    for (const char* candidate : kSubjectColors) {
        bool used = false;
        for (const auto& s : subjects_) {
            if (s.color == candidate) {
                used = true;
                break;
            }
        }
        if (!used) return candidate;
    }
    return kSubjectColors[subjects_.size() % 16];
}

void App::updateReminderEnabled(bool value) {
    settings_.reminderEnabled = value;
    persist();
}

void App::updateRetention(float value) {
    settings_.targetRetention = std::min(0.95f, std::max(0.80f, std::round(value) / 100.f));
}

void App::updateMaxInterval(int days) {
    if (days == settings_.maxIntervalDays) return;
    settings_.maxIntervalDays = days;
    persist();
}

void App::updateFocusMinutes(int minutes) {
    if (minutes == settings_.focusMinutes) return;
    settings_.focusMinutes = minutes;
    persist();
}

void App::updateTheme(int index) {
    settings_.themeIndex = index;
    persist();
}

void App::setCalendarDays(int days) {
    if (calendarDays_ == days) return;
    calendarDays_ = days;
    playCalendarRows();
}

void App::setLanguage(const std::string& code) {
    if (settings_.language == code) return;
    settings_.language = code;
    todayLabel_ = I18n::todayLabel(code, nowMs());
    persist();
}

// ---------------------------------------------------------------- pomodoro

void App::openFocusClock() {
    clockScale_.set(0.94f);
    showFocusClock_ = true;
    clockScale_.spring(1.f, kSettleStiffness, kSettleDamping);
}

void App::closeFocusClock() {
    if (!showFocusClock_) return;
    clockScale_.cubic(0.94f, Motion::base, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
    showFocusClock_ = false;
}

void App::startCycle() {
    focusCycleStart_ = nowMs();
    focusRound_ = 1;
    startSegment(settings_.focusMinutes, false);
}

void App::startSegment(int minutes, bool isBreak) {
    const int safe = std::min(90, std::max(1, minutes));
    const long long startedAt = nowMs();
    const bool wasRunning = focusRunning_;
    focusIsBreak_ = isBreak;
    focusPaused_ = false;
    focusRunning_ = true;
    focusPlannedMinutes_ = safe;
    focusRemainingMs_ = static_cast<long long>(safe) * 60000;
    focusStartedAt_ = startedAt;
    focusEndAt_ = startedAt + static_cast<long long>(safe) * 60000;
    focusPausedRemaining_ = 0;
    if (wasRunning) popClock();
    persist();
}

void App::ringFocusEnd(bool wasBreak, int minutes, int round) {
    (void)wasBreak;
    (void)minutes;
    (void)round;
    // No system notification from a homebrew app; the on-screen summary is the cue.
}

void App::tickFocus() {
    if (!focusRunning_ || focusPaused_) return;
    const long long left = focusEndAt_ - nowMs();
    focusRemainingMs_ = left > 0 ? left : 0;
    if (left <= 0) finishSegment(true);
}

void App::pauseFocus() {
    if (!focusRunning_ || focusPaused_) return;
    focusPausedRemaining_ = std::max(0LL, focusEndAt_ - nowMs());
    focusRemainingMs_ = focusPausedRemaining_;
    focusPaused_ = true;
    persist();
}

void App::resumeFocus() {
    if (!focusRunning_ || !focusPaused_) return;
    focusEndAt_ = nowMs() + focusPausedRemaining_;
    focusPaused_ = false;
    persist();
}

void App::stopFocusEarly() {
    if (!focusRunning_) return;
    finishSegment(false);
}

void App::finishSegment(bool completed, long long endOverride, bool autoContinue) {
    if (!focusRunning_) return;
    const long long startedAt = focusStartedAt_;
    const long long now = nowMs();
    long long endedAt = now;
    if (endOverride != 0) {
        endedAt = endOverride;
    } else if (completed && focusEndAt_ > 0 && focusEndAt_ <= now) {
        endedAt = focusEndAt_;
    }
    const bool wasBreak = focusIsBreak_;
    const int planned = focusPlannedMinutes_;
    const int round = focusRound_;
    focusRunning_ = false;
    focusPaused_ = false;
    focusIsBreak_ = false;
    focusRemainingMs_ = 0;

    if (wasBreak) {
        if (completed && autoContinue) {
            focusRound_ = round + 1;
            startSegment(settings_.focusMinutes, false);
            return;
        }
        endCycle(endedAt);
        return;
    }

    const FocusSummary summary = summarize(startedAt, endedAt, logs_);
    if (summary.minutes >= 1) {
        FocusSession session;
        session.id = newId();
        session.startedAt = startedAt;
        session.endedAt = endedAt;
        session.plannedMinutes = planned;
        session.minutes = summary.minutes;
        session.itemCount = summary.itemCount;
        session.remembered = summary.remembered;
        session.completed = completed;
        doneSessions_.push_back(session);
    }
    persist();

    if (completed && autoContinue) {
        startSegment(breakMinutesFor(round), true);
        return;
    }
    endCycle(endedAt);
}

void App::endCycle(long long endedAt) {
    const long long cycleStart = focusCycleStart_;
    const CycleSummary cycle = cycleSummary(doneSessions_, cycleStart);
    focusCycleStart_ = 0;
    focusRound_ = 1;
    persist();
    closeFocusClock();
    if (cycle.segments == 0) {
        showToast(t("focusTooShort"));
        return;
    }
    summaryMinutes_ = cycle.minutes;
    summarySegments_ = cycle.segments;
    summaryItems_ = cycle.itemCount;
    summaryRemembered_ = cycle.remembered;
    summaryStart_ = cycleStart;
    summaryEnd_ = endedAt;
    showSummary();
}

void App::showSummary() {
    summaryScale_.set(0.94f);
    showFocusSummary_ = true;
    summaryScale_.spring(1.f, kSnapStiffness, kSnapDamping);
}

void App::closeSummary() {
    if (!showFocusSummary_) return;
    summaryScale_.cubic(0.94f, Motion::base, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
    showFocusSummary_ = false;
}

bool App::currentFocusRecord(FocusSession& out) const {
    if (!focusRunning_) return false;
    out.id = "active";
    out.startedAt = focusStartedAt_;
    out.endedAt = focusPaused_ ? nowMs() + focusPausedRemaining_ : focusEndAt_;
    out.plannedMinutes = focusPlannedMinutes_;
    out.minutes = 0;
    out.itemCount = 0;
    out.remembered = 0;
    out.completed = false;
    out.isBreak = focusIsBreak_;
    out.round = focusRound_;
    out.cycleStart = focusCycleStart_;
    return true;
}

// ---------------------------------------------------------------- per-frame

void App::stepTimers(float dtMs) {
    const float dt = dtMs / 1000.f;

    if (countPopTimer_ >= 0.f) {
        countPopTimer_ -= dt;
        countPop_ = countPopAnim_.value();
        if (countPopTimer_ < 0.f && !countPopAnim_.active()) {
            countPopTimer_ = -1.f;
            countPopAnim_.spring(1.f, kSettleStiffness, kSettleDamping);
        }
    }
    if (clockPopTimer_ >= 0.f) {
        clockPopTimer_ -= dt;
        clockPop_ = clockPopAnim_.value();
        if (clockPopTimer_ < 0.f && !clockPopAnim_.active()) {
            clockPopTimer_ = -1.f;
            clockPopAnim_.spring(1.f, kSettleStiffness, kSettleDamping);
        }
    }
    if (reviewPressTimer_ >= 0.f) {
        reviewPressTimer_ -= dt;
        if (reviewPressTimer_ < 0.f) {
            reviewPressTimer_ = -1.f;
            reviewCommitTimer_ = 0.17f;
            reviewScale_.cubic(0.95f, 170.f, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
        }
    }
    if (reviewCommitTimer_ >= 0.f) {
        reviewCommitTimer_ -= dt;
        if (reviewCommitTimer_ < 0.f) {
            reviewCommitTimer_ = -1.f;
            const int grade = pressedGrade_;
            const std::string itemId = reviewItem_.id;
            const int token = reviewToken_;
            reviewBusy_ = false;
            commitReview(grade, itemId, token);
        }
    }
    if (toastTimer_ > 0.f) {
        toastTimer_ -= dtMs;
        if (toastTimer_ <= 0.f) {
            toastTimer_ = 0.f;
            toastOpacity_.cubic(0.f, 220.f, kAccel.p1x, kAccel.p1y, kAccel.p2x, kAccel.p2y);
        }
    }
}

void App::advance(float dtMs) {
    todayTitleAnim_.tick(dtMs);
    todayProgressAnim_.tick(dtMs);
    todayLoggedAnim_.tick(dtMs);
    listOpacityAnim_.tick(dtMs);
    listShiftAnim_.tick(dtMs);
    pageOpacityAnim_.tick(dtMs);
    pageShiftAnim_.tick(dtMs);
    countPopAnim_.tick(dtMs);
    clockPopAnim_.tick(dtMs);
    formProgressAnim_.tick(dtMs);
    modeFadeAnim_.tick(dtMs);
    actionContentAnim_.tick(dtMs);
    reviewOpacity_.tick(dtMs);
    reviewScale_.tick(dtMs);
    composerScale_.tick(dtMs);
    composerShift_.tick(dtMs);
    composerOpacity_.tick(dtMs);
    composerDim_.tick(dtMs);
    actionScale_.tick(dtMs);
    actionOverlayOpacity_.tick(dtMs);
    confirmScale_.tick(dtMs);
    timePickerScale_.tick(dtMs);
    clockScale_.tick(dtMs);
    summaryScale_.tick(dtMs);
    toastOpacity_.tick(dtMs);
    for (auto& a : recAnim_) a.tick(dtMs);
    for (auto& a : setAnim_) a.tick(dtMs);
    for (auto& a : dotAlpha_) a.tick(dtMs);
    for (int i = 0; i < 32; ++i) {
        calXAnim_[i].tick(dtMs);
        calAlphaAnim_[i].tick(dtMs);
    }

    todayTitleIn_ = todayTitleAnim_.value();
    todayProgress_ = todayProgressAnim_.value();
    todayLoggedIn_ = todayLoggedAnim_.value();
    listOpacity_ = listOpacityAnim_.value();
    listShift_ = listShiftAnim_.value();
    pageOpacity_ = pageOpacityAnim_.value();
    pageShift_ = pageShiftAnim_.value();
    formProgress_ = formProgressAnim_.value();
    modeFade_ = modeFadeAnim_.value();
    actionContentOpacity_ = actionContentAnim_.value();
    for (int i = 0; i < 12; ++i) recIn_[i] = recAnim_[i].value();
    for (int i = 0; i < 5; ++i) setIn_[i] = setAnim_[i].value();

    tickFocus();
    stepTimers(dtMs);
}

}  // namespace folio