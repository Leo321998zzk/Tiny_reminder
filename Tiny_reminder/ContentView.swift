//
//  ContentView.swift
//  Tiny_reminder
//
//  Created by Leo Li on 2/21/26.
//

import SwiftUI
import UserNotifications
import Combine

// Main screen: allows creating homework reminders, lists upcoming items,
// and provides access to global and per-item settings. Also handles scheduling
// and cancellation of local notifications.

// Configuration that defines how often to remind the user as the deadline approaches.
// - daysBeforeInterval: When the deadline is far away (> switchToHourlyAt hours), remind every N hours.
// - hoursBeforeInterval: When close to the deadline (<= switchToHourlyAt hours), remind every N minutes.
// - switchToHourlyAt: Threshold (in hours remaining) where we switch from hourly to minute-based reminders.
struct NotificationSchedule {
    // Far phase cadence (in hours)
    var daysBeforeInterval: Int   // Notify every X hours when far from deadline
    // Close phase cadence (in minutes)
    var hoursBeforeInterval: Int  // Notify every X minutes when close to deadline
    // Threshold (hours remaining) to switch to the close phase
    var switchToHourlyAt: Int     // Switch to fast rate when X hours remain
}

// A single homework item the user wants reminders for.
// Each item can optionally override the global notification schedule.
struct Homework: Identifiable {
    // Stable unique identifier used to group/cancel notifications per homework
    let id = UUID()
    // Human-readable subject/title for the homework
    var subject: String
    // Absolute deadline for the homework
    var dueDate: Date
    // Optional per-item schedule; nil means use the global default
    var customSchedule: NotificationSchedule? // nil = use global default
}

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

// Main screen: allows creating homework reminders, lists upcoming items,
// and provides access to global and per-item settings. Also handles scheduling
// and cancellation of local notifications.
struct ContentView: View {
    // In-memory list of all homework items
    @State private var homeworkList: [Homework] = []
    // Text field binding for new homework subject
    @State private var subject = ""
    // Date picker binding for new homework due date/time
    @State private var dueDate = Date()
    // Continuously updated current time used to filter and clamp dates
    @State private var currentTime = Date()
    // Global default notification schedule (used when items have no override)
    @State private var globalSchedule = NotificationSchedule(
        daysBeforeInterval: 6,   // Notify every 6 hours when far
        hoursBeforeInterval: 30, // Notify every 30 mins when close
        switchToHourlyAt: 24     // Switch when 24 hours remain
    )

    // 1 Hz timer to refresh currentTime and keep UI/validation in sync
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Derived collection of future-due homework items (filters out past due)
    var upcomingHomework: [Homework] {
        homeworkList.filter { $0.dueDate > currentTime }
    }

    var body: some View {
        NavigationView {
            VStack {
                // Subject input for the new homework item
                TextField("Subject name", text: $subject)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                // Due date/time picker constrained to not allow past dates
                DatePicker("Due Date", selection: $dueDate,
                           in: currentTime...,
                           displayedComponents: [.date, .hourAndMinute])
                    .padding()

                // Create a new homework item and schedule its notifications
                Button("Add Reminder") {
                    addHomework()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                // List of upcoming homework items with navigation to per-item settings
                List {
                    ForEach($homeworkList) { $hw in
                        // Guard: only display items that are still in the future
                        if hw.dueDate > currentTime {
                            // Navigate to per-item settings (override or view defaults)
                            NavigationLink(destination: ItemSettingsView(
                                homework: $hw,
                                globalSchedule: globalSchedule
                            )) {
                                VStack(alignment: .leading) {
                                    Text(hw.subject).font(.headline)
                                    Text(hw.dueDate, style: .date)
                                        .font(.subheadline).foregroundColor(.gray)
                                    Text(hw.dueDate, style: .time)
                                        .font(.subheadline).foregroundColor(.gray)
                                    // Indicator showing whether this item uses custom or default reminders
                                    Text(hw.customSchedule != nil ? "🔔 Custom reminders" : "🔔 Default reminders")
                                        .font(.caption).foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .onDelete(perform: removeHomework)
                }
            }
            .navigationTitle("Homework Reminders")
            .toolbar {
                // Enable list editing (delete/reorder if supported)
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                // Open global notification settings
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView(schedule: $globalSchedule)) {
                        Image(systemName: "gear")
                    }
                }
            }
            // Ask for notification permission when the view appears
            .onAppear { requestPermission() }
            // Keep currentTime fresh and clamp dueDate so it never goes into the past
            .onReceive(timer) { _ in
                currentTime = Date()
                if dueDate <= currentTime {
                    dueDate = currentTime
                }
            }
        }
    }

    // Request authorization to show alerts, play sounds, and update badges.
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]) { _, _ in
            // For brevity, ignore the granted/error values here
        }
    }

    // Create and store a new homework item, then schedule its notifications.
    func addHomework() {
        // Require a non-empty subject
        guard !subject.isEmpty else { return }
        // Construct the new model instance
        let hw = Homework(subject: subject, dueDate: dueDate)
        // Add to our in-memory list
        homeworkList.append(hw)
        // Schedule notifications using the current global schedule (or per-item override if you pass it)
        scheduleEscalatingNotifications(for: hw, using: globalSchedule)
        // Reset the input field
        subject = ""
    }

    // Remove selected homework items and cancel any pending notifications for them.
    func removeHomework(at offsets: IndexSet) {
        // Translate visible row offsets into concrete homework IDs from upcomingHomework
        let upcomingIDs = offsets.map { upcomingHomework[$0].id }
        // Cancel all scheduled notifications tied to each homework being removed
        for id in upcomingIDs {
            if let hw = homeworkList.first(where: { $0.id == id }) {
                cancelAllNotifications(for: hw) // ✅ Cancel all notifications on delete
            }
        }
        // Remove from the master list by ID
        homeworkList.removeAll { upcomingIDs.contains($0.id) }
    }

    // Cancel any pending notifications previously scheduled for this homework item.
    func cancelAllNotifications(for hw: Homework) {
        // Remove all notifications whose identifier starts with the homework ID
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            // Collect only the identifiers that were created for this homework (prefix match on UUID)
            let ids = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(hw.id.uuidString) }
            // Bulk-cancel the matching requests
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // Build and schedule a two-phase set of notifications for a homework item.
    // Phase 1 ("far"): From now until switchToHourlyAt hours before the deadline, fire every N hours.
    // Phase 2 ("close"): From switchToHourlyAt hours before the deadline up to the deadline, fire every N minutes.
    // Each scheduled notification receives a unique identifier composed of the homework UUID and an index.
    func scheduleEscalatingNotifications(for hw: Homework, using schedule: NotificationSchedule) {
        // Establish reference times
        let now = Date()
        let deadline = hw.dueDate
        let switchPoint = deadline.addingTimeInterval(-Double(schedule.switchToHourlyAt) * 3600)

        // Collect all fire times across both phases before scheduling
        var fireTimes: [Date] = []

        // Far phase: step forward in hour-sized jumps until the switch point
        var current = now.addingTimeInterval(Double(schedule.daysBeforeInterval) * 3600)
        while current < switchPoint {
            fireTimes.append(current)
            current = current.addingTimeInterval(Double(schedule.daysBeforeInterval) * 3600)
        }

        // Close phase: step forward in minute-sized jumps until the deadline
        current = switchPoint
        while current < deadline {
            fireTimes.append(current)
            current = current.addingTimeInterval(Double(schedule.hoursBeforeInterval) * 60)
        }

        // Schedule each fire time as a separate notification
        for (index, fireTime) in fireTimes.enumerated() {
            // Skip any fire times that are already in the past (race conditions)
            guard fireTime > now else { continue }

            // Configure the notification content
            let content = UNMutableNotificationContent()
            content.title = "Homework Reminder"
            content.sound = .default

            // Customize the message based on whether we're in the far or close phase
            let timeLeft = deadline.timeIntervalSince(fireTime)
            if timeLeft > Double(schedule.switchToHourlyAt) * 3600 {
                let hoursLeft = Int(timeLeft / 3600)
                content.body = "\(hw.subject) is due in \(hoursLeft) hour(s)."
            } else {
                let minutesLeft = Int(timeLeft / 60)
                content.body = "⚠️ \(hw.subject) is due in \(minutesLeft) minute(s)!"
            }

            // Convert the fire time into calendar components for a one-shot trigger
            let triggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

            // Compose a stable identifier that lets us cancel per-homework later
            let identifier = "\(hw.id.uuidString)-\(index)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            // Enqueue the notification with the system
            UNUserNotificationCenter.current().add(request)
        }
    }
}

