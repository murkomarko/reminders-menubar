import Foundation
import EventKit
import Combine

@MainActor
class FocusTimerService: ObservableObject {
    static let shared = FocusTimerService()
    
    private init() {
        // This prevents others from using the default '()' initializer for this class.
    }
    
    // MARK: - Published State
    
    /// The calendar item identifier of the currently focused reminder, or nil if not focusing.
    @Published private(set) var focusedReminderId: String?
    
    /// The EKReminder being focused (kept for saving notes later).
    private var focusedReminder: EKReminder?
    
    /// Seconds elapsed since focus started.
    @Published private(set) var elapsedSeconds: Int = 0
    
    /// Whether the timer is currently in a "nudge" state (for pulsing animation).
    @Published private(set) var isNudging: Bool = false
    
    // MARK: - Private State
    
    private var timer: Timer?
    private var focusStartDate: Date?
    private var lastNudgeTime: Date?
    
    // MARK: - Computed Properties
    
    var isFocusing: Bool {
        return focusedReminderId != nil
    }
    
    var elapsedTimeFormatted: String {
        let minutes = elapsedSeconds / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Public Methods
    
    /// Start a focus session for a specific reminder.
    func startFocus(for reminder: EKReminder) {
        // Stop any existing session first
        if isFocusing {
            stopFocus()
        }
        
        focusedReminder = reminder
        focusedReminderId = reminder.calendarItemIdentifier
        focusStartDate = Date()
        lastNudgeTime = Date()
        elapsedSeconds = 0
        isNudging = false
        
        // Start the timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    /// Stop the current focus session and log the time.
    func stopFocus() {
        guard let reminder = focusedReminder, let startDate = focusStartDate else {
            resetState()
            return
        }
        
        let duration = Date().timeIntervalSince(startDate)
        
        // Only log if at least 1 minute has passed
        if duration >= 60 {
            appendFocusLog(to: reminder, duration: duration)
        }
        
        resetState()
    }
    
    /// Check if a specific reminder is currently being focused.
    func isFocused(reminderId: String) -> Bool {
        return focusedReminderId == reminderId
    }
    
    // MARK: - Private Methods
    
    private func tick() {
        guard let startDate = focusStartDate else { return }
        
        elapsedSeconds = Int(Date().timeIntervalSince(startDate))
        
        // Check for nudge
        checkNudge()
    }
    
    private func checkNudge() {
        let nudgeInterval = UserPreferences.shared.focusNudgeIntervalMinutes
        guard nudgeInterval > 0, let lastNudge = lastNudgeTime else {
            return
        }
        
        let secondsSinceLastNudge = Date().timeIntervalSince(lastNudge)
        let nudgeIntervalSeconds = Double(nudgeInterval * 60)
        
        if secondsSinceLastNudge >= nudgeIntervalSeconds {
            // Trigger nudge
            isNudging = true
            lastNudgeTime = Date()
            
            // Reset nudge state after animation duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.isNudging = false
            }
        }
    }
    
    private func resetState() {
        timer?.invalidate()
        timer = nil
        focusedReminder = nil
        focusedReminderId = nil
        focusStartDate = nil
        lastNudgeTime = nil
        elapsedSeconds = 0
        isNudging = false
    }
    
    // MARK: - Focus Log Management
    
    private let focusLogHeader = "--- Focus Log ---"
    private let focusLogFooter = "-----------------"
    
    private func appendFocusLog(to reminder: EKReminder, duration: TimeInterval) {
        let durationMinutes = Int(duration / 60)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let newEntry = "• \(dateString): \(durationMinutes)m"
        
        var existingNotes = reminder.notes ?? ""
        var logEntries: [String] = []
        var userNotes = ""
        
        // Parse existing focus log if present
        if let headerRange = existingNotes.range(of: focusLogHeader),
           let footerRange = existingNotes.range(of: focusLogFooter) {
            // Extract existing log entries
            let logContent = existingNotes[headerRange.upperBound..<footerRange.lowerBound]
            logEntries = logContent
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.starts(with: "Total:") }
            
            // Extract user notes after the log block
            let afterFooter = existingNotes[footerRange.upperBound...]
            userNotes = String(afterFooter).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // No existing log, treat all content as user notes
            userNotes = existingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Add new entry
        logEntries.append(newEntry)
        
        // Calculate total
        let totalMinutes = calculateTotalMinutes(from: logEntries)
        let totalFormatted = formatDuration(minutes: totalMinutes)
        
        // Rebuild notes
        var newNotes = focusLogHeader + "\n"
        for entry in logEntries {
            newNotes += entry + "\n"
        }
        newNotes += "Total: \(totalFormatted)\n"
        newNotes += focusLogFooter
        
        if !userNotes.isEmpty {
            newNotes += "\n\n" + userNotes
        }
        
        reminder.notes = newNotes
        RemindersService.shared.save(reminder: reminder)
    }
    
    private func calculateTotalMinutes(from entries: [String]) -> Int {
        var total = 0
        let pattern = #"(\d+)m"#
        let regex = try? NSRegularExpression(pattern: pattern)
        
        for entry in entries {
            let range = NSRange(entry.startIndex..., in: entry)
            if let match = regex?.firstMatch(in: entry, range: range),
               let minutesRange = Range(match.range(at: 1), in: entry) {
                total += Int(entry[minutesRange]) ?? 0
            }
        }
        
        return total
    }
    
    private func formatDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
