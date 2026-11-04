// Tap routing: every draw call registers a hit region, then the frame's taps
// dispatch to the same actions the ArkUI onClick handlers performed.
#include <algorithm>

#include "platform/platform.h"
#include "ui/app.h"

namespace folio {

void App::onAction(int action, const std::string& arg, int number) {
    switch (action) {
        case 100:  // tab
            switchTab(number);
            break;
        case 101: {  // open review for an item
            for (const auto& item : items_) {
                if (item.id == arg) {
                    openReview(item);
                    break;
                }
            }
            break;
        }
        case 102:  // composer (new entry)
            openComposer();
            break;
        case 103:
            closeReview();
            break;
        case 104:
            postponeReview();
            break;
        case 105:
            startRating();
            break;
        case 106:
            backToEntry();
            break;
        case 107:
            finishReview(number);
            break;
        case 108:
            openComposer();
            break;
        case 109:
            closeComposer();
            break;
        case 110:
            addItem();
            break;
        case 111:
            switchMode(number);
            break;
        case 112:
            draftSubjectId_ = arg;
            break;
        case 113:
            draftFixedDays_ = std::min(90, draftFixedDays_ + 1);
            break;
        case 114:
            draftFixedDays_ = std::max(1, draftFixedDays_ - 1);
            break;
        case 115:
            openFocusClock();
            break;
        case 116:
            closeFocusClock();
            break;
        case 117:
            startCycle();
            break;
        case 118:
            if (focusPaused_) {
                resumeFocus();
            } else {
                pauseFocus();
            }
            break;
        case 119:
            stopFocusEarly();
            break;
        case 120:
            closeSummary();
            break;
        case 121:
            setCalendarDays(number);
            break;
        case 122:
            updateMaxInterval(number);
            break;
        case 123:
            updateFocusMinutes(number);
            break;
        case 124:
            updateTheme(number);
            break;
        case 125:
            setLanguage(arg);
            break;
        case 126: {
            const int pct = static_cast<int>(std::lround(settings_.targetRetention * 100));
            settingRetentionUnlocked_ = !settingRetentionUnlocked_;
            if (settingRetentionUnlocked_) {
                (void)pct;
            }
            break;
        }
        case 127:
            updateRetention(static_cast<float>(std::lround(settings_.targetRetention * 100)) - 1.f);
            persist();
            break;
        case 128:
            updateRetention(static_cast<float>(std::lround(settings_.targetRetention * 100)) + 1.f);
            persist();
            break;
        case 129: {  // open item actions from a list card
            for (const auto& item : items_) {
                if (item.id == arg) {
                    openItemActions(item);
                    break;
                }
            }
            break;
        }
        case 130:
            closeItemActions();
            break;
        case 131:
            startEditItem();
            break;
        case 132:
            askDeleteRecord(actionItem_);
            break;
        case 133:
            cancelConfirm();
            break;
        case 134:
            executeConfirm();
            break;
        case 135:
            cancelConfirm();
            break;
        case 136: {  // delete a subject
            for (const auto& subject : subjects_) {
                if (subject.id == arg) {
                    confirmDeleteSubject(subject);
                    break;
                }
            }
            break;
        }
        case 137:
            updateReminderEnabled(!settings_.reminderEnabled);
            break;
        case 138:
            openTimePicker();
            break;
        case 139:
            pickerHour_ = (pickerHour_ + 23) % 24;
            break;
        case 140:
            pickerHour_ = (pickerHour_ + 1) % 24;
            break;
        case 141:
            pickerMinute_ = (pickerMinute_ + 59) % 60;
            break;
        case 142:
            pickerMinute_ = (pickerMinute_ + 1) % 60;
            break;
        case 143:
            cancelTimePicker();
            break;
        case 144:
            confirmTimePicker();
            break;
        case 145:
            if (arg == "add") {
                addSubject();
            } else if (!platform().requestText(t("subject").c_str(), newSubjectName_.c_str(), newSubjectName_)) {
                // Keyboard cancelled: leave the current draft untouched.
            }
            break;
        case 146:
            editSubjectId_ = arg;
            break;
        case 147:
            saveItemEdit();
            break;
        case 148:
            switchTab(1);
            break;
        default:
            break;
    }
}

void App::recordTap(const Rect& r, int action, const std::string& arg, int number) {
    taps_.push_back({r, action, arg, number});
}

void App::dispatchTap(float x, float y) {
    // Walk the tap list backwards: later registrations paint on top.
    for (auto it = taps_.rbegin(); it != taps_.rend(); ++it) {
        if (it->rect.contains(x, y)) {
            onAction(it->action, it->arg, it->number);
            return;
        }
    }
}

}  // namespace folio