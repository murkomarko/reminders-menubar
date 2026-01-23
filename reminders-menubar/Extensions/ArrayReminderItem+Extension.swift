import EventKit

extension Array where Element == ReminderItem {
    var sortedReminders: [ReminderItem] {
        return sortedReminders(self)
    }
    
    var sortedRemindersByPriority: [ReminderItem] {
        // "Apple Style" sorting is usually Date -> Priority.
        // The user requested to match the official app, which defaults to interaction/date.
        // So we redirect this to use the standard sortedReminders logic effectively.
        return sortedReminders(self)
    }
    
    private func sortedReminders(_ reminders: [ReminderItem]) -> [ReminderItem] {
        return reminders.sorted { first, second in
             // 1. Completion Status (Incomplete first)
             if first.reminder.isCompleted != second.reminder.isCompleted {
                 return !first.reminder.isCompleted
             }
             
             // 2. Due Date (Earliest first)
             let firstDate = first.reminder.dueDateComponents?.date
             let secondDate = second.reminder.dueDateComponents?.date
             
             if let d1 = firstDate, let d2 = secondDate {
                 if d1 != d2 { return d1 < d2 }
             } else if firstDate != nil {
                 return true // Items with date come before items without
             } else if secondDate != nil {
                 return false
             }
             
             // 3. Priority (1 is High, 5 Medium, 9 Low, 0 None)
             // Sort Order: 1, 5, 9, 0.
             func normalizedPriority(_ p: Int) -> Int {
                 return p == 0 ? 99 : p
             }
             let p1 = normalizedPriority(first.reminder.priority)
             let p2 = normalizedPriority(second.reminder.priority)
             if p1 != p2 {
                 return p1 < p2
             }
             
             // 4. Creation Date (Oldest first)
             let c1 = first.reminder.creationDate ?? Date.distantPast
             let c2 = second.reminder.creationDate ?? Date.distantPast
             return c1 < c2
        }
    }
}
