// Painting layer: same structure as the ArkUI @Builder tree in pages/Index.ets.
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <functional>

#include "platform/platform.h"
#include "ui/app.h"

namespace folio {

namespace {

Color tok(const char* hex, float alphaMul = 1.f) { return parseColor(hex, alphaMul); }
Color tokStr(const std::string& hex, float alphaMul = 1.f) { return parseColor(hex.c_str(), alphaMul); }

constexpr int kActTab = 100;
constexpr int kActReviewItem = 101;
constexpr int kActAddItem = 102;
constexpr int kActCloseReview = 103;
constexpr int kActPostpone = 104;
constexpr int kActStartRating = 105;
constexpr int kActBackToEntry = 106;
constexpr int kActGrade = 107;
constexpr int kActComposer = 108;
constexpr int kActCloseComposer = 109;
constexpr int kActSaveItem = 110;
constexpr int kActMode = 111;
constexpr int kActSubjectDraft = 112;
constexpr int kActFixedPlus = 113;
constexpr int kActFixedMinus = 114;
constexpr int kActFocusOpen = 115;
constexpr int kActFocusClose = 116;
constexpr int kActFocusStart = 117;
constexpr int kActFocusPause = 118;
constexpr int kActFocusEnd = 119;
constexpr int kActCloseSummary = 120;
constexpr int kActCalendarDays = 121;
constexpr int kActMaxInterval = 122;
constexpr int kActFocusMinutes = 123;
constexpr int kActTheme = 124;
constexpr int kActLanguage = 125;
constexpr int kActRetentionToggle = 126;
constexpr int kActRetentionDown = 127;
constexpr int kActRetentionUp = 128;
constexpr int kActItemActions = 129;
constexpr int kActCloseActions = 130;
constexpr int kActEditItem = 131;
constexpr int kActDeleteFromAction = 132;
constexpr int kActCloseConfirm = 133;
constexpr int kActDoDelete = 134;
constexpr int kActCancelConfirm = 135;
constexpr int kActDeleteSubject = 136;
constexpr int kActReminderToggle = 137;
constexpr int kActOpenTimePicker = 138;
constexpr int kActHourDown = 139;
constexpr int kActHourUp = 140;
constexpr int kActMinuteDown = 141;
constexpr int kActMinuteUp = 142;
constexpr int kActTimeCancel = 143;
constexpr int kActTimeConfirm = 144;
constexpr int kActAddSubject = 145;
constexpr int kActSubjectEdit = 146;
constexpr int kActSaveEdit = 147;
constexpr int kActSeeAll = 148;
constexpr int kActScrollRecords = 149;

}  // namespace

// ---------------------------------------------------------------- helpers

void App::drawIcon(Ui& ui, const Rect& box, int iconId, float opacity) {
    // Each shape carries its own color from the SVG, so icons keep their real
    // palette; opacity is the only knob the UI needs (muted nav states).
    if (iconId < 0 || iconId >= static_cast<int>(sizeof(kIcons) / sizeof(kIcons[0]))) return;
    const IconDef& def = kIcons[iconId];
    for (int i = 0; i < def.shapeCount; ++i) {
        const IconShape& shape = def.shapes[i];
        const float r = ((shape.color >> 16) & 0xFF) / 255.f;
        const float g = ((shape.color >> 8) & 0xFF) / 255.f;
        const float b = (shape.color & 0xFF) / 255.f;
        const Color draw(r, g, b, opacity);
        if (shape.strokeWidth > 0.f) {
            ui.canvas().strokePolyline(shape.points, shape.count, box, def.viewSize, shape.strokeWidth,
                                       draw);
        } else {
            ui.canvas().fillPolygons(shape.points, shape.count, box, def.viewSize, draw);
        }
    }
}
int App::navIcon(int index, bool active) const {
    static const int onIcons[4] = {kIconBananaOn, kIconLemonOn, kIconCarrotOn, kIconWatermelonOn};
    static const int offIcons[4] = {kIconBananaOff, kIconLemonOff, kIconCarrotOff, kIconWatermelonOff};
    const int safe = (index >= 0 && index < 4) ? index : 0;
    return active ? onIcons[safe] : offIcons[safe];
}

void App::draw(Canvas& canvas, Ui& ui) {
    canvas.clear(pageBg());
    // Switch is always a wide landscape display, so the tablet split layout
    // from the original is the primary one; the phone layout is kept for
    // narrow windows.
    if (isWide_) {
        drawTabletLayout(ui);
    } else {
        drawPhoneLayout(ui);
    }
    if (showReview_) drawReviewOverlay(ui);
    if (showComposer_ && !isWide_) drawComposerOverlay(ui);
    if (showItemActions_) drawItemActionsOverlay(ui);
    if (showConfirm_) drawConfirmOverlay(ui);
    if (showTimePicker_) drawTimePickerOverlay(ui);
    if (showFocusClock_) drawFocusClockOverlay(ui);
    if (showFocusSummary_) drawFocusSummaryOverlay(ui);
    drawToast(ui);
}

// ---------------------------------------------------------------- layouts

void App::drawPhoneLayout(Ui& ui) {
    const float w = vpWidth_;
    const float h = vpHeight_;
    drawTopBar(ui, Rect(0, 0, w, 72), true);
    const float contentTop = 72.f;
    const float navH = 60.f + 18.f;
    if (tab_ == 0) {
        drawTodayPane(ui, Rect(0, contentTop, w, h - contentTop - navH));
    } else if (tab_ == 1) {
        drawRecordsPage(ui, Rect(0, contentTop, w, h - contentTop - navH));
    } else if (tab_ == 2) {
        drawCalendarPage(ui, Rect(0, contentTop, w, h - contentTop - navH));
    } else {
        drawSettingsPage(ui, Rect(0, contentTop, w, h - contentTop - navH));
    }
    if (focusRunning_ && tab_ != 0) {
        drawFocusMiniBar(ui);
    }
    drawBottomNav(ui, Rect(w * 0.04f, h - navH + 8.f, w * 0.92f, 60.f));
}

void App::drawTabletLayout(Ui& ui) {
    const float w = vpWidth_;
    const float h = vpHeight_;
    drawRail(ui, Rect(0, 0, 124, h));
    const float left = 124.f;
    drawTopBar(ui, Rect(left, 0, w - left, 72), false);
    if (tab_ == 0) {
        const float paneW = std::min(400.f, (w - left) * 0.45f);
        drawTodayPane(ui, Rect(left, 72, w - left - paneW - 68.f, h - 72));
        // The composer is a fixed-content Column in the original: it is as tall
        // as its contents, capped by the available height.
        const float composerH = std::min(h - 96.f, 596.f);
        drawComposerPane(ui, Rect(w - paneW - 44.f, 84, paneW, composerH), false);
    } else if (tab_ == 1) {
        drawRecordsPage(ui, Rect(left, 72, w - left, h - 72));
    } else if (tab_ == 2) {
        drawCalendarPage(ui, Rect(left, 72, w - left, h - 72));
    } else {
        drawSettingsPage(ui, Rect(left, 72, w - left, h - 72));
    }
    if (focusRunning_ && tab_ != 0) {
        drawFocusMiniBar(ui);
    }
}

void App::drawRail(Ui& ui, const Rect& area) {
    Canvas& c = ui.canvas();
    c.fillRect(area, pageBg());
    for (int i = 0; i < 4; ++i) {
        const Rect item(area.x + 6, area.y + 56 + i * (88 + 34), 112, 88);
        const bool active = tab_ == i;
        const Color tint = active ? tok("#6C4B00") : tok(tokens::mutedSoft);
        drawIcon(ui, Rect(item.x + item.w * 0.5f - 15, item.y + 18, 30, 30), navIcon(i, active));
        Canvas::TextStyle st = ui.style(11.5f, tint, active);
        st.align = Canvas::TextStyle::Center;
        st.valign = Canvas::TextStyle::Middle;
        c.drawText(Rect(item.x, item.y + 54, item.w, 18), navLabel(i).c_str(), st);
        ui.tap(item, kActTab, "", i);
    }
    Canvas::TextStyle ver = ui.style(7.f, tok(tokens::mutedSoft));
    ver.align = Canvas::TextStyle::Center;
    c.drawText(Rect(area.x, area.bottom() - 30, area.w, 12), "v1.1.2", ver);
}

void App::drawTopBar(Ui& ui, const Rect& area, bool showAdd) {
    Canvas& c = ui.canvas();
    c.fillRect(area, pageBg());
    const float pad = isWide_ ? 44.f : 20.f;
    Canvas::TextStyle st = ui.style(12.f, tok(tokens::muted));
    st.valign = Canvas::TextStyle::Middle;
    c.drawText(Rect(area.x + pad, area.y, area.w - pad * 2 - 120, area.h), todayLabel_.c_str(), st);

    // On the tablet layout the original puts the tomato button at the far right
    // (TopBar(false) has no "new entry" pill next to it).
    const float tomatoSize = 34.f;
    const float tomatoRight = showAdd ? (area.right() - pad - 68.f - 8.f) : (area.right() - pad);
    const Rect tomatoRect(tomatoRight - tomatoSize, area.y + (area.h - tomatoSize) * 0.5f, tomatoSize,
                          tomatoSize);
    c.fillCircle(tomatoRect.center().x, tomatoRect.center().y, tomatoRect.w * 0.5f,
                 focusRunning_ ? tok("#FFE3D8") : tok("#FFEDE6"));
    c.strokeCircle(tomatoRect.center().x, tomatoRect.center().y, tomatoRect.w * 0.5f, 1.f,
                   focusRunning_ ? tok("#FF6542") : tok("#FF6542", 0.25f));
    drawIcon(ui, tomatoRect.inset(tomatoRect.w * 0.2f), kIconTomato);
    ui.tap(Rect(tomatoRect.x, tomatoRect.y - 6, tomatoRect.w, tomatoRect.h + 12), kActFocusOpen);

    if (showAdd) {
        const Rect add(area.right() - pad - 68, area.y + (area.h - 34) * 0.5f, 68, 34);
        ui.pillButton(add, t("newEntry"), 12.f, themeButton(), tokStr(themeInk()), false);
        ui.tap(add, kActComposer);
    }
}

// ---------------------------------------------------------------- today

void App::drawTodayPane(Ui& ui, const Rect& area) {
    Canvas& c = ui.canvas();
    const float pad = isWide_ ? 44.f : 20.f;
    const Rect inner(area.x + pad, area.y, area.w - pad * 2 - (isWide_ ? 20.f : 0.f), area.h);
    float y = inner.y + (isWide_ ? 10.f : 8.f);

    // Title row with the count pill, sliding in from the left.
    const float titleSize = isWide_ ? 48.f : 34.f;
    const float shift = (1.f - todayTitleIn_) * -mv(72.f);
    const float alpha = 0.3f + 0.7f * std::min(1.f, todayTitleIn_ * 1.8f);
    c.pushAlpha(alpha);
    const auto due = dueItems();
    const std::string title = t("todayTitle");
    const float titleW = ui.measure(title, titleSize, true, -1.f);
    Canvas::TextStyle ts = ui.style(titleSize, tok(tokens::ink), true);
    ts.letterSpacing = -1.f;
    ts.valign = Canvas::TextStyle::Middle;
    c.drawText(Rect(inner.x + shift, y, titleW + 20, titleSize * 1.25f), title.c_str(), ts);

    const std::string countText = t("items", static_cast<int>(due.size()));
    const float countW = ui.measure(countText, 11.f, false) + 34.f;
    const Rect pill(inner.x + shift + titleW + 14.f, y + titleSize * 0.28f, countW, 30.f);
    const float pop = countPop_;
    const Rect pillScaled(pill.center().x - pill.w * pop * 0.5f, pill.center().y - pill.h * pop * 0.5f,
                          pill.w * pop, pill.h * pop);
    c.fillRoundRect(pillScaled, 15.f, tok(tokens::surfaceSoft));
    c.strokeRoundRect(pillScaled, 15.f, 1.f, tok("#A6FFC531"));
    c.fillCircle(pillScaled.x + 14.f, pillScaled.center().y, 2.5f, tok(tokens::orange));
    Canvas::TextStyle cs = ui.style(11.f, tok("#9B5C00"));
    cs.valign = Canvas::TextStyle::Middle;
    c.drawText(Rect(pillScaled.x + 21.f, pillScaled.y, pillScaled.w - 26.f, pillScaled.h), countText.c_str(), cs);
    c.popAlpha();

    y += titleSize * 1.25f + 8.f;

    const auto overdue = overdueItems();
    if (!overdue.empty()) {
        c.pushAlpha(alpha);
        Canvas::TextStyle os = ui.style(11.5f, tok(tokens::coral));
        c.drawText(Rect(inner.x + shift, y, inner.w, 16.f),
                   t("overdueHint", static_cast<int>(overdue.size()), oldestOverdueLabel()).c_str(), os);
        c.popAlpha();
        y += 26.f;
    }

    const Rect listArea(inner.x, y, inner.w, inner.bottom() - y);
    c.pushClip(listArea);
    c.pushAlpha(listOpacity_);
    float listY = listArea.y + listShift_;

    if (due.empty()) {
        const Rect empty(inner.x, listY, inner.w, 230.f);
        const float fp = formProgress_;
        c.pushAlpha(fp);
        Canvas::TextStyle t1 = ui.style(16.f, tok(tokens::inkSoft));
        t1.align = Canvas::TextStyle::Center;
        c.drawText(Rect(empty.x, empty.y + 74.f, empty.w, 22.f), t("todayEmptyTitle").c_str(), t1);
        Canvas::TextStyle t2 = ui.style(11.f, tok(tokens::muted));
        t2.align = Canvas::TextStyle::Center;
        c.drawText(Rect(empty.x, empty.y + 104.f, empty.w, 18.f), t("todayEmptyBody").c_str(), t2);
        const Rect btn(empty.center().x - 46.f, empty.y + 132.f, 92.f, 38.f);
        ui.pillButton(btn, t("newEntry"), 12.f, themeButton(), tokStr(themeInk()), false);
        ui.tap(btn, kActComposer);
        c.popAlpha();
        listY += 230.f;
    } else {
        for (size_t i = 0; i < due.size(); ++i) {
            const float itemShift = (1.f - todayProgress_) * (mv(36.f) + static_cast<float>(i) * mv(8.f));
            const Rect row(inner.x, listY + itemShift, inner.w, 100.f);
            c.pushAlpha(0.3f + 0.7f * std::min(1.f, todayProgress_ * 1.8f));
            drawReviewRow(ui, row, due[i], static_cast<int>(i));
            c.popAlpha();
            listY += 116.f;
        }
    }

    const auto logged = todayCreatedItems();
    if (!logged.empty()) {
        const float sx = (1.f - todayLoggedIn_) * mv(72.f);
        c.pushAlpha(0.3f + 0.7f * std::min(1.f, todayLoggedIn_ * 1.8f));
        listY += 8.f;
        drawTodayLogged(ui, Rect(inner.x + sx, listY, inner.w, logged.size() * 70.f + 30.f));
        c.popAlpha();
    }

    c.popAlpha();
    c.popClip();
}

void App::drawTodayLogged(Ui& ui, const Rect& area) {
    Canvas& c = ui.canvas();
    const auto logged = todayCreatedItems();
    float y = area.y;
    Canvas::TextStyle h = ui.style(12.f, tok(tokens::inkSoft), true);
    h.valign = Canvas::TextStyle::Middle;
    c.drawText(Rect(area.x, y, 120.f, 18.f), t("todayLogged").c_str(), h);
    Canvas::TextStyle n = ui.style(9.f, tok(tokens::mutedSoft));
    n.valign = Canvas::TextStyle::Middle;
    c.drawText(Rect(area.x + 72.f, y, 60.f, 18.f), t("items", static_cast<int>(logged.size())).c_str(), n);
    Canvas::TextStyle seeAll = ui.style(9.f, tok("#B16A0A"));
    seeAll.align = Canvas::TextStyle::Right;
    seeAll.valign = Canvas::TextStyle::Middle;
    c.drawText(Rect(area.right() - 60.f, y, 60.f, 18.f), t("seeAll").c_str(), seeAll);
    ui.tap(Rect(area.right() - 66.f, y - 4.f, 66.f, 26.f), kActSeeAll);
    y += 24.f;

    for (size_t i = 0; i < logged.size(); ++i) {
        const auto& item = logged[i];
        const float shiftY = (1.f - todayProgress_) * (mv(20.f) + static_cast<float>(i) * mv(5.f));
        const Rect card(area.x, y + shiftY, area.w, 62.f);
        c.pushAlpha(std::min(1.f, todayProgress_));
        ui.card(card, 16.f, tok(tokens::surface), tok("#B3FFFFFF"), 1.f, 0.f, 0.f, 0.f);
        c.fillCircle(card.x + 20.f, card.y + 22.f, 3.5f, colorOf(findSubject(item.subjectId).color));
        Canvas::TextStyle title = ui.style(14.f, tok(tokens::ink));
        title.valign = Canvas::TextStyle::Middle;
        title.marquee = true;
        c.drawText(Rect(card.x + 32.f, card.y + 6.f, card.w - 50.f, 22.f), item.title.c_str(), title);
        Canvas::TextStyle sub = ui.style(9.f, tok(tokens::muted));
        sub.valign = Canvas::TextStyle::Middle;
        const std::string line = findSubject(item.subjectId).name + "  ·  " + t("next") + " " +
                                 shortDate(item.nextReviewAt);
        c.drawText(Rect(card.x + 32.f, card.y + 30.f, card.w - 50.f, 16.f), line.c_str(), sub);
        ui.tap(card, kActItemActions, item.id);
        c.popAlpha();
        y += 70.f;
    }
}

void App::drawReviewRow(Ui& ui, const Rect& area, const StudyItem& item, int index) {
    (void)index;
    Canvas& c = ui.canvas();
    const Rect card(area.x, area.y, area.w, 100.f);
    const Color subjectColor = colorOf(findSubject(item.subjectId).color);
    ui.card(card, 22.f, tok(tokens::surfaceSoft), tok("#B3FFFFFF"), 1.f, 22.f, 0.06f, 8.f);
    c.strokeCircle(card.x + 33.f, card.y + 40.f, 14.f, 2.f, subjectColor);
    c.fillCircle(card.x + 33.f, card.y + 40.f, 4.f, subjectColor);

    Canvas::TextStyle s = ui.style(10.f, tok(tokens::muted));
    s.valign = Canvas::TextStyle::Top;
    c.drawText(Rect(card.x + 57.f, card.y + 26.f, 200.f, 14.f), findSubject(item.subjectId).name.c_str(), s);
    Canvas::TextStyle title = ui.style(21.f, tok(tokens::ink), true);
    title.valign = Canvas::TextStyle::Top;
    title.maxLines = 1;
    // Long chapter titles scroll instead of being cut off.
    title.marquee = true;
    c.drawText(Rect(card.x + 57.f, card.y + 38.f, card.w - 145.f, 28.f), item.title.c_str(), title);
    Canvas::TextStyle sub = ui.style(11.5f, overdueDaysOf(item) > 0 ? tok(tokens::coral) : tok(tokens::muted));
    sub.valign = Canvas::TextStyle::Top;
    c.drawText(Rect(card.x + 57.f, card.y + 66.f, card.w - 160.f, 16.f), itemSubtitle(item).c_str(), sub);

    const Rect btn(card.right() - 76.f, card.y + 34.f, 54.f, 32.f);
    c.fillRoundRect(btn, 16.f, tok(tokens::surface));
    c.strokeRoundRect(btn, 16.f, 1.f, tok(tokens::line));
    ui.textCenter(btn, t("review"), 10.5f, tok(tokens::inkSoft));
    ui.tap(btn, kActReviewItem, item.id);
    ui.tap(Rect(card.x, card.y, card.w - 90.f, card.h), kActItemActions, item.id);
}

// ---------------------------------------------------------------- composer

void App::drawComposerPane(Ui& ui, const Rect& area, bool showClose) {
    Canvas& c = ui.canvas();
    c.pushAlpha(formProgress_);
    c.pushClip(area);
    const Rect card(area.x, area.y + (1.f - formProgress_) * mv(18.f), area.w, area.h);
    ui.card(card, 26.f, tok(tokens::surfaceSoft), Color(1, 1, 1, 0.8f), 1.f, 32.f, 0.078f, 16.f);
    // The original pane is a fixed-height column; clip so content never leaks.
    float y = card.y + 24.f;
    Canvas::TextStyle h = ui.style(28.f, tok(tokens::ink), true);
    h.letterSpacing = -0.6f;
    h.valign = Canvas::TextStyle::Middle;
    c.drawText(Rect(card.x + 24.f, y, card.w - 110.f, 36.f), t("newEntry").c_str(), h);
    if (showClose) {
        const Rect btn(card.right() - 24.f - 40.f, y + 6.f, 40.f, 26.f);
        c.fillRoundRect(btn, 13.f, tok(tokens::yellowSoft));
        ui.textCenter(btn, t("close"), 9.f, tok("#6C4B00"));
        ui.tap(btn, kActCloseComposer);
    }
    y += 44.f;

    Canvas::TextStyle label = ui.style(9.f, tok(tokens::muted));
    label.valign = Canvas::TextStyle::Middle;
    c.drawText(Rect(card.x + 24.f, y, 60.f, 14.f), t("subject").c_str(), label);
    y += 20.f;

    // subject chips, wrapping
    float cx = card.x + 24.f;
    float rowH = 37.f;
    for (const auto& subject : subjects_) {
        const float cw = ui.measure(subject.name, 11.f, false) + 24.f;
        if (cx + cw > card.right() - 24.f) {
            cx = card.x + 24.f;
            y += rowH;
        }
        const bool selected = draftSubjectId_ == subject.id;
        const Rect chip(cx, y, cw, 31.f);
        const Color fill = selected ? colorOf(subject.color) : tok(tokens::surface);
        c.fillRoundRect(chip, 16.f, fill);
        c.strokeRoundRect(chip, 16.f, 1.f, selected ? colorOf(subject.color) : tok(tokens::line));
        ui.textCenter(chip, subject.name, 11.f,
                      selected ? tokStr(subjectInk(subject.color)) : tok(tokens::inkSoft));
        ui.tap(chip, kActSubjectDraft, subject.id);
        cx += cw + 6.f;
    }
    y += rowH + 10.f;

    c.drawText(Rect(card.x + 24.f, y, 120.f, 14.f), t("chapter").c_str(), label);
    y += 20.f;
    const Rect input(card.x + 24.f, y, card.w - 48.f, 50.f);
    c.fillRoundRect(input, 14.f, tok(tokens::surface));
    c.strokeRoundRect(input, 14.f, 1.f, tok("#B3FFFFFF"));
    const bool empty = draftTitle_.empty();
    Canvas::TextStyle in = ui.style(20.f, empty ? tok(tokens::mutedSoft) : tok(tokens::ink));
    in.valign = Canvas::TextStyle::Middle;
    c.drawText(Rect(input.x + 14.f, input.y, input.w - 28.f, input.h),
               empty ? t("titlePlaceholder").c_str() : draftTitle_.c_str(), in);
    ui.tap(input, kActAddItem, "focusTitle");
    y += 62.f;

    Canvas::TextStyle modeLabel = ui.style(9.f, tok(tokens::muted));
    modeLabel.valign = Canvas::TextStyle::Middle;
    c.drawText(Rect(card.x + 24.f, y, 80.f, 26.f), t("reviewMode").c_str(), modeLabel);
    const Rect fsrsBtn(card.right() - 24.f - 110.f, y, 52.f, 28.f);
    const Rect fixedBtn(card.right() - 24.f - 52.f, y, 52.f, 28.f);
    const bool fsrs = draftMode_ == 0;
    c.fillRoundRect(fsrsBtn, 14.f, fsrs ? themeButton() : tok(tokens::surface));
    c.strokeRoundRect(fsrsBtn, 14.f, 1.f, fsrs ? themeButton() : tok(tokens::line));
    ui.textCenter(fsrsBtn, t("fsrsMode"), 9.5f, fsrs ? tokStr(themeInk()) : tok(tokens::inkSoft));
    ui.tap(fsrsBtn, kActMode, "", 0);
    c.fillRoundRect(fixedBtn, 14.f, !fsrs ? themeButton() : tok(tokens::surface));
    c.strokeRoundRect(fixedBtn, 14.f, 1.f, !fsrs ? themeButton() : tok(tokens::line));
    ui.textCenter(fixedBtn, t("fixedMode"), 9.5f, !fsrs ? tokStr(themeInk()) : tok(tokens::inkSoft));
    ui.tap(fixedBtn, kActMode, "", 1);
    y += 40.f;

    if (fsrs) {
        // Six dots showing the projected intervals.
        const float step = (card.w - 48.f) / 6.f;
        for (int i = 0; i < 6; ++i) {
            const float a = dotAlpha_[i].value();
            if (a <= 0.01f) continue;
            const float dx = card.x + 24.f + step * (i + 0.5f);
            const float dy = y + 6.f + (1.f - a) * mv(10.f);
            const float r = (i == 0 ? 4.f : 4.f) * (0.5f + 0.5f * a);
            c.pushAlpha(a);
            if (i == 0) {
                c.fillCircle(dx, dy, r, tok(tokens::orange));
            } else {
                c.fillCircle(dx, dy, r, tok(tokens::surface));
                c.strokeCircle(dx, dy, r, 1.5f, tok("#FF9C2C", 0.5f));
            }
            Canvas::TextStyle ds = ui.style(7.5f, i == 0 ? tok("#B16A0A") : tok(tokens::mutedSoft));
            ds.align = Canvas::TextStyle::Center;
            c.drawText(Rect(dx - step * 0.5f, dy + 8.f, step, 12.f), curveDotLabel(i).c_str(), ds);
            c.popAlpha();
        }
        y += 34.f;
        Canvas::TextStyle hint = ui.style(8.5f, tok(tokens::muted));
        hint.align = Canvas::TextStyle::Center;
        c.drawText(Rect(card.x + 24.f, y, card.w - 48.f, 14.f), t("curveForecastHint").c_str(), hint);
        y += 22.f;
    } else {
        const Rect minus(card.x + 24.f, y, 34.f, 30.f);
        const Rect plus(card.right() - 58.f, y, 34.f, 30.f);
        c.fillRoundRect(minus, 10.f, tok(tokens::surface));
        c.strokeRoundRect(minus, 10.f, 1.f, tok(tokens::line));
        ui.textCenter(minus, "-", 18.f, tok(tokens::inkSoft), true);
        ui.tap(minus, kActFixedMinus);
        c.fillRoundRect(plus, 10.f, tok(tokens::surface));
        c.strokeRoundRect(plus, 10.f, 1.f, tok(tokens::line));
        ui.textCenter(plus, "+", 18.f, tok(tokens::inkSoft), true);
        ui.tap(plus, kActFixedPlus);
        ui.textCenter(Rect(minus.right(), y, plus.x - minus.right(), 30.f),
                      t("fixedDaysHint", draftFixedDays_), 10.f, tok(tokens::muted));
        y += 42.f;
    }

    const Rect remind(card.x + 24.f, y, card.w - 48.f, 56.f);
    c.fillRoundRect(remind, 15.f, tok(tokens::yellowSoft));
    c.strokeRoundRect(remind, 15.f, 1.f, tok("#4DFFD687"));
    ui.textLeft(Rect(remind.x + 13.f, remind.y + 8.f, remind.w - 80.f, 18.f), t("remindMe"), 11.f,
                tok(tokens::inkSoft), true);
    ui.textLeft(Rect(remind.x + 13.f, remind.y + 28.f, remind.w - 80.f, 18.f), settings_.reminderTime, 12.f,
                tok(tokens::muted));
    const Rect toggle(remind.right() - 60.f, remind.y + 16.f, 46.f, 24.f);
    c.fillRoundRect(toggle, 12.f, settings_.reminderEnabled ? themeButton() : tok("#D8CEBA"));
    c.fillCircle(settings_.reminderEnabled ? toggle.right() - 12.f : toggle.x + 12.f, toggle.center().y, 10.f,
                 tok("#FFFFFF"));
    ui.tap(toggle, kActReminderToggle);
    y += 68.f;

    const Rect save(card.x + 24.f, y, card.w - 48.f, 50.f);
    ui.pillButton(save, t("save"), 13.f, themeButton(), tokStr(themeInk()), true);
    ui.tap(save, kActSaveItem);
    y += 62.f;
    Canvas::TextStyle local = ui.style(8.5f, tok(tokens::mutedSoft));
    local.align = Canvas::TextStyle::Center;
    c.drawText(Rect(card.x + 24.f, y, card.w - 48.f, 14.f), t("localOnly").c_str(), local);
    c.popClip();
    c.popAlpha();
}

}  // namespace folio