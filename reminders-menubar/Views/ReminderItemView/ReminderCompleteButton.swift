import SwiftUI
import EventKit

struct ReminderCompleteButton: View {
    var reminderItem: ReminderItem
    @State private var isAnimating = false
    @ObservedObject var focusTimerService = FocusTimerService.shared

    private var isFocused: Bool {
        focusTimerService.isFocused(reminderId: reminderItem.id)
    }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAnimating = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Stop focus timer if this reminder was being focused
                if isFocused {
                    focusTimerService.stopFocus()
                }
                
                reminderItem.reminder.isCompleted.toggle()
                RemindersService.shared.save(reminder: reminderItem.reminder)
                if reminderItem.reminder.isCompleted {
                    reminderItem.childReminders.uncompleted.forEach { uncompletedChild in
                        uncompletedChild.reminder.isCompleted = true
                        RemindersService.shared.save(reminder: uncompletedChild.reminder)
                    }
                }
                isAnimating = false
            }
        }) {
            Image(systemName: buttonIcon)
                .resizable()
                .frame(width: 14, height: 14)
                .foregroundColor(Color(reminderItem.reminder.calendar.color))
                .scaleEffect(isAnimating ? 1.2 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var buttonIcon: String {
        if isAnimating {
            return "checkmark.circle.fill"
        } else if reminderItem.reminder.isCompleted {
            return "largecircle.fill.circle"
        } else {
            return "circle"
        }
    }
}

#Preview {
    var reminder: EKReminder {
        let calendar = EKCalendar(for: .reminder, eventStore: .init())
        calendar.color = .systemTeal

        let reminder = EKReminder(eventStore: .init())
        reminder.title = "Look for awesome projects on GitHub"
        reminder.isCompleted = false
        reminder.calendar = calendar

        return reminder
    }
    let reminderItem = ReminderItem(for: reminder)

    ReminderCompleteButton(reminderItem: reminderItem)
}
