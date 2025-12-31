import SwiftUI
import Combine

struct StatusView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var isRefreshing = false
    @State private var timer: AnyCancellable?

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
                    // Health Score
                    healthScoreSection

                    // Metrics Grid
                    metricsGrid

                    // Top Processes
                    processesSection
                }
                .padding(24)
            }
        }
        .background(SumiColors.background(colorScheme))
        .onAppear {
            refreshMetrics()
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
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
                    Text("status")
                        .font(SumiTypography.command)
                        .foregroundStyle(SumiColors.accent(colorScheme))
                    CursorBlinkView()
                }

                Text("Live System Status")
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
            }

            Spacer()

            // Live indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(isRefreshing ? SumiColors.accent(colorScheme) : .successGreen)
                    .frame(width: 8, height: 8)

                Text("Live")
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))

                Button(action: refreshMetrics) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(SumiTextButtonStyle())
            }
        }
    }

    // MARK: - Health Score Section
    private var healthScoreSection: some View {
        HStack(spacing: 24) {
            // Score Circle
            ZStack {
                Circle()
                    .stroke(SumiColors.border(colorScheme), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: Double(appState.systemStatus.healthScore) / 100)
                    .stroke(appState.systemStatus.healthColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(appState.systemStatus.healthScore)")
                        .font(SumiTypography.metric)
                        .foregroundStyle(SumiColors.primary(colorScheme))

                    Text("Health")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                }
            }

            // Health Details
            VStack(alignment: .leading, spacing: 12) {
                Text(appState.systemStatus.healthDescription)
                    .font(SumiTypography.monoTitle)
                    .foregroundStyle(appState.systemStatus.healthColor)

                Text(healthMessage)
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.secondary(colorScheme))

                // Quick stats
                HStack(spacing: 16) {
                    QuickStat(label: "CPU", value: "\(Int(appState.systemStatus.cpuUsage))%")
                    QuickStat(label: "RAM", value: "\(Int(appState.systemStatus.memoryPercentage * 100))%")
                    QuickStat(label: "Disk", value: "\(Int(appState.systemStatus.diskPercentage * 100))%")
                }
            }

            Spacer()
        }
        .padding(24)
        .sumiCard()
    }

    private var healthMessage: String {
        switch appState.systemStatus.healthScore {
        case 80...100:
            return "Your system is running smoothly."
        case 60..<80:
            return "Your system is performing well with minor issues."
        case 40..<60:
            return "Consider freeing up some resources."
        case 20..<40:
            return "System performance may be degraded."
        default:
            return "Immediate attention recommended."
        }
    }

    // MARK: - Metrics Grid
    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            // CPU
            MetricCard(
                title: "CPU Usage",
                value: "\(Int(appState.systemStatus.cpuUsage))%",
                subtitle: "Load: \(String(format: "%.2f", appState.systemStatus.loadAverage.0))",
                icon: "cpu"
            )

            // Memory
            MetricCard(
                title: "Memory",
                value: formatBytes(appState.systemStatus.memoryUsed),
                subtitle: "\(formatBytes(appState.systemStatus.memoryFree)) free",
                icon: "memorychip"
            )

            // Disk
            MetricCard(
                title: "Disk",
                value: formatBytes(appState.systemStatus.diskUsed),
                subtitle: "\(formatBytes(appState.systemStatus.diskFree)) free",
                icon: "internaldrive"
            )

            // Battery
            if appState.systemStatus.batteryLevel > 0 {
                MetricCard(
                    title: "Battery",
                    value: "\(appState.systemStatus.batteryLevel)%",
                    subtitle: appState.systemStatus.isCharging ? "Charging" : "On Battery",
                    icon: batteryIcon
                )
            } else {
                MetricCard(
                    title: "Power",
                    value: "AC",
                    subtitle: "Connected to power",
                    icon: "bolt.fill"
                )
            }
        }
    }

    private var batteryIcon: String {
        let level = appState.systemStatus.batteryLevel
        if appState.systemStatus.isCharging {
            return "battery.100.bolt"
        }
        switch level {
        case 75...100: return "battery.100"
        case 50..<75: return "battery.75"
        case 25..<50: return "battery.50"
        default: return "battery.25"
        }
    }

    // MARK: - Processes Section
    private var processesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Top Processes", subtitle: "by CPU usage")

            VStack(spacing: 4) {
                // Header
                HStack {
                    Text("Process")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("PID")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                        .frame(width: 60)

                    Text("CPU")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                        .frame(width: 60)

                    Text("Memory")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                        .frame(width: 80)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()
                    .background(SumiColors.border(colorScheme))

                // Processes
                ForEach(appState.systemStatus.topProcesses) { process in
                    ProcessRow(process: process)
                }

                if appState.systemStatus.topProcesses.isEmpty {
                    Text("No processes to display")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                        .padding(12)
                }
            }
            .sumiCard()
        }
    }

    // MARK: - Actions
    private func refreshMetrics() {
        isRefreshing = true

        Task {
            let status = await StatusService.shared.collectMetrics()

            await MainActor.run {
                appState.systemStatus = status
                isRefreshing = false
            }
        }
    }

    private func startAutoRefresh() {
        timer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                refreshMetrics()
            }
    }

    private func stopAutoRefresh() {
        timer?.cancel()
        timer = nil
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Quick Stat
struct QuickStat: View {
    let label: String
    let value: String

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(SumiTypography.mono)
                .foregroundStyle(SumiColors.primary(colorScheme))

            Text(label)
                .font(SumiTypography.monoSmall)
                .foregroundStyle(SumiColors.secondary(colorScheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(SumiColors.surface(colorScheme))
        )
    }
}

// MARK: - Process Row
struct ProcessRow: View {
    let process: SystemStatus.ProcessInfo

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Text(process.name)
                .font(SumiTypography.mono)
                .foregroundStyle(SumiColors.primary(colorScheme))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(process.pid)")
                .font(SumiTypography.monoSmall)
                .foregroundStyle(SumiColors.secondary(colorScheme))
                .frame(width: 60)

            Text("\(String(format: "%.1f", process.cpuUsage))%")
                .font(SumiTypography.mono)
                .foregroundStyle(cpuColor)
                .frame(width: 60)

            Text(formatBytes(process.memoryUsage))
                .font(SumiTypography.monoSmall)
                .foregroundStyle(SumiColors.secondary(colorScheme))
                .frame(width: 80)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var cpuColor: Color {
        if process.cpuUsage > 50 {
            return .errorRed
        } else if process.cpuUsage > 20 {
            return .warningOrange
        }
        return SumiColors.accent(colorScheme)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }
}

#Preview {
    StatusView()
        .environmentObject(AppState())
        .frame(width: 900, height: 700)
}
