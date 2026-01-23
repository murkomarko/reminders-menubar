import SwiftUI

struct UpcomingRemindersTitle: View {
    @ObservedObject var userPreferences = UserPreferences.shared
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        HStack(alignment: .center) {
            Text(rmbLocalized(.upcomingRemindersTitle))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            Spacer()

            Spacer()
        }
    }
}

struct UpcomingRemindersTitle_Previews: PreviewProvider {
    static var previews: some View {
        UpcomingRemindersTitle()
    }
}
