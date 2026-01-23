import SwiftUI

struct FocusTimerBadge: View {
    @ObservedObject var focusTimerService = FocusTimerService.shared
    
    var body: some View {
        Button(action: {
            focusTimerService.stopFocus()
        }) {
            HStack(spacing: 2) {
                Image(systemName: "timer")
                    .font(.system(size: 9))
                Text(focusTimerService.elapsedTimeFormatted)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.8))
            )
            .scaleEffect(focusTimerService.isNudging ? 1.15 : 1.0)
            .animation(
                focusTimerService.isNudging
                    ? .easeInOut(duration: 0.3).repeatCount(3, autoreverses: true)
                    : .default,
                value: focusTimerService.isNudging
            )
        }
        .buttonStyle(.plain)
        .help(rmbLocalized(.focusTimerStopHelp))
    }
}

#Preview {
    FocusTimerBadge()
}
