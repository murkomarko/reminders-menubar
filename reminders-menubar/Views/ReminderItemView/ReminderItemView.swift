import SwiftUI
import EventKit

@MainActor
struct ReminderItemView: View {
    var reminderItem: ReminderItem
    var isShowingCompleted: Bool
    var showCalendarTitleOnDueDate = false
    @State var reminderItemIsHovered = false

    @State private var showingEditPopover = false
    @State private var isEditingTitle = false

    @State private var showingRemoveAlert = false
    
    @ObservedObject var focusTimerService = FocusTimerService.shared
    @ObservedObject var userPreferences = UserPreferences.shared

    var body: some View {
        if reminderItem.reminder.calendar == nil {
            // On macOS 12 the calendar may be nil during delete operation.
            // Returning Empty to avoid issues since calendar is a force unwrap.
            EmptyView()
        } else {
            mainReminderItemView()
        }
    }

    @ViewBuilder
    func mainReminderItemView() -> some View {
        HStack(spacing: 3) {
            ReminderCompleteButton(reminderItem: reminderItem)
            
            // Priority indicator
            if let prioritySystemImage = reminderItem.reminder.ekPriority.systemImage {
                Image(systemName: prioritySystemImage)
                    .font(.system(size: 10))
                    .foregroundColor(Color(reminderItem.reminder.calendar.color))
            }
            
            // Overdue date (shown BEFORE title - uses fixedSize to never compress)
            if reminderItem.reminder.isExpired, let date = reminderItem.reminder.dueDateComponents?.date {
                Text(date.compactDateDescription(withTime: reminderItem.reminder.hasTime))
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.red)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .onTapGesture {
                        openRemindersApp()
                    }
            }
            
            // Title (truncates first when space is limited)
            Text(LocalizedStringKey(reminderItem.reminder.title.toDetectedLinkAttributedString()))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture {
                    openRemindersApp()
                }
            
            // Timer badge (when focused, always visible)
            if isCurrentlyFocused() {
                FocusTimerBadge()
                    .fixedSize()
            }
        }
        .overlay(
            Group {
                if shouldShowEllipsisButton() {
                    HStack(spacing: 4) {
                        // List name badge (clickable - opens Apple Reminders to this list)
                        Button(action: {
                            openRemindersApp()
                        }) {
                            Text(reminderItem.reminder.calendar.title)
                                .font(.system(size: 10))
                                .foregroundColor(Color(reminderItem.reminder.calendar.color))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color(reminderItem.reminder.calendar.color).opacity(0.15))
                                )
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        
                        // Focus timer button
                        focusButton()
                            .opacity(userPreferences.focusTimerEnabled ? 1 : 0)
                        
                        // Ellipsis menu
                        ReminderEllipsisMenuView(
                            showingEditPopover: $showingEditPopover,
                            showingRemoveAlert: $showingRemoveAlert,
                            reminder: reminderItem.reminder,
                            reminderHasChildren: reminderItem.hasChildren
                        )
                        .popover(isPresented: $showingEditPopover, arrowEdge: .trailing) {
                            ReminderEditPopover(
                                isPresented: $showingEditPopover,
                                focusOnTitle: $isEditingTitle,
                                reminder: reminderItem.reminder,
                                reminderHasChildren: reminderItem.hasChildren
                            )
                        }
                    }
                    .padding(.leading, 12) // Add padding to separate from potential text overlap
                    .background(
                        // Gradient fade from clear to background color to smooth text overlap
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: Color(NSColor.windowBackgroundColor).opacity(0.8), location: 0.1),
                                .init(color: Color(NSColor.windowBackgroundColor), location: 0.4)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            },
            alignment: .trailing
        )
        .padding(.vertical, 1) // Reduced vertical spacing between rows
        .onHover { isHovered in
            reminderItemIsHovered = isHovered
        }
        .padding(.leading, reminderItem.isChild ? 24 : 0)
        .alert(isPresented: $showingRemoveAlert) {
            removeReminderAlert()
        }

        ForEach(reminderItem.childReminders.uncompleted) { reminderItem in
            ReminderItemView(reminderItem: reminderItem, isShowingCompleted: isShowingCompleted)
        }

        if isShowingCompleted {
            ForEach(reminderItem.childReminders.completed) { reminderItem in
                ReminderItemView(reminderItem: reminderItem, isShowingCompleted: isShowingCompleted)
            }
        }
    }

    func shouldShowEllipsisButton() -> Bool {
        return reminderItemIsHovered || showingEditPopover
    }
    
    func shouldShowFocusButton() -> Bool {
        return reminderItemIsHovered || isCurrentlyFocused()
    }
    
    func isCurrentlyFocused() -> Bool {
        return focusTimerService.isFocused(reminderId: reminderItem.id)
    }
    
    @ViewBuilder
    func focusButton() -> some View {
        if isCurrentlyFocused() {
            Button(action: {
                focusTimerService.stopFocus()
            }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(reminderItem.reminder.calendar.color))
            }
            .buttonStyle(.plain)
            .frame(width: 16, height: 16)
            .help(rmbLocalized(.focusTimerStopHelp))
        } else {
            Button(action: {
                focusTimerService.startFocus(for: reminderItem.reminder)
            }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(reminderItem.reminder.calendar.color))
            }
            .buttonStyle(.plain)
            .frame(width: 16, height: 16)
            .help(rmbLocalized(.focusTimerStartHelp))
        }
    }

    func removeReminderAlert() -> Alert {
        Alert(
            title: Text(rmbLocalized(.removeReminderAlertTitle)),
            message: Text(rmbLocalized(.removeReminderAlertMessage, arguments: reminderItem.reminder.title)),
            primaryButton: .destructive(Text(rmbLocalized(.removeReminderAlertConfirmButton)), action: {
                // Stop focus timer if this reminder was focused
                if isCurrentlyFocused() {
                    focusTimerService.stopFocus()
                }
                RemindersService.shared.remove(reminder: reminderItem.reminder)
            }),
            secondaryButton: .cancel(Text(rmbLocalized(.removeReminderAlertCancelButton)))
        )
    }
    
    func openRemindersApp() {
        // Try to open using the known scheme
        if let url = URL(string: "x-apple-reminderkit://") {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback: Launch by name (legacy but effective for system apps)
            NSWorkspace.shared.launchApplication("Reminders")
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

    ReminderItemView(reminderItem: reminderItem, isShowingCompleted: false)
}
