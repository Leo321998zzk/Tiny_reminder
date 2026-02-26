import SwiftUI

// Global settings screen for configuring the default reminder schedule
// used by all homework items that don't have a custom schedule.
struct SettingsView: View {
    @Binding var schedule: NotificationSchedule

    var body: some View {
        Form {
            // Far phase controls: how often to remind when the deadline is still far away
            Section(header: Text("📅 Far From Deadline")) {
                // Stepper to adjust reminder interval (hours) when far from deadline (1-24)
                Stepper("Remind every \(schedule.daysBeforeInterval) hour(s)",
                        value: $schedule.daysBeforeInterval, in: 1...24)
                Text("When the deadline is more than \(schedule.switchToHourlyAt) hour(s) away.")
                    .font(.caption).foregroundColor(.gray)
            }

            // Close phase controls: switch threshold and minute-level cadence near the deadline
            Section(header: Text("⏰ Close to Deadline")) {
                // Stepper to adjust threshold hour count for switching reminder frequency (1-48)
                Stepper("Switch when \(schedule.switchToHourlyAt) hour(s) remain",
                        value: $schedule.switchToHourlyAt, in: 1...48)
                // Stepper to adjust reminder interval (minutes) when close to deadline (5-60 step 5)
                Stepper("Remind every \(schedule.hoursBeforeInterval) min(s)",
                        value: $schedule.hoursBeforeInterval, in: 5...60, step: 5)
                Text("When the deadline is within \(schedule.switchToHourlyAt) hour(s).")
                    .font(.caption).foregroundColor(.gray)
            }

            // Human-readable summary of the current configuration
            Section(header: Text("📋 Summary")) {
                Text("Far: every \(schedule.daysBeforeInterval)h → switches to every \(schedule.hoursBeforeInterval)min when \(schedule.switchToHourlyAt)h remain → stops at deadline or deletion.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        // Title shown in the navigation bar
        .navigationTitle("Notification Settings")
    }
}
