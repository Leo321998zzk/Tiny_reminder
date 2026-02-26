import SwiftUI

// Per-item override settings. Lets the user switch between using the
// global schedule and a custom schedule for a specific homework item.
struct ItemSettingsView: View {
    // The homework item being edited (two-way binding)
    @Binding var homework: Homework
    // Read-only copy of the current global schedule to show defaults
    var globalSchedule: NotificationSchedule

    // Whether this item uses a custom schedule override
    @State private var useCustom: Bool = false
    // Local working copy of the schedule when useCustom is true
    @State private var localSchedule: NotificationSchedule

    init(homework: Binding<Homework>, globalSchedule: NotificationSchedule) {
        self._homework = homework
        self.globalSchedule = globalSchedule
        // Initialize state based on whether the homework already has a custom schedule.
        // If present, start with that and mark useCustom = true; otherwise mirror the global schedule.
        if let custom = homework.wrappedValue.customSchedule {
            _useCustom = State(initialValue: true)
            _localSchedule = State(initialValue: custom)
        } else {
            _useCustom = State(initialValue: false)
            _localSchedule = State(initialValue: globalSchedule)
        }
    }

    var body: some View {
        Form {
            // Toggle between using the global default and a per-item custom schedule
            Section {
                Toggle("Use custom schedule for this item", isOn: $useCustom)
                    .onChange(of: useCustom) { value in
                        // Persist the choice back to the bound homework model
                        homework.customSchedule = value ? localSchedule : nil
                    }
            }

            if useCustom {
                // Far phase cadence (hours) for this item
                Section(header: Text("📅 Far From Deadline")) {
                    // Stepper to adjust far phase interval hours
                    Stepper("Remind every \(localSchedule.daysBeforeInterval) hour(s)",
                            value: $localSchedule.daysBeforeInterval, in: 1...24)
                        .onChange(of: localSchedule.daysBeforeInterval) { _ in
                            homework.customSchedule = localSchedule
                        }
                }

                // Close phase: switch threshold (hours) and cadence (minutes)
                Section(header: Text("⏰ Close to Deadline")) {
                    // Stepper to adjust switch threshold (hours)
                    Stepper("Switch when \(localSchedule.switchToHourlyAt) hour(s) remain",
                            value: $localSchedule.switchToHourlyAt, in: 1...48)
                        .onChange(of: localSchedule.switchToHourlyAt) { _ in
                            homework.customSchedule = localSchedule
                        }
                    // Stepper to adjust close phase interval minutes
                    Stepper("Remind every \(localSchedule.hoursBeforeInterval) min(s)",
                            value: $localSchedule.hoursBeforeInterval, in: 5...60, step: 5)
                        .onChange(of: localSchedule.hoursBeforeInterval) { _ in
                            homework.customSchedule = localSchedule
                        }
                }
            } else {
                // Read-only view of the global default when custom is off
                Section(header: Text("Using Global Default")) {
                    Text("Far: every \(globalSchedule.daysBeforeInterval)h")
                    Text("Close: every \(globalSchedule.hoursBeforeInterval)min when \(globalSchedule.switchToHourlyAt)h remain")
                }
                .foregroundColor(.gray)
            }
        }
        .navigationTitle(homework.subject)
    }
}
