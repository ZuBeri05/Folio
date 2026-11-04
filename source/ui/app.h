#pragma once

#include <string>
#include <vector>

#include "core/canvas.h"
#include "core/font.h"
#include "domain/fsrs.h"
#include "domain/models.h"
#include "services/i18n.h"
#include "ui/anim.h"
#include "ui/theme.h"
#include "ui/ui.h"

namespace folio {

struct DayCount {
    long long date = 0;
    int count = 0;
};

struct TouchSample {
    bool active = false;
    float x = 0.f;
    float y = 0.f;
};

/**
 * All screen state and behaviour from pages/Index.ets. Layout lives in
 * app_draw.cpp; this class owns the data, the timers and every motion value.
 */
class App {
public:
    void init(FontBook* fonts);
    /** One frame: advance animations, layout, draw, then dispatch taps. */
    void frame(Canvas& canvas, Ui& ui, float dtMs, const TouchSample& touch, float widthVp, float heightVp);

    /** Set by the platform when the OS keyboard returns text. */
    void setKeyboardResult(bool ok, const std::string& text);

private:
    friend struct AppDraw;
public:
    /** Draw-order tap recording, called from the Ui sink. */
    void recordTap(const Rect& r, int action, const std::string& arg, int number);
    void onAction(int action, const std::string& arg, int number);
    void dispatchTap(float x, float y);

private:
    friend struct AppInput;

    // ---- data ----------------------------------------------------------
    std::vector<Subject> subjects_;
    std::vector<StudyItem> items_;
    std::vector<ReviewLog> logs_;
    std::vector<FocusSession> focusSessions_;
    std::vector<FocusSession> doneSessions_;
    Settings settings_;
    bool dataLoaded_ = false;

    // ---- layout / navigation -------------------------------------------
    int tab_ = 0;
    bool isWide_ = false;
    bool isTablet_ = false;
    float vpWidth_ = 1280.f;
    float vpHeight_ = 720.f;
    float scrollToday_ = 0.f;
    float scrollRecords_ = 0.f;
    float scrollCalendar_ = 0.f;
    float scrollSettings_ = 0.f;

    // ---- composer ------------------------------------------------------
    bool showComposer_ = false;
    std::string draftSubjectId_;
    std::string draftTitle_;
    int draftMode_ = 0;  // 0 = fsrs, 1 = fixed
    float modeFade_ = 1.f;
    int draftFixedDays_ = 3;
    int dotVisible_ = 6;

    // ---- today page motion ---------------------------------------------
    float todayTitleIn_ = 1.f;
    float todayProgress_ = 1.f;
    float todayLoggedIn_ = 1.f;
    float listOpacity_ = 0.f;
    float listShift_ = 0.f;
    float countPop_ = 1.f;
    float formProgress_ = 1.f;

    // ---- page transition ------------------------------------------------
    float pageOpacity_ = 1.f;
    float pageShift_ = 0.f;

    // ---- records / calendar / settings entrance -------------------------
    float recIn_[12] = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
    float setIn_[5] = {1, 1, 1, 1, 1};
    std::vector<float> calX_;
    std::vector<float> calAlpha_;
    int calendarDays_ = 14;
    float recRowH_ = 86.f;

    // ---- review overlay --------------------------------------------------
    bool showReview_ = false;
    StudyItem reviewItem_;
    int reviewStage_ = 0;  // 0 = entry card, 1 = rating card
    std::vector<int> gradePreviewDays_;
    int pressedGrade_ = 0;
    float reviewPressTimer_ = -1.f;
    float reviewCommitTimer_ = -1.f;
    bool reviewBusy_ = false;
    int reviewToken_ = 0;
    float reviewCloseTimer_ = -1.f;

    // ---- item actions / confirm / time picker ---------------------------
    bool showItemActions_ = false;
    StudyItem actionItem_;
    int actionMode_ = 0;  // 0 = view, 1 = edit
    std::string editTitle_;
    std::string editSubjectId_;
    float actionContentOpacity_ = 1.f;
    bool showConfirm_ = false;
    std::string confirmTitle_;
    std::string confirmMessage_;
    int confirmKind_ = 0;  // 0 = subject, 1 = record
    std::string confirmSubjectId_;
    std::string confirmItemId_;
    bool showTimePicker_ = false;
    int pickerHour_ = 20;
    int pickerMinute_ = 0;
    std::string newSubjectName_;

    // ---- focus / pomodoro ------------------------------------------------
    bool focusRunning_ = false;
    bool focusPaused_ = false;
    bool focusIsBreak_ = false;
    long long focusEndAt_ = 0;
    long long focusStartedAt_ = 0;
    long long focusRemainingMs_ = 0;
    int focusPlannedMinutes_ = 25;
    int focusRound_ = 1;
    long long focusCycleStart_ = 0;
    long long focusPausedRemaining_ = 0;
    bool showFocusClock_ = false;
    bool showFocusSummary_ = false;
    int summaryMinutes_ = 0;
    int summarySegments_ = 0;
    int summaryItems_ = 0;
    int summaryRemembered_ = 0;
    long long summaryStart_ = 0;
    long long summaryEnd_ = 0;
    float clockPop_ = 1.f;
    float clockPopTimer_ = -1.f;
    float countPopTimer_ = -1.f;

    // ---- animated values -------------------------------------------------
    Anim reviewOpacity_{0.f};
    Anim reviewScale_{1.f};
    Anim composerScale_{1.f};
    Anim composerShift_{0.f};
    Anim composerOpacity_{1.f};
    Anim composerDim_{0.f};
    Anim actionScale_{1.f};
    Anim actionOverlayOpacity_{1.f};
    Anim confirmScale_{1.f};
    Anim timePickerScale_{1.f};
    Anim clockScale_{1.f};
    Anim summaryScale_{1.f};
    Anim todayTitleAnim_{1.f};
    Anim todayProgressAnim_{1.f};
    Anim todayLoggedAnim_{1.f};
    Anim listOpacityAnim_{0.f};
    Anim listShiftAnim_{0.f};
    Anim recAnim_[12];
    Anim setAnim_[5];
    Anim calXAnim_[32];
    Anim calAlphaAnim_[32];
    Anim pageOpacityAnim_{1.f};
    Anim pageShiftAnim_{0.f};
    Anim countPopAnim_{1.f};
    Anim clockPopAnim_{1.f};
    Anim formProgressAnim_{1.f};
    Anim modeFadeAnim_{1.f};
    Anim actionContentAnim_{1.f};
    Anim dotAlpha_[6];
    Anim toastOpacity_{0.f};

    std::string todayLabel_;
    std::string toastText_;
    float toastTimer_ = 0.f;
    bool settingRetentionUnlocked_ = false;
    bool wasTouching_ = false;
    float clockSeconds_ = 0.f;
    FontBook* fonts_ = nullptr;

    // ---- helpers used by both update and draw ----------------------------
    float mv(float base) const { return Motion::travel(base, vpWidth_); }
    float md(float base) const { return Motion::time(base, vpWidth_); }

    std::string t(const char* key) const;
    std::string t(const char* key, int a) const;
    std::string t(const char* key, const std::string& a) const;
    std::string t(const char* key, const std::string& a, const std::string& b) const;
    std::string t(const char* key, int a, const std::string& b) const;
    std::string t(const char* key, const std::string& a, int b) const;
    std::string shortDate(long long ts) const;
    std::string longDate(long long ts) const;
    std::string weekday(long long ts) const;
    std::string navLabel(int index) const;

    const Subject& findSubject(const std::string& id) const;
    Color colorOf(const std::string& hex, float alphaMul = 1.f) const;
    std::string subjectInk(const std::string& color) const;

    std::vector<StudyItem> dueItems() const;
    std::vector<StudyItem> sortedItems() const;
    std::vector<StudyItem> todayCreatedItems() const;
    std::vector<StudyItem> overdueItems() const;
    int overdueDaysOf(const StudyItem& item) const;
    std::string oldestOverdueLabel() const;
    std::vector<DayCount> upcoming() const;
    std::vector<StudyItem> dayItems(long long day, bool isToday) const;
    std::string itemSubtitle(const StudyItem& item) const;

    Color pageBg() const;
    Color pageColors(int index, int slot) const;
    Color themeAccent(int index) const;
    Color themeButton() const;
    std::string themeInk() const;

    std::string gradeLabel(int grade) const;
    std::string gradeMeaning(int grade) const;
    Color gradeColor(int grade) const;
    Color gradeTint(int grade, const char* alpha) const;
    std::string intervalText(int days) const;
    std::string gradeIntervalText(int grade) const;
    std::string legacyRating(int grade) const;
    int reviewElapsedDays(const StudyItem& item, long long now) const;
    std::string minutesLabel(int minutes) const;
    std::string roundLabel() const;
    std::string focusClockText() const;
    std::string elapsedClockText() const;
    float focusRemainingPercent() const;
    int tickCount() const;
    int elapsedMinutes() const;
    float tickOpacity(int index) const;
    Color clockAccent() const;
    float clockSize() const;
    int todayFocusMinutes() const;
    int todayFocusCount() const;
    std::vector<int> weekFocus() const;
    int weekBarHeight(int minutes) const;
    long long weekDayTs(int index) const;
    int todayWeekIndex() const;
    std::string clockLabel(long long ts) const;
    std::string curveDotLabel(int index) const;

    // ---- behaviour -------------------------------------------------------
    void loadData();
    void persist();
    void showToast(const std::string& message);
    void switchTab(int next);
    void playEntry();
    void playToday();
    void playRecords();
    void playSettings();
    void playForm();
    void playDots();
    void playCalendarRows();
    void refreshGradePreview(const StudyItem& item);
    void popCount();
    void popClock();

    void openComposer();
    void closeComposer();
    void switchMode(int mode);
    void addItem();

    void openReview(const StudyItem& item);
    void closeReview();
    void startRating();
    void backToEntry();
    void postponeReview();
    void finishReview(int grade);
    void commitReview(int grade, const std::string& itemId, int token);
    bool isReviewCommitActive(const std::string& itemId, int token) const;
    void discardPendingReview();

    void openItemActions(const StudyItem& item);
    void closeItemActions();
    void startEditItem();
    void changeActionMode(int mode);
    void saveItemEdit();
    void askDeleteRecord(const StudyItem& item);
    void confirmDeleteSubject(const Subject& subject);
    void closeConfirmAnimated();
    void cancelConfirm();
    void executeConfirm();
    void deleteItem(const std::string& id);

    void openTimePicker();
    void closeTimePickerAnimated();
    void cancelTimePicker();
    void confirmTimePicker();
    void applyReminderTime(int hour, int minute);

    void addSubject();
    void deleteSubject();
    void updateRetention(float value);
    void updateMaxInterval(int days);
    void updateFocusMinutes(int minutes);
    void updateTheme(int index);
    void setCalendarDays(int days);
    void setLanguage(const std::string& code);
    void updateReminderEnabled(bool value);
    std::string nextSubjectColor() const;

    void openFocusClock();
    void closeFocusClock();
    void startCycle();
    void startSegment(int minutes, bool isBreak);
    void ringFocusEnd(bool wasBreak, int minutes, int round);
    void tickFocus();
    void pauseFocus();
    void resumeFocus();
    void stopFocusEarly();
    void finishSegment(bool completed, long long endOverride = 0, bool autoContinue = true);
    void endCycle(long long endedAt);
    void showSummary();
    void closeSummary();
    void restoreFocus();
    bool currentFocusRecord(FocusSession& out) const;

    void advance(float dtMs);
    struct TapRegion {
        Rect rect;
        int action = 0;
        std::string arg;
        int number = 0;
    };
    std::vector<TapRegion> taps_;
    void stepTimers(float dtMs);

    // drawing (app_draw.cpp)
    void draw(Canvas& canvas, Ui& ui);
    void drawPhoneLayout(Ui& ui);
    void drawTabletLayout(Ui& ui);
    void drawRail(Ui& ui, const Rect& area);
    void drawTopBar(Ui& ui, const Rect& area, bool showAdd);
    void drawTodayPane(Ui& ui, const Rect& area);
    void drawEmptyToday(Ui& ui, const Rect& area);
    void drawTodayLogged(Ui& ui, const Rect& area);
    void drawReviewRow(Ui& ui, const Rect& area, const StudyItem& item, int index);
    void drawComposerPane(Ui& ui, const Rect& area, bool showClose);
    void drawRecordsPage(Ui& ui, const Rect& area);
    void drawCalendarPage(Ui& ui, const Rect& area);
    void drawSettingsPage(Ui& ui, const Rect& area);
    void drawBottomNav(Ui& ui, const Rect& area);
    void drawFocusWeekCard(Ui& ui, const Rect& area);
    void drawReviewOverlay(Ui& ui);
    void drawEntryCard(Ui& ui, const Rect& area);
    void drawRatingCard(Ui& ui, const Rect& area);
    void drawConfirmOverlay(Ui& ui);
    void drawTimePickerOverlay(Ui& ui);
    void drawItemActionsOverlay(Ui& ui);
    void drawComposerOverlay(Ui& ui);
    void drawFocusClockOverlay(Ui& ui);
    void drawFocusSummaryOverlay(Ui& ui);
    void drawFocusMiniBar(Ui& ui);
    void drawToast(Ui& ui);
    void drawIcon(Ui& ui, const Rect& box, int iconId, float opacity = 1.f);
    /** Nav icon index for a tab (on/off asset variants live in kIcons). */
    int navIcon(int index, bool active) const;
    Color nullTint() const;
};

}  // namespace folio