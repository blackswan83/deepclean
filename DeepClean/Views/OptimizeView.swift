import SwiftUI

struct OptimizeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var isRunning = false
    @State private var currentTask: String = ""
    @State private var progress: Double = 0
    @State private var results: [OptimizeResult] = []
    @State private var showResults = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(24)

            Divider()
                .background(SumiColors.border(colorScheme))

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Tasks
                    tasksSection

                    // Progress
                    if isRunning {
                        progressSection
                    }

                    // Actions
                    actionsSection
                }
                .padding(24)
            }
        }
        .background(SumiColors.background(colorScheme))
        .sheet(isPresented: $showResults) {
            OptimizeResultsView(results: results) {
                showResults = false
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("mo")
                        .font(SumiTypography.command)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                    Text("optimize")
                        .font(SumiTypography.command)
                        .foregroundStyle(SumiColors.accent(colorScheme))
                    CursorBlinkView()
                }

                Text("System Optimization")
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
            }

            Spacer()

            if isRunning {
                HStack(spacing: 8) {
                    SumiSpinner()
                    Text("Optimizing...")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                }
            }
        }
    }

    // MARK: - Tasks Section
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Optimization Tasks")

            VStack(spacing: 8) {
                ForEach(appState.optimizeTasks.indices, id: \.self) { index in
                    TaskRow(task: appState.optimizeTasks[index])
                }
            }
        }
    }

    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 12) {
            CLIProgressBar(
                progress: progress,
                label: currentTask
            )

            if !results.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(results.suffix(3)) { result in
                        HStack(spacing: 8) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(result.success ? Color.successGreen : Color.errorRed)

                            Text(result.taskName)
                                .font(SumiTypography.monoSmall)
                                .foregroundStyle(SumiColors.primary(colorScheme))

                            Spacer()

                            Text(result.success ? "Done" : "Failed")
                                .font(SumiTypography.monoSmall)
                                .foregroundStyle(result.success ? Color.successGreen : Color.errorRed)
                        }
                    }
                }
            }
        }
        .padding(16)
        .sumiCard()
    }

    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 16) {
            // Info
            HStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.warningOrange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Some tasks require administrator privileges")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.primary(colorScheme))

                    Text("You will be prompted to enter your password for system-level operations.")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.warningOrange.opacity(0.1))
            )

            // Buttons
            HStack(spacing: 16) {
                Spacer()

                Button("Run All Tasks") {
                    runAllTasks()
                }
                .buttonStyle(SumiPrimaryButtonStyle())
                .disabled(isRunning)
            }
        }
        .padding(16)
        .sumiCard()
    }

    // MARK: - Actions
    private func runAllTasks() {
        isRunning = true
        results = []
        progress = 0

        Task {
            let taskResults = await OptimizeService.shared.runAllTasks(appState.optimizeTasks) { prog, status in
                Task { @MainActor in
                    progress = prog
                    currentTask = status
                }
            }

            await MainActor.run {
                results = taskResults
                isRunning = false
                showResults = true
            }
        }
    }
}

// MARK: - Task Row
struct TaskRow: View {
    let task: OptimizeTask

    @Environment(\.colorScheme) var colorScheme
    @State private var isRunning = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: task.icon)
                .font(.system(size: 16))
                .foregroundStyle(SumiColors.accent(colorScheme))
                .frame(width: 24)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(task.name)
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.primary(colorScheme))

                    if task.requiresSudo {
                        Text("sudo")
                            .font(SumiTypography.monoSmall)
                            .foregroundStyle(Color.warningOrange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.warningOrange.opacity(0.1))
                            )
                    }
                }

                Text(task.description)
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
            }

            Spacer()

            // Status
            if task.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.successGreen)
            } else if task.isRunning || isRunning {
                SumiSpinner()
            }

            // Run Button
            Button(action: { runTask() }) {
                Text("Run")
                    .font(SumiTypography.monoSmall)
            }
            .buttonStyle(SumiSecondaryButtonStyle())
            .disabled(isRunning || task.isRunning)
        }
        .padding(12)
        .sumiCard()
    }

    private func runTask() {
        isRunning = true

        Task {
            _ = try? await OptimizeService.shared.runTask(task)

            await MainActor.run {
                isRunning = false
            }
        }
    }
}

// MARK: - Optimize Results View
struct OptimizeResultsView: View {
    let results: [OptimizeResult]
    let onDismiss: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: allSuccessful ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(allSuccessful ? SumiColors.accent(colorScheme) : Color.warningOrange)

            // Title
            Text("Optimization Complete")
                .font(SumiTypography.monoTitle)
                .foregroundStyle(SumiColors.primary(colorScheme))

            // Summary
            VStack(spacing: 12) {
                HStack {
                    Text("Tasks completed:")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                    Spacer()
                    Text("\(successCount) / \(results.count)")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.primary(colorScheme))
                }
            }
            .padding(16)
            .sumiCard()

            // Details
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(results) { result in
                        HStack(spacing: 12) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(result.success ? Color.successGreen : Color.errorRed)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.taskName)
                                    .font(SumiTypography.mono)
                                    .foregroundStyle(SumiColors.primary(colorScheme))

                                if let error = result.error {
                                    Text(error)
                                        .font(SumiTypography.monoSmall)
                                        .foregroundStyle(Color.errorRed)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()
                        }
                        .padding(8)
                    }
                }
            }
            .frame(maxHeight: 200)
            .padding(16)
            .sumiCard()

            // Button
            Button("Done", action: onDismiss)
                .buttonStyle(SumiPrimaryButtonStyle())
        }
        .padding(32)
        .frame(width: 450)
        .background(SumiColors.background(colorScheme))
    }

    private var successCount: Int {
        results.filter(\.success).count
    }

    private var allSuccessful: Bool {
        successCount == results.count
    }
}

#Preview {
    OptimizeView()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
