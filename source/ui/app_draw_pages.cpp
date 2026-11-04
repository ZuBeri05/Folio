// Records, calendar, settings and the bottom navigation.
#include <algorithm>
#include <cmath>
#include <cstdio>

#include "platform/platform.h"
#include "ui/app.h"

namespace folio {

namespace {

Color tok(const char* hex, float alphaMul = 1.f) { return parseColor(hex, alphaMul); }
Color tokStr(const std::string& hex, float alphaMul = 1.f) { return parseColor(hex.c_str(), alphaMul); }

constexpr int kActTab = 100;
constexpr int kActItemActions = 129;
constexpr int kActCalendarDays = 121;
constexpr int kActMaxInterval = 122;
constexpr int kActFocusMinutes = 123;
constexpr int kActTheme = 124;
constexpr int kActLanguage = 125;
constexpr int kActRetentionToggle = 126;
constexpr int kActRetentionDown = 127;
constexpr int kActRetentionUp = 128;
constexpr int kActDeleteSubject = 136;
constexpr int kActAddSubject = 145;
constexpr int kActReminderToggle = 137;
constexpr int kActOpenTimePicker = 138;

}  // namespace

void App::drawBottomNav(Ui& ui, const Rect& area) {
    Canvas& c = ui.canvas();
    ui.card(area, 30.f, tok(tokens::surface), Color(1, 1, 1, 0.8f), 1.f, 22.f, 0.1f, 8.f);
    const float w = area.w / 4.f;
    for (int i = 0; i < 4; ++i) {
        const Rect cell(area.x + w * i, area.y, w, area.h);
        const bool active = tab_ == i;
        const float scale = active ? 1.08f : 1.f;
        const Rect icon(cell.center().x - 11.f * scale, cell.y + 12.f, 22.f * scale, 22.f * scale);
        drawIcon(ui, icon, navIcon(i, active), active ? 1.f : 0.5f);
        Canvas::TextStyle st = ui.style(8.f, active ? tok("#6C4B00") : tok(tokens::mutedSoft));
        st.align = Canvas::TextStyle::Center;
        c.drawText(Rect(cell.x, cell.y + 38.f, cell.w, 14.f), navLabel(i).c_str(), st);
        ui.tap(cell, kActTab, "", i);
    }
}

Color App::nullTint() const { return Color(1.f, 1.f, 1.f, 1.f); }

void App::drawRecordsPage(Ui& ui, const Rect& area) {
    Canvas& c = ui.canvas();
    const float pad = isWide_ ? 52.f : 20.f;
    const Rect inner(area.x + pad, area.y, area.w - pad * 2, area.h);
    c.pushClip(inner);

    Canvas::TextStyle h = ui.style(isWide_ ? 44.f : 32.f, tok(tokens::ink), true);
    h.valign = Canvas::TextStyle::Middle;
    c.drawText(Rect(inner.x, inner.y + 10.f, inner.w - 90.f, isWide_ ? 56.f : 42.f), t("recordsTitle").c_str(), h);
    Canvas::TextStyle n = ui.style(11.f, tok(tokens::muted));
    n.align = Canvas::TextStyle::Right;
    n.valign = Canvas::TextStyle::Middle;
    c.drawText(Rect(inner.right() - 90.f, inner.y + 10.f, 90.f, 42.f),
               t("items", static_cast<int>(items_.size())).c_str(), n);

    float y = inner.y + (isWide_ ? 76.f : 62.f);
    if (!doneSessions_.empty()) {
        drawFocusWeekCard(ui, Rect(inner.x, y, isWide_ ? std::min(560.f, inner.w) : inner.w, 96.f));
        y += 114.f;
    }

    const auto sorted = sortedItems();
    if (sorted.empty()) {
        Canvas::TextStyle empty = ui.style(14.f, tok(tokens::muted));
        c.drawText(Rect(inner.x, y + 60.f, inner.w, 22.f), t("noRecords").c_str(), empty);
        c.popClip();
        return;
    }

    const float rowH = recRowH_;
    const float startY = y;
    c.pushClip(Rect(inner.x, startY, inner.w, inner.bottom() - startY));
    for (size_t i = 0; i < sorted.size() && i < 12; ++i) {
        const auto& item = sorted[i];
        const float progress = recIn_[std::min<size_t>(i, 11)];
        const float rowY = startY + static_cast<float>(i) * (rowH + 10.f);
        if (rowY > inner.bottom()) break;

        // Timeline: the vertical line grows down and drags the card out with it.
        const float lineX = inner.x + 7.f;
        const Rect line(lineX, rowY, 1.5f, rowH + 10.f);
        c.pushAlpha(progress);
        c.fillRect(Rect(line.x, line.y, line.w, line.h), tok(tokens::lineStrong));

        Canvas::TextStyle date = ui.style(11.f, tok(tokens::muted));
        date.valign = Canvas::TextStyle::Top;
        c.drawText(Rect(inner.x + 20.f, rowY + 16.f, 62.f, 16.f), shortDate(item.createdAt).c_str(), date);
        Canvas::TextStyle wd = ui.style(9.f, tok(tokens::mutedSoft));
        wd.valign = Canvas::TextStyle::Top;
        c.drawText(Rect(inner.x + 20.f, rowY + 34.f, 62.f, 14.f), weekday(item.createdAt).c_str(), wd);

        const float cardX = inner.x + 92.f + (1.f - progress) * -mv(26.f);
        const Rect card(cardX, rowY, inner.right() - cardX, rowH);
        ui.card(card, 18.f, tok(tokens::surfaceSoft), tok("#B3FFFFFF"), 1.f, 0.f, 0.f, 0.f);
        Canvas::TextStyle subj = ui.style(9.5f, colorOf(findSubject(item.subjectId).color));
        subj.valign = Canvas::TextStyle::Top;
        c.drawText(Rect(card.x + 16.f, card.y + 16.f, card.w - 130.f, 14.f),
                   findSubject(item.subjectId).name.c_str(), subj);
        Canvas::TextStyle title = ui.style(16.f, tok(tokens::ink));
        title.valign = Canvas::TextStyle::Top;
        title.marquee = true;
        c.drawText(Rect(card.x + 16.f, card.y + 32.f, card.w - 130.f, 22.f), item.title.c_str(), title);
        Canvas::TextStyle nextLabel = ui.style(8.f, tok(tokens::mutedSoft));
        nextLabel.align = Canvas::TextStyle::Right;
        nextLabel.valign = Canvas::TextStyle::Top;
        c.drawText(Rect(card.right() - 108.f, card.y + 16.f, 80.f, 14.f), t("next").c_str(), nextLabel);
        Canvas::TextStyle nextDate = ui.style(10.f, tok(tokens::muted));
        nextDate.align = Canvas::TextStyle::Right;
        nextDate.valign = Canvas::TextStyle::Top;
        c.drawText(Rect(card.right() - 108.f, card.y + 32.f, 80.f, 16.f), shortDate(item.nextReviewAt).c_str(),
                   nextDate);
        ui.tap(card, kActItemActions, item.id);
        c.popAlpha();
    }
    c.popClip();
    c.popClip();
}

void App::drawFocusWeekCard(Ui& ui, const Rect& area) {
    Canvas& c = ui.canvas();
    ui.card(area, 18.f, tok(tokens::surfaceSoft), tok("#B3FFFFFF"), 1.f, 0.f, 0.f, 0.f);
    Canvas::TextStyle h = ui.style(10.5f, tok(tokens::muted), true);
    h.valign = Canvas::TextStyle::Middle;
    c.drawText(Rect(area.x + 16.f, area.y + 8.f, 160.f, 16.f), t("focusCardTitle").c_str(), h);
    Canvas::TextStyle total = ui.style(10.f, tok(tokens::mutedSoft));
    total.align = Canvas::TextStyle::Right;
    total.valign = Canvas::TextStyle::Middle;
    const std::string line = t("focusTodayTotal", minutesLabel(todayFocusMinutes()), todayFocusCount());
    c.drawText(Rect(area.right() - 216.f, area.y + 8.f, 200.f, 16.f), line.c_str(), total);

    const auto buckets = weekFocus();
    const float cellW = (area.w - 32.f) / 7.f;
    const int todayIndex = todayWeekIndex();
    for (int i = 0; i < 7; ++i) {
        const float barH = weekBarHeight(buckets[i]);
        const float cx = area.x + 16.f + cellW * i + cellW * 0.5f;
        const Rect bar(cx - 9.f, area.y + 66.f - barH, 18.f, barH);
        c.fillRoundRect(bar, 3.f, i == todayIndex ? tok(tokens::coral) : tok("#E8DCC4"));
        Canvas::TextStyle wd = ui.style(8.f, i == todayIndex ? tok(tokens::coral) : tok(tokens::mutedSoft));
        wd.align = Canvas::TextStyle::Center;
        c.drawText(Rect(cx - cellW * 0.5f, area.y + 70.f, cellW, 12.f), weekday(weekDayTs(i)).c_str(), wd);
    }
}

void App::drawCalendarPage(Ui& ui, const Rect& area) {
    Canvas& c = ui.canvas();
    const float pad = isWide_ ? 52.f : 20.f;
    const Rect inner(area.x + pad, area.y, area.w - pad * 2, area.h);
    c.pushClip(inner);

    Canvas::TextStyle h = ui.style(isWide_ ? 44.f : 32.f, tok(tokens::ink), true);
    h.valign = Canvas::TextStyle::Middle;
    c.drawText(Rect(inner.x, inner.y + 10.f, inner.w - 190.f, isWide_ ? 52.f : 40.f), t("calendarTitle").c_str(),
               h);
    Canvas::TextStyle sub = ui.style(11.f, tok(tokens::muted));
    sub.valign = Canvas::TextStyle::Top;
    c.drawText(Rect(inner.x, inner.y + (isWide_ ? 62.f : 50.f), inner.w - 190.f, 16.f),
               t("nextDays", calendarDays_).c_str(), sub);

    const int options[3] = {7, 14, 30};
    float rx = inner.right() - 3 * 52.f;
    for (int i = 0; i < 3; ++i) {
        const Rect chip(rx, inner.y + 20.f, 48.f, 26.f);
        const bool active = calendarDays_ == options[i];
        c.fillRoundRect(chip, 12.f, active ? tok(tokens::yellowSoft) : tok(tokens::surfaceSoft));
        ui.textCenter(chip, t("days", options[i]), 10.5f, active ? tok("#6C4B00") : tok(tokens::muted), active);
        ui.tap(chip, kActCalendarDays, "", options[i]);
        rx += 52.f;
    }

    float y = inner.y + (isWide_ ? 90.f : 78.f);
    const auto days = upcoming();
    const auto overdue = overdueItems();
    c.pushClip(Rect(inner.x, y, inner.w, inner.bottom() - y));
    for (size_t i = 0; i < days.size(); ++i) {
        const float alpha = i < 32 ? calAlphaAnim_[std::min<size_t>(i, 31)].value() : 1.f;
        const float dx = i < 32 ? calXAnim_[std::min<size_t>(i, 31)].value() : 0.f;
        const bool emptyDay = days[i].count == 0;
        const float rowH = emptyDay ? 40.f : 62.f;
        const Rect row(inner.x + dx, y, inner.w, rowH);
        c.pushAlpha(std::max(0.f, std::min(1.f, alpha)));
        if (!emptyDay) {
            c.fillRoundRect(row, 18.f, tok(tokens::surfaceSoft));
            c.strokeRoundRect(row, 18.f, 1.f, tok("#B3FFFFFF"));
        } else {
            c.fillRoundRect(row, 18.f, tok(tokens::surfaceSoft, 0.4f));
        }
        Canvas::TextStyle date = ui.style(18.f, tok(tokens::ink), true);
        date.valign = Canvas::TextStyle::Top;
        c.drawText(Rect(row.x + 16.f, row.y + 12.f, 60.f, 22.f), shortDate(days[i].date).c_str(), date);
        Canvas::TextStyle wd = ui.style(9.f, tok(tokens::muted));
        wd.valign = Canvas::TextStyle::Top;
        c.drawText(Rect(row.x + 16.f, row.y + 34.f, 60.f, 14.f), weekday(days[i].date).c_str(), wd);

        if (!emptyDay) {
            const auto list = dayItems(days[i].date, i == 0);
            float chipX = row.x + 92.f;
            float chipY = row.y + 12.f;
            for (const auto& item : list) {
                const float cw = ui.measure(item.title, 11.f, false) + 30.f;
                if (chipX + cw > row.right() - 16.f) {
                    chipX = row.x + 92.f;
                    chipY += 28.f;
                }
                const Rect chip(chipX, chipY, cw, 26.f);
                c.fillRoundRect(chip, 10.f, tok(tokens::surface));
                c.fillCircle(chip.x + 10.f, chip.center().y, 3.f, colorOf(findSubject(item.subjectId).color));
                Canvas::TextStyle it = ui.style(11.f, tok(tokens::inkSoft));
                it.valign = Canvas::TextStyle::Middle;
                c.drawText(Rect(chip.x + 17.f, chip.y, chip.w - 22.f, chip.h), item.title.c_str(), it);
                chipX += cw + 6.f;
            }
        } else {
            Canvas::TextStyle none = ui.style(11.f, tok(tokens::mutedSoft));
            none.valign = Canvas::TextStyle::Middle;
            c.drawText(Rect(row.x + 92.f, row.y, row.w - 108.f, row.h), t("noPlan").c_str(), none);
        }
        if (i == 0 && !overdue.empty()) {
            Canvas::TextStyle od = ui.style(8.5f, tok(tokens::coral), true);
            od.valign = Canvas::TextStyle::Top;
            c.drawText(Rect(row.x + 16.f, row.y + 50.f, 90.f, 12.f),
                       t("overdueInDay", static_cast<int>(overdue.size())).c_str(), od);
        }
        c.popAlpha();
        y += rowH + 8.f;
    }
    c.popClip();
    c.popClip();
}

void App::drawSettingsPage(Ui& ui, const Rect& area) {
    Canvas& c = ui.canvas();
    const float pad = isWide_ ? 52.f : 20.f;
    const Rect inner(area.x + pad, area.y, area.w - pad * 2, area.h);
    c.pushClip(inner);

    Canvas::TextStyle h = ui.style(isWide_ ? 44.f : 32.f, tok(tokens::ink), true);
    h.valign = Canvas::TextStyle::Middle;
    c.drawText(Rect(inner.x, inner.y + 10.f, inner.w, isWide_ ? 52.f : 40.f), t("settingsTitle").c_str(), h);

    float y = inner.y + (isWide_ ? 76.f : 64.f);
    const float cardW = isWide_ ? std::min(760.f, inner.w) : inner.w;
    c.pushClip(Rect(inner.x, y, inner.w, inner.bottom() - y));

    auto animIn = [&](int index, float dxBase, float dyBase) {
        const float p = setIn_[index];
        const float ease = 0.3f + 0.7f * std::min(1.f, p * 1.8f);
        c.pushAlpha(ease);
        return Vec2((1.f - p) * dxBase, (1.f - p) * dyBase);
    };

    // 1. reminder card
    {
        const Vec2 off = animIn(0, -mv(72.f), 0.f);
        const Rect card(inner.x + off.x, y + off.y, cardW, 148.f);
        ui.card(card, 22.f, tok(tokens::surfaceSoft), tok("#B3FFFFFF"), 1.f, 0.f, 0.f, 0.f);
        ui.textLeft(Rect(card.x + 18.f, card.y + 14.f, card.w - 100.f, 20.f), t("remindMe"), 14.f,
                    tok(tokens::ink), true);
        ui.textLeft(Rect(card.x + 18.f, card.y + 34.f, card.w - 100.f, 16.f), t("reminderSub"), 9.5f,
                    tok(tokens::muted));
        const Rect toggle(card.right() - 74.f, card.y + 18.f, 46.f, 24.f);
        c.fillRoundRect(toggle, 12.f, settings_.reminderEnabled ? themeButton() : tok("#D8CEBA"));
        c.fillCircle(settings_.reminderEnabled ? toggle.right() - 12.f : toggle.x + 12.f, toggle.center().y, 10.f,
                     tok("#FFFFFF"));
        ui.tap(toggle, kActReminderToggle);

        ui.textLeft(Rect(card.x + 18.f, card.y + 66.f, 160.f, 18.f), t("reminderTime"), 11.f, tok(tokens::muted));
        const Rect timeBtn(card.right() - 100.f, card.y + 60.f, 82.f, 30.f);
        c.fillRoundRect(timeBtn, 10.f, tok(tokens::surface));
        ui.textCenter(Rect(timeBtn.x, timeBtn.y, timeBtn.w - 16.f, timeBtn.h), settings_.reminderTime, 13.f,
                      tok(tokens::inkSoft), true);
        ui.textRight(Rect(timeBtn.x, timeBtn.y, timeBtn.w - 8.f, timeBtn.h), "\u25BE", 9.f, tok(tokens::mutedSoft));
        ui.tap(timeBtn, kActOpenTimePicker);

        ui.textLeft(Rect(card.x + 18.f, card.y + 104.f, 120.f, 16.f), t("reminderMethod"), 10.f, tok(tokens::muted));
        ui.textRight(Rect(card.x + 18.f, card.y + 104.f, card.w - 36.f, 16.f), t("systemCalendar"), 10.f,
                     tok(tokens::mutedSoft));
        c.popAlpha();
        y += 164.f;
    }

    // 2. retention + interval + focus length
    {
        const Vec2 off = animIn(1, 0.f, mv(44.f));
        const Rect card(inner.x + off.x, y + off.y, cardW, 300.f);
        ui.card(card, 22.f, tok(tokens::surfaceSoft), tok("#B3FFFFFF"), 1.f, 0.f, 0.f, 0.f);
        ui.textLeft(Rect(card.x + 18.f, card.y + 14.f, card.w - 170.f, 20.f), t("retentionTitle"), 14.f,
                    tok(tokens::ink), true);
        ui.textLeft(Rect(card.x + 18.f, card.y + 34.f, card.w - 170.f, 16.f), t("retentionHint"), 9.5f,
                    tok(tokens::muted));
        char pct[8];
        std::snprintf(pct, sizeof(pct), "%d%%", static_cast<int>(std::lround(settings_.targetRetention * 100)));
        ui.textRight(Rect(card.right() - 132.f, card.y + 10.f, 62.f, 30.f), pct, 24.f, themeAccent(settings_.themeIndex),
                     true);
        const Rect adjBtn(card.right() - 64.f, card.y + 18.f, 46.f, 26.f);
        c.fillRoundRect(adjBtn, 13.f, themeButton());
        ui.textCenter(adjBtn, t("retentionAdjust"), 9.f, tokStr(themeInk()));
        ui.tap(adjBtn, kActRetentionToggle);

        // Slider (80..95) drawn by hand: track, filled portion, knob.
        const Rect track(card.x + 18.f, card.y + 66.f, card.w - 120.f, 4.f);
        c.fillRoundRect(track, 2.f, tok("#E6DCC8"));
        const float fillT = (static_cast<float>(settings_.targetRetention) - 0.80f) / 0.15f;
        c.fillRoundRect(Rect(track.x, track.y, track.w * fillT, track.h), 2.f, themeButton());
        c.fillCircle(track.x + track.w * fillT, track.center().y, 9.f, themeButton());
        ui.textLeft(Rect(track.x, track.y + 14.f, 40.f, 12.f), "80%", 9.f, tok(tokens::mutedSoft));
        ui.textRight(Rect(track.right() - 40.f, track.y + 14.f, 40.f, 12.f), "95%", 9.f, tok(tokens::mutedSoft));
        ui.tap(Rect(track.x - 8.f, track.y - 14.f, 28.f, 32.f), kActRetentionDown);
        ui.tap(Rect(track.right() - 20.f, track.y - 14.f, 28.f, 32.f), kActRetentionUp);

        Canvas::TextStyle exp = ui.style(10.f, tok(tokens::inkSoft));
        exp.wrap = true;
        exp.maxLines = 3;
        exp.lineHeight = 15.f;
        c.drawText(Rect(card.x + 18.f, card.y + 100.f, card.w - 36.f, 46.f), t("retentionExplain").c_str(), exp);

        c.fillRect(Rect(card.x + 18.f, card.y + 156.f, card.w - 36.f, 1.f), tok(tokens::line));

        ui.textLeft(Rect(card.x + 18.f, card.y + 168.f, card.w - 36.f, 20.f), t("maxIntervalTitle"), 14.f,
                    tok(tokens::ink), true);
        const int intervals[4] = {90, 180, 365, 0};
        float mx = card.x + 18.f;
        for (int i = 0; i < 4; ++i) {
            const std::string label = intervals[i] == 0 ? t("unlimited") : t("daysShort", intervals[i]);
            const float w = ui.measure(label, 10.f, false) + 20.f;
            const Rect chip(mx, card.y + 194.f, w, 26.f);
            const bool active = settings_.maxIntervalDays == intervals[i];
            c.fillRoundRect(chip, 11.f, active ? tok(tokens::yellowSoft) : tok(tokens::surface));
            ui.textCenter(chip, label, 10.f, active ? tok("#6C4B00") : tok(tokens::muted), active);
            ui.tap(chip, kActMaxInterval, "", intervals[i]);
            mx += w + 6.f;
        }

        ui.textLeft(Rect(card.x + 18.f, card.y + 236.f, card.w - 36.f, 18.f), t("focusSettingTitle"), 14.f,
                    tok(tokens::ink), true);
        const int minutes[6] = {15, 20, 25, 30, 45, 60};
        float fx = card.x + 18.f;
        for (int i = 0; i < 6; ++i) {
            const std::string label = t("minutesShort", minutes[i]);
            const float w = ui.measure(label, 10.f, false) + 20.f;
            const Rect chip(fx, card.y + 260.f, w, 26.f);
            const bool active = settings_.focusMinutes == minutes[i];
            c.fillRoundRect(chip, 11.f, active ? tok(tokens::yellowSoft) : tok(tokens::surface));
            ui.textCenter(chip, label, 10.f, active ? tok("#6C4B00") : tok(tokens::muted), active);
            ui.tap(chip, kActFocusMinutes, "", minutes[i]);
            fx += w + 6.f;
        }
        c.popAlpha();
        y += 316.f;
    }

    // 3. subjects
    {
        const Vec2 off = animIn(2, mv(72.f), 0.f);
        float cy = y + off.y;
        const float h = 78.f + 44.f * static_cast<float>((subjects_.size() + 2) / 3);
        const Rect card(inner.x + off.x, cy, cardW, h);
        ui.card(card, 22.f, tok(tokens::surfaceSoft), tok("#B3FFFFFF"), 1.f, 0.f, 0.f, 0.f);
        ui.textLeft(Rect(card.x + 18.f, card.y + 14.f, 100.f, 16.f), t("subject"), 11.f, tok(tokens::muted), true);
        float chipX = card.x + 18.f;
        float chipY = card.y + 38.f;
        for (const auto& subject : subjects_) {
            const float w = ui.measure(subject.name, 10.f, false) + 40.f;
            if (chipX + w > card.right() - 18.f) {
                chipX = card.x + 18.f;
                chipY += 36.f;
            }
            const Rect chip(chipX, chipY, w, 30.f);
            c.fillRoundRect(chip, 12.f, tok(tokens::surface));
            c.strokeRoundRect(chip, 12.f, 1.f, tok("#B3FFFFFF"));
            c.fillCircle(chip.x + 12.f, chip.center().y, 3.5f, colorOf(subject.color));
            ui.textLeft(Rect(chip.x + 19.f, chip.y, w - 44.f, chip.h), subject.name, 10.f, tok(tokens::inkSoft));
            const Rect del(chip.right() - 22.f, chip.y, 20.f, chip.h);
            ui.textCenter(del, "\u00D7", 11.f, tok(tokens::mutedSoft));
            ui.tap(del, kActDeleteSubject, subject.id);
            chipX += w + 6.f;
        }
        const Rect input(card.x + 18.f, chipY + 40.f, card.w - 130.f, 36.f);
        c.fillRoundRect(input, 10.f, tok(tokens::surface));
        c.strokeRoundRect(input, 10.f, 1.f, tok("#E6DCC8"));
        Canvas::TextStyle in = ui.style(12.f, newSubjectName_.empty() ? tok(tokens::mutedSoft) : tok(tokens::ink));
        in.valign = Canvas::TextStyle::Middle;
        const std::string inputText = newSubjectName_.empty() ? t("addSubject") : newSubjectName_;
        c.drawText(Rect(input.x + 12.f, input.y, input.w - 24.f, input.h), inputText.c_str(), in);
        ui.tap(input, kActAddSubject, "focus");
        const Rect addBtn(card.right() - 106.f, input.y, 88.f, 36.f);
        ui.pillButton(addBtn, t("addSubject"), 11.f, themeButton(), tokStr(themeInk()), false);
        ui.tap(addBtn, kActAddSubject, "add");
        c.popAlpha();
        y += h + 16.f;
    }

    // 4. palette
    {
        const Vec2 off = animIn(3, -mv(72.f), 0.f);
        const Rect card(inner.x + off.x, y + off.y, cardW, 128.f);
        ui.card(card, 22.f, tok(tokens::surfaceSoft), tok("#B3FFFFFF"), 1.f, 0.f, 0.f, 0.f);
        ui.textLeft(Rect(card.x + 18.f, card.y + 14.f, 200.f, 16.f), t("palette"), 11.f, tok(tokens::muted), true);
        static const char* const names[4] = {"奶油", "雾蓝", "暖砂", "鼠尾草"};
        for (int i = 0; i < 4; ++i) {
            const float cellW = (card.w - 36.f - 18.f) / 4.f;
            const Rect cell(card.x + 18.f + cellW * i + 3.f, card.y + 38.f, cellW - 6.f, 46.f);
            const bool active = settings_.themeIndex == i;
            c.fillRoundRect(cell, 12.f, tok(tokens::surface));
            c.strokeRoundRect(cell, 12.f, active ? 2.f : 1.f,
                              active ? themeAccent(i) : tok("#E6DCC8"));
            c.fillRoundRect(Rect(cell.x + 10.f, cell.center().y - 13.f, 26.f, 26.f), 8.f, themeAccent(i));
            for (int k = 0; k < 4; ++k) {
                c.fillCircle(cell.x + 48.f + k * 16.f, cell.center().y, 6.5f, pageColors(i, k));
                c.strokeCircle(cell.x + 48.f + k * 16.f, cell.center().y, 6.5f, 1.f, Color(0, 0, 0, 0.27f));
            }
            (void)names;
            ui.tap(cell, kActTheme, "", i);
        }
        c.popAlpha();
        y += 144.f;
    }

    // 5. language
    {
        const Vec2 off = animIn(4, 0.f, mv(44.f));
        const Rect card(inner.x + off.x, y + off.y, cardW, 112.f);
        ui.card(card, 22.f, tok(tokens::surfaceSoft), tok("#B3FFFFFF"), 1.f, 0.f, 0.f, 0.f);
        ui.textLeft(Rect(card.x + 18.f, card.y + 14.f, 200.f, 16.f), t("language"), 11.f, tok(tokens::muted), true);
        float lx = card.x + 18.f;
        float ly = card.y + 38.f;
        for (const auto& option : I18n::kLanguages) {
            const float w = ui.measure(option.name, 10.f, false) + 24.f;
            if (lx + w > card.right() - 18.f) {
                lx = card.x + 18.f;
                ly += 36.f;
            }
            const Rect chip(lx, ly, w, 30.f);
            const bool active = settings_.language == option.code;
            c.fillRoundRect(chip, 15.f, active ? themeButton() : tok(tokens::surface));
            c.strokeRoundRect(chip, 15.f, 1.f, active ? themeButton() : tok("#E6DCC8"));
            ui.textCenter(chip, option.name, 10.f, active ? tokStr(themeInk()) : tok(tokens::inkSoft));
            ui.tap(chip, kActLanguage, option.code);
            lx += w + 6.f;
        }
        c.popAlpha();
    }

    c.popClip();
    c.popClip();
}

}  // namespace folio