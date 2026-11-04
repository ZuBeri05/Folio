// Overlays: review, item actions, confirm, time picker, composer, pomodoro.
#include <algorithm>
#include <cmath>
#include <cstdio>

#include "platform/platform.h"
#include "ui/app.h"

namespace folio {

namespace {

Color tok(const char* hex, float alphaMul = 1.f) { return parseColor(hex, alphaMul); }
Color tokStr(const std::string& hex, float alphaMul = 1.f) { return parseColor(hex.c_str(), alphaMul); }

constexpr int kActCloseReview = 103;
constexpr int kActPostpone = 104;
constexpr int kActStartRating = 105;
constexpr int kActBackToEntry = 106;
constexpr int kActGrade = 107;
constexpr int kActCloseComposer = 109;
constexpr int kActSaveItem = 110;
constexpr int kActFocusOpen = 115;
constexpr int kActFocusClose = 116;
constexpr int kActFocusStart = 117;
constexpr int kActFocusPause = 118;
constexpr int kActFocusEnd = 119;
constexpr int kActCloseSummary = 120;
constexpr int kActCloseActions = 130;
constexpr int kActEditItem = 131;
constexpr int kActDeleteFromAction = 132;
constexpr int kActCloseConfirm = 133;
constexpr int kActDoDelete = 134;
constexpr int kActCancelConfirm = 135;
constexpr int kActHourDown = 139;
constexpr int kActHourUp = 140;
constexpr int kActMinuteDown = 141;
constexpr int kActMinuteUp = 142;
constexpr int kActTimeCancel = 143;
constexpr int kActTimeConfirm = 144;
constexpr int kActSaveEdit = 147;
constexpr int kActSubjectEdit = 146;
constexpr int kActTab = 100;

}  // namespace

void App::drawReviewOverlay(Ui& ui) {
    Canvas& c = ui.canvas();
    c.pushAlpha(reviewOpacity_.value());
    c.fillRect(c.bounds(), tok(tokens::dim));
    ui.tap(c.bounds(), kActCloseReview);

    const float w = vpWidth_;
    const float h = vpHeight_;
    const bool wide = isWide_;
    const float cardW = wide ? std::min(680.f, w - 80.f) : w - 32.f;
    const float cardH = wide ? 320.f : 300.f;
    const float cx = (w - cardW) * 0.5f;
    const float cy = (h - cardH) * 0.5f;
    const float s = reviewScale_.value();
    const Rect card(w * 0.5f + (cx - w * 0.5f) * s, h * 0.5f + (cy - h * 0.5f) * s, cardW * s, cardH * s);

    if (reviewStage_ == 1) {
        drawRatingCard(ui, card);
    } else {
        drawEntryCard(ui, card);
    }
    c.popAlpha();
}

void App::drawEntryCard(Ui& ui, const Rect& card) {
    Canvas& c = ui.canvas();
    ui.card(card, 28.f, tok(tokens::surface), Color(1, 1, 1, 0.8f), 1.f, 40.f, 0.14f, 20.f);
    const float pad = isWide_ ? 32.f : 22.f;
    const Rect inner = card.inset(pad);

    ui.textLeft(Rect(inner.x, inner.y, 100.f, 18.f), findSubject(reviewItem_.subjectId).name, 10.f,
                tok(tokens::muted), true);
    ui.textLeft(Rect(inner.x + 78.f, inner.y, 80.f, 18.f), t("reviewN", reviewItem_.reviewCount + 1), 9.f,
                tok(tokens::mutedSoft));
    const Rect closeBtn(inner.right() - 44.f, inner.y - 2.f, 44.f, 26.f);
    c.fillRoundRect(closeBtn, 13.f, tok(tokens::yellowSoft));
    ui.textCenter(closeBtn, t("close"), 9.f, tok("#6C4B00"));
    ui.tap(closeBtn, kActCloseReview);

    Canvas::TextStyle title = ui.style(isWide_ ? 38.f : 30.f, tok(tokens::ink), true);
    title.letterSpacing = -1.f;
    title.valign = Canvas::TextStyle::Top;
    title.maxLines = 3;
    title.wrap = true;
    title.lineHeight = (isWide_ ? 46.f : 38.f);
    c.drawText(Rect(inner.x, inner.y + 32.f, inner.w, (isWide_ ? 138.f : 114.f)), reviewItem_.title.c_str(), title);

    const long long lastAt = reviewItem_.lastReviewedAt > 0 ? reviewItem_.lastReviewedAt : reviewItem_.createdAt;
    ui.textLeft(Rect(inner.x, inner.y + 148.f, inner.w, 16.f), t("lastReview", shortDate(lastAt)), 10.5f,
                tok(tokens::muted));

    c.fillRect(Rect(inner.x, inner.bottom() - 74.f, inner.w, 1.f), tok(tokens::line));
    const float btnY = inner.bottom() - 48.f;
    const float halfW = (inner.w - 10.f) * 0.5f;
    const Rect later(inner.x, btnY, halfW, 48.f);
    c.fillRoundRect(later, 14.f, tok(tokens::surfaceSoft));
    c.strokeRoundRect(later, 14.f, 1.f, tok(tokens::line));
    ui.textCenter(later, t("postponeTomorrow"), 12.f, tok(tokens::inkSoft));
    ui.tap(later, kActPostpone);

    const Rect done(inner.x + halfW + 10.f, btnY, halfW, 48.f);
    ui.pillButton(done, t("completeReview"), 12.f, themeButton(), tokStr(themeInk()), false);
    ui.tap(done, kActStartRating);
}

void App::drawRatingCard(Ui& ui, const Rect& card) {
    Canvas& c = ui.canvas();
    ui.card(card, 28.f, tok(tokens::surface), Color(1, 1, 1, 0.8f), 1.f, 40.f, 0.14f, 20.f);
    const float pad = isWide_ ? 32.f : 22.f;
    const Rect inner = card.inset(pad);

    const Rect back(inner.x, inner.y - 2.f, 30.f, 30.f);
    c.fillRoundRect(back, 15.f, tok(tokens::yellowSoft));
    ui.textCenter(back, "\u2190", 14.f, tok("#6C4B00"));
    ui.tap(back, kActBackToEntry);
    ui.textLeft(Rect(inner.x + 40.f, inner.y, 100.f, 18.f), findSubject(reviewItem_.subjectId).name, 10.f,
                tok(tokens::muted), true);
    const Rect closeBtn(inner.right() - 44.f, inner.y - 2.f, 44.f, 26.f);
    c.fillRoundRect(closeBtn, 13.f, tok(tokens::yellowSoft));
    ui.textCenter(closeBtn, t("close"), 9.f, tok("#6C4B00"));
    ui.tap(closeBtn, kActCloseReview);

    Canvas::TextStyle title = ui.style(isWide_ ? 30.f : 24.f, tok(tokens::ink), true);
    title.letterSpacing = -0.8f;
    title.valign = Canvas::TextStyle::Top;
    title.maxLines = 2;
    title.wrap = true;
    title.lineHeight = (isWide_ ? 38.f : 32.f);
    c.drawText(Rect(inner.x, inner.y + 34.f, inner.w, (isWide_ ? 76.f : 64.f)), reviewItem_.title.c_str(), title);

    float y = inner.y + (isWide_ ? 118.f : 104.f);
    c.fillRect(Rect(inner.x, y, inner.w, 1.f), tok(tokens::line));
    y += 18.f;
    ui.textLeft(Rect(inner.x, y, inner.w, 18.f), t("rateTitle"), isWide_ ? 20.f : 18.f, tok(tokens::ink), true);
    y += 26.f;
    const std::string retention = t("retentionTitle") + " " +
                                  std::to_string(static_cast<int>(std::lround(settings_.targetRetention * 100))) + "%";
    ui.textLeft(Rect(inner.x, y, inner.w, 16.f), retention, 11.f, tok(tokens::muted));
    y += 22.f;

    // Four grade cards, 2x2 on phones and 1x4 on tablets.
    const bool wide = isWide_;
    const int cols = wide ? 4 : 2;
    const float gapX = 10.f;
    const float cardW = (inner.w - gapX * (cols - 1)) / cols;
    const float cardH = wide ? 96.f : 84.f;
    for (int grade = 1; grade <= 4; ++grade) {
        const int index = grade - 1;
        const int col = wide ? index : index % 2;
        const int row = wide ? 0 : index / 2;
        const float px = inner.x + col * (cardW + gapX);
        const float py = y + row * (cardH + 10.f);
        const float sc = pressedGrade_ == grade ? 0.96f : 1.f;
        const float w2 = cardW * sc;
        const float h2 = cardH * sc;
        const Rect gc(px + (cardW - w2) * 0.5f, py + (cardH - h2) * 0.5f, w2, h2);
        c.fillRoundRect(gc, 16.f, gradeTint(grade, "#14"));
        c.strokeRoundRect(gc, 16.f, 1.f, gradeTint(grade, "#3D"));
        c.fillCircle(gc.x + 16.f, gc.y + 22.f, 3.5f, gradeColor(grade));
        Canvas::TextStyle gl = ui.style(wide ? 14.f : 13.f, gradeColor(grade), true);
        gl.valign = Canvas::TextStyle::Middle;
        c.drawText(Rect(gc.x + 25.f, gc.y + 12.f, gc.w - 34.f, 20.f), gradeLabel(grade).c_str(), gl);
        Canvas::TextStyle gm = ui.style(wide ? 9.5f : 9.f, tok(tokens::muted));
        gm.wrap = true;
        gm.maxLines = 2;
        gm.lineHeight = wide ? 13.f : 12.f;
        gm.valign = Canvas::TextStyle::Top;
        c.drawText(Rect(gc.x + 14.f, gc.y + 38.f, gc.w - 26.f, wide ? 26.f : 24.f), gradeMeaning(grade).c_str(), gm);
        Canvas::TextStyle gi = ui.style(wide ? 16.f : 15.f, tok(tokens::ink), true);
        gi.valign = Canvas::TextStyle::Top;
        c.drawText(Rect(gc.x + 14.f, gc.y + gc.h - 30.f, gc.w - 26.f, 22.f), gradeIntervalText(grade).c_str(), gi);
        ui.tap(gc, kActGrade, "", grade);
    }
}

void App::drawConfirmOverlay(Ui& ui) {
    Canvas& c = ui.canvas();
    c.fillRect(c.bounds(), tok(tokens::dim));
    ui.tap(c.bounds(), kActCancelConfirm);
    const float w = vpWidth_;
    const float h = vpHeight_;
    const float cardW = isWide_ ? 440.f : w * 0.88f;
    const float cardH = 244.f;
    const float s = confirmScale_.value();
    const Rect card(w * 0.5f + (-cardW * 0.5f) * s, h * 0.5f + (-cardH * 0.5f) * s, cardW * s, cardH * s);
    ui.card(card, 24.f, tok(tokens::surface), Color(1, 1, 1, 0.8f), 1.f, 40.f, 0.14f, 20.f);
    const Rect inner = card.inset(24.f);
    Canvas::TextStyle title = ui.style(22.f, tok(tokens::ink), true);
    title.wrap = true;
    title.maxLines = 2;
    title.lineHeight = 28.f;
    c.drawText(Rect(inner.x, inner.y, inner.w, 56.f), confirmTitle_.c_str(), title);
    Canvas::TextStyle msg = ui.style(11.f, tok(tokens::muted));
    msg.wrap = true;
    msg.maxLines = 3;
    msg.lineHeight = 18.f;
    c.drawText(Rect(inner.x, inner.y + 62.f, inner.w, 54.f), confirmMessage_.c_str(), msg);

    const Rect danger(inner.x, inner.bottom() - 88.f, inner.w, 46.f);
    ui.pillButton(danger, confirmKind_ == 0 ? t("deleteSubjectTitle") : t("deleteRecordTitle"), 13.f,
                  themeButton(), tokStr(themeInk()), true);
    ui.tap(danger, kActDoDelete);
    const Rect cancel(inner.x, inner.bottom() - 38.f, inner.w, 38.f);
    ui.textCenter(cancel, t("cancel"), 12.f, tok(tokens::muted));
    ui.tap(cancel, kActCancelConfirm);
}

void App::drawTimePickerOverlay(Ui& ui) {
    Canvas& c = ui.canvas();
    c.fillRect(c.bounds(), tok(tokens::dim));
    ui.tap(c.bounds(), kActTimeCancel);
    const float w = vpWidth_;
    const float h = vpHeight_;
    const float cardW = 198.f;
    const float cardH = 226.f;
    const float s = timePickerScale_.value();
    const Rect card(w * 0.5f + (-cardW * 0.5f) * s, h * 0.5f + (-cardH * 0.5f) * s, cardW * s, cardH * s);
    ui.card(card, 22.f, tok(tokens::surface), Color(1, 1, 1, 0.8f), 1.f, 36.f, 0.14f, 16.f);

    // Two columns of +/- buttons with the selected value in the middle, which
    // stands in for ArkUI's TextPicker (a wheel is overkill for 24x60 values).
    auto column = [&](float x, int value, int actionDown, int actionUp) {
        const Rect up(x, card.y + 14.f, 58.f, 30.f);
        c.fillRoundRect(up, 10.f, tok(tokens::surfaceSoft));
        ui.textCenter(up, "\u25B4", 12.f, tok(tokens::mutedSoft));
        ui.tap(up, actionUp);
        const Rect mid(x, card.y + 56.f, 58.f, 60.f);
        c.fillRoundRect(mid, 14.f, tok(tokens::yellowSoft));
        char buf[4];
        std::snprintf(buf, sizeof(buf), "%02d", value);
        ui.textCenter(mid, buf, 26.f, tok(tokens::ink), true);
        const Rect down(x, card.y + 128.f, 58.f, 30.f);
        c.fillRoundRect(down, 10.f, tok(tokens::surfaceSoft));
        ui.textCenter(down, "\u25BE", 12.f, tok(tokens::mutedSoft));
        ui.tap(down, actionDown);
    };
    column(card.x + 22.f, pickerHour_, kActHourDown, kActHourUp);
    ui.textCenter(Rect(card.x + 82.f, card.y + 56.f, 34.f, 60.f), ":", 19.f, tok(tokens::ink), true);
    column(card.x + card.w - 80.f, pickerMinute_, kActMinuteDown, kActMinuteUp);

    const float btnY = card.bottom() - 52.f;
    const Rect cancel(card.x + 10.f, btnY, (card.w - 20.f) * 0.5f, 42.f);
    ui.textCenter(cancel, t("cancel"), 12.5f, tok(tokens::muted));
    ui.tap(cancel, kActTimeCancel);
    const Rect ok(card.x + 10.f + (card.w - 20.f) * 0.5f, btnY, (card.w - 20.f) * 0.5f, 42.f);
    ui.textCenter(ok, t("confirm"), 12.5f, themeButton(), true);
    ui.tap(ok, kActTimeConfirm);
}

void App::drawItemActionsOverlay(Ui& ui) {
    Canvas& c = ui.canvas();
    c.pushAlpha(actionOverlayOpacity_.value());
    c.fillRect(c.bounds(), tok(tokens::dim));
    ui.tap(c.bounds(), kActCloseActions);

    const float w = vpWidth_;
    const float h = vpHeight_;
    const float cardW = isWide_ ? 560.f : w * 0.92f;
    const float cardH = actionMode_ == 0 ? 330.f : 360.f;
    const float s = actionScale_.value();
    const Rect card(w * 0.5f + (-cardW * 0.5f) * s, h * 0.5f + (-cardH * 0.5f) * s, cardW * s, cardH * s);
    ui.card(card, 26.f, tok(tokens::surface), Color(1, 1, 1, 0.8f), 1.f, 40.f, 0.14f, 20.f);
    const Rect inner = card.inset(24.f);

    c.pushAlpha(actionContentOpacity_);
    ui.textLeft(Rect(inner.x, inner.y, 120.f, 18.f), actionMode_ == 0 ? t("detailRecord") : t("editRecord"), 11.f,
                tok(tokens::muted));
    const Rect closeBtn(inner.right() - 50.f, inner.y - 3.f, 50.f, 30.f);
    c.fillRoundRect(closeBtn, 14.f, tok(tokens::yellowSoft));
    ui.textCenter(closeBtn, t("close"), 9.f, tok("#6C4B00"));
    ui.tap(closeBtn, kActCloseActions);

    Canvas::TextStyle title = ui.style(26.f, tok(tokens::ink), true);
    title.wrap = true;
    title.maxLines = 2;
    title.lineHeight = 32.f;
    c.drawText(Rect(inner.x, inner.y + 34.f, inner.w, 68.f), actionItem_.title.c_str(), title);

    const std::string meta = findSubject(actionItem_.subjectId).name + "  ·  " + t("next") + " " +
                             shortDate(actionItem_.nextReviewAt);
    ui.textLeft(Rect(inner.x, inner.y + 104.f, inner.w, 16.f), meta, 10.f, tok(tokens::muted));

    const Rect stats(inner.x, inner.y + 130.f, inner.w, 64.f);
    c.fillRoundRect(stats, 14.f, tok(tokens::surfaceSoft));
    const float third = stats.w / 3.f;
    const char* labels[3] = {"created", "reviewed", "currentInterval"};
    const std::string values[3] = {shortDate(actionItem_.createdAt), t("times", actionItem_.reviewCount),
                                   t("days", actionItem_.currentIntervalDays)};
    for (int i = 0; i < 3; ++i) {
        ui.textLeft(Rect(stats.x + 12.f + third * i, stats.y + 12.f, third - 20.f, 14.f), t(labels[i]), 8.f,
                    tok(tokens::mutedSoft));
        ui.textLeft(Rect(stats.x + 12.f + third * i, stats.y + 30.f, third - 20.f, 18.f), values[i], 11.f,
                    tok(tokens::inkSoft));
    }

    if (actionMode_ == 0) {
        const Rect modify(inner.x, inner.bottom() - 44.f, (inner.w - 10.f) * 0.5f, 44.f);
        ui.pillButton(modify, t("modify"), 12.f, themeButton(), tokStr(themeInk()), true);
        ui.tap(modify, kActEditItem);
        const Rect del(inner.x + (inner.w - 10.f) * 0.5f + 10.f, inner.bottom() - 44.f, (inner.w - 10.f) * 0.5f, 44.f);
        c.fillRoundRect(del, 13.f, tok("#FFE9E4"));
        ui.textCenter(del, t("deleteAction"), 12.f, tok("#C7422C"), true);
        ui.tap(del, kActDeleteFromAction);
    } else {
        float y = inner.y + 208.f;
        ui.textLeft(Rect(inner.x, y, inner.w, 14.f), t("titleLabel"), 9.f, tok(tokens::muted));
        y += 18.f;
        const Rect input(inner.x, y, inner.w, 44.f);
        c.fillRoundRect(input, 12.f, tok(tokens::surface));
        c.strokeRoundRect(input, 12.f, 1.f, tok("#B3FFFFFF"));
        Canvas::TextStyle in = ui.style(15.f, tok(tokens::ink));
        in.valign = Canvas::TextStyle::Middle;
        c.drawText(Rect(input.x + 12.f, input.y, input.w - 24.f, input.h), editTitle_.c_str(), in);
        ui.tap(input, kActEditItem);
        y += 56.f;
        ui.textLeft(Rect(inner.x, y, inner.w, 14.f), t("subject"), 9.f, tok(tokens::muted));
        y += 18.f;
        float cx = inner.x;
        for (const auto& subject : subjects_) {
            const float cw = ui.measure(subject.name, 10.f, false) + 22.f;
            if (cx + cw > inner.right()) {
                cx = inner.x;
                y += 36.f;
            }
            const Rect chip(cx, y, cw, 30.f);
            const bool active = editSubjectId_ == subject.id;
            c.fillRoundRect(chip, 15.f, active ? themeButton() : tok(tokens::surface));
            c.strokeRoundRect(chip, 15.f, 1.f, active ? themeButton() : tok(tokens::line));
            ui.textCenter(chip, subject.name, 10.f, active ? tokStr(themeInk()) : tok(tokens::inkSoft));
            ui.tap(chip, kActSubjectEdit, subject.id);
            cx += cw + 6.f;
        }
        const Rect save(inner.x, inner.bottom() - 42.f, (inner.w - 10.f) * 0.5f, 42.f);
        c.fillRoundRect(save, 12.f, themeButton());
        ui.textCenter(save, t("save"), 12.f, tokStr(themeInk()), true);
        ui.tap(save, kActSaveEdit);
        const Rect cancel(inner.x + (inner.w - 10.f) * 0.5f + 10.f, inner.bottom() - 42.f,
                          (inner.w - 10.f) * 0.5f, 42.f);
        c.fillRoundRect(cancel, 12.f, tok(tokens::surfaceSoft));
        ui.textCenter(cancel, t("cancel"), 12.f, tok(tokens::inkSoft));
        ui.tap(cancel, kActCloseActions);
    }
    c.popAlpha();
    c.popAlpha();
}

void App::drawComposerOverlay(Ui& ui) {
    Canvas& c = ui.canvas();
    c.pushAlpha(composerDim_.value());
    c.fillRect(c.bounds(), tok(tokens::dim));
    c.popAlpha();
    const float w = vpWidth_;
    const float h = vpHeight_;
    const float cardW = std::min(430.f, w * 0.92f);
    const float cardH = h * 0.84f;
    const float s = composerScale_.value();
    const Rect card(w * 0.5f + (-cardW * 0.5f) * s, h * 0.5f + (-cardH * 0.5f) * s + composerShift_.value(),
                    cardW * s, cardH * s);
    c.pushAlpha(composerOpacity_.value());
    drawComposerPane(ui, card, true);
    c.popAlpha();
}

void App::drawFocusClockOverlay(Ui& ui) {
    Canvas& c = ui.canvas();
    const float w = vpWidth_;
    const float h = vpHeight_;
    const float s = clockScale_.value();
    c.pushAlpha(std::min(1.f, s));
    c.fillRect(c.bounds(), pageBg());
    ui.tap(c.bounds(), kActFocusClose);

    const Rect closeBtn(w - 60.f, 32.f, 44.f, 44.f);
    ui.textCenter(closeBtn, "\u00D7", 24.f, tok(tokens::muted));
    ui.tap(closeBtn, kActFocusClose);

    const float size = clockSize() * s;
    const float cx = w * 0.5f;
    const float cy = h * 0.5f - 10.f;
    const float radius = size * 0.5f;

    // Background ring and the depleting arc.
    c.strokeCircle(cx, cy, radius - size * 0.016f, std::max(9.f, size * 0.032f), tok("#2E5E4B30"));
    const float pct = focusRunning_ ? focusRemainingPercent() : 100.f;
    if (pct > 0.5f) {
        c.strokeArc(cx, cy, radius - size * 0.016f, std::max(9.f, size * 0.032f), 0.f,
                    static_cast<float>(2.0 * 3.14159265358979) * (pct / 100.f), clockAccent());
    }

    // One tick per minute around the ring; elapsed ticks fade out.
    const int ticks = tickCount();
    for (int i = 0; i < ticks; ++i) {
        const float angle = static_cast<float>(i) * 2.f * 3.14159265358979f / static_cast<float>(ticks);
        const float tickR = radius * 0.94f;
        const float tx = cx + std::sin(angle) * tickR;
        const float ty = cy - std::cos(angle) * tickR;
        const float tw = std::max(2.f, size * 0.008f);
        const float th = std::max(4.f, size * 0.02f);
        c.pushAlpha(tickOpacity(i));
        c.fillRoundRect(Rect(tx - tw * 0.5f, ty - th * 0.5f, tw, th), tw * 0.5f, clockAccent());
        c.popAlpha();
    }

    const Rect tomatoBox(cx - size * 0.055f, cy - size * 0.20f, size * 0.11f, size * 0.11f);
    drawIcon(ui, tomatoBox, kIconTomato);

    if (focusRunning_) {
        Canvas::TextStyle clock = ui.style(size * 0.26f, focusPaused_ ? tok(tokens::muted) : tok(tokens::ink), true);
        clock.align = Canvas::TextStyle::Center;
        clock.valign = Canvas::TextStyle::Middle;
        c.drawText(Rect(cx - size * 0.5f, cy - size * 0.06f, size, size * 0.2f), focusClockText().c_str(), clock);
        Canvas::TextStyle round = ui.style(std::max(12.f, size * 0.055f), tok(tokens::muted));
        round.align = Canvas::TextStyle::Center;
        c.drawText(Rect(cx - size * 0.5f, cy + size * 0.13f, size, 20.f), roundLabel().c_str(), round);
    } else {
        Canvas::TextStyle mins = ui.style(size * 0.15f, tok(tokens::ink), true);
        mins.align = Canvas::TextStyle::Center;
        mins.valign = Canvas::TextStyle::Middle;
        c.drawText(Rect(cx - size * 0.5f, cy - size * 0.03f, size, size * 0.16f),
                   minutesLabel(settings_.focusMinutes).c_str(), mins);
        Canvas::TextStyle label = ui.style(std::max(10.f, size * 0.045f), tok(tokens::mutedSoft));
        label.align = Canvas::TextStyle::Center;
        c.drawText(Rect(cx - size * 0.5f, cy + size * 0.12f, size, 18.f), t("focusTitle").c_str(), label);
    }

    if (focusRunning_) {
        ui.textCenter(Rect(cx - size * 0.5f, cy + radius + 22.f, size, 20.f),
                      t("focusElapsed", elapsedClockText()) + " · " + minutesLabel(focusPlannedMinutes_), 13.f,
                      tok(tokens::mutedSoft));
        const Rect pause(cx - 150.f, h - 88.f, 140.f, 44.f);
        ui.textCenter(pause, focusPaused_ ? t("focusResume") : t("focusPause"), 14.f, tok(tokens::inkSoft));
        ui.tap(pause, kActFocusPause);
        const Rect end(cx + 8.f, h - 88.f, 140.f, 44.f);
        ui.textCenter(end, t("focusEnd"), 14.f, tok(tokens::coral));
        ui.tap(end, kActFocusEnd);
    } else {
        const Rect startBtn(cx - 80.f, h - 96.f, 160.f, 46.f);
        ui.pillButton(startBtn, t("focusStartCycle"), 14.f, themeButton(), tokStr(themeInk()), false);
        ui.tap(startBtn, kActFocusStart);
    }
    c.popAlpha();
}

void App::drawFocusSummaryOverlay(Ui& ui) {
    Canvas& c = ui.canvas();
    c.fillRect(c.bounds(), tok(tokens::dim));
    ui.tap(c.bounds(), kActCloseSummary);
    const float w = vpWidth_;
    const float h = vpHeight_;
    const float cardW = 244.f;
    const float cardH = 220.f;
    const float s = summaryScale_.value();
    const Rect card(w * 0.5f + (-cardW * 0.5f) * s, h * 0.5f + (-cardH * 0.5f) * s, cardW * s, cardH * s);
    ui.card(card, 24.f, tok(tokens::surface), Color(1, 1, 1, 0.8f), 1.f, 36.f, 0.14f, 16.f);
    const Rect inner = card.inset(14.f);
    Canvas::TextStyle label = ui.style(11.f, tok(tokens::muted));
    label.align = Canvas::TextStyle::Center;
    c.drawText(Rect(inner.x, inner.y + 8.f, inner.w, 16.f), t("focusSummary").c_str(), label);
    Canvas::TextStyle mins = ui.style(34.f, tok(tokens::ink), true);
    mins.align = Canvas::TextStyle::Center;
    mins.letterSpacing = -0.5f;
    c.drawText(Rect(inner.x, inner.y + 28.f, inner.w, 44.f), minutesLabel(summaryMinutes_).c_str(), mins);
    Canvas::TextStyle reviewed = ui.style(11.5f, tok(tokens::inkSoft));
    reviewed.align = Canvas::TextStyle::Center;
    c.drawText(Rect(inner.x, inner.y + 76.f, inner.w, 18.f),
               t("focusReviewed", summaryItems_, std::to_string(summaryRemembered_)).c_str(), reviewed);
    Canvas::TextStyle seg = ui.style(10.f, tok(tokens::mutedSoft));
    seg.align = Canvas::TextStyle::Center;
    const std::string line = t("focusSegments", summarySegments_) + " · " + clockLabel(summaryStart_) + " – " +
                             clockLabel(summaryEnd_);
    c.drawText(Rect(inner.x, inner.y + 100.f, inner.w, 16.f), line.c_str(), seg);
    const Rect done(inner.x, inner.bottom() - 46.f, inner.w, 44.f);
    ui.textCenter(done, t("focusDone"), 12.f, themeButton(), true);
    ui.tap(done, kActCloseSummary);
}

void App::drawFocusMiniBar(Ui& ui) {
    Canvas& c = ui.canvas();
    const float w = isWide_ ? std::min(520.f, vpWidth_ - 200.f) : vpWidth_ - 40.f;
    const Rect bar((vpWidth_ - w) * 0.5f, vpHeight_ - 128.f, w, 36.f);
    c.fillRoundRect(bar, 18.f, tok(tokens::surfaceSoft));
    c.strokeRoundRect(bar, 18.f, 1.f, tok("#A6FFC531"));
    c.pushAlpha(focusPaused_ ? 0.4f : 1.f);
    drawIcon(ui, Rect(bar.x + 14.f, bar.y + 8.f, 18.f, 18.f), kIconTomato);
    c.popAlpha();
    ui.textLeft(Rect(bar.x + 40.f, bar.y, 70.f, bar.h), focusClockText(), 12.f, tok(tokens::ink), true);
    ui.textLeft(Rect(bar.x + 104.f, bar.y, 120.f, bar.h),
                focusIsBreak_ ? t("focusBreaking") : t("focusCardTitle"), 9.5f, tok(tokens::muted));
    ui.textRight(Rect(bar.right() - 30.f, bar.y, 22.f, bar.h), "\u203A", 13.f, tok(tokens::mutedSoft));
    ui.tap(bar, kActTab, "", 0);
}

void App::drawToast(Ui& ui) {
    if (toastOpacity_.value() <= 0.01f) return;
    Canvas& c = ui.canvas();
    const std::string text = toastText_;
    Canvas::TextStyle st = ui.style(12.f, Color(1, 1, 1, 1));
    st.maxLines = 2;
    st.wrap = true;
    st.lineHeight = 17.f;
    const float maxW = vpWidth_ * 0.7f;
    const float tw = std::min(maxW, ui.measure(text, 12.f, false) + 40.f);
    const Rect box((vpWidth_ - tw) * 0.5f, vpHeight_ - 150.f, tw, 48.f);
    c.pushAlpha(toastOpacity_.value());
    c.fillRoundRect(box, 14.f, Color(0.13f, 0.11f, 0.08f, 0.92f));
    Canvas::TextStyle centered = st;
    centered.align = Canvas::TextStyle::Center;
    centered.valign = Canvas::TextStyle::Middle;
    c.drawText(box.inset(12.f, 6.f), text.c_str(), centered);
    c.popAlpha();
}

}  // namespace folio