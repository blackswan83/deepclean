import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var isQuickCleaning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection
                .padding(12)

            Divider()

            // Quick Stats
            statsSection
                .padding(12)

            Divider()

            // Quick Actions
            actionsSection

            Divider()

            // Footer
            footerSection
        }
        .frame(width: 280)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundStyle(SumiColors.accent(colorScheme))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("deep")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.primary(colorScheme))
                    Text("clean")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.accent(colorScheme))
                }

                Text("System Cleaner")
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
            }

            Spacer()

            // Health Score
            healthBadge
        }
    }

    private var healthBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(appState.systemStatus.healthColor)
                .frame(width: 8, height: 8)

            Text("\(appState.systemStatus.healthScore)")
                .font(SumiTypography.mono)
                .foregroundStyle(SumiColors.primary(colorScheme))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(appState.systemStatus.healthColor.opacity(0.1))
        )
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(spacing: 8) {
            // CPU
            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 12))
                    .foregroundStyle(SumiColors.secondary(colorScheme))
                    .frame(width: 20)

                Text("CPU")
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))

                Spacer()

                Text("\(Int(appState.systemStatus.cpuUsage))%")
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.primary(colorScheme))
            }

            // Memory
            HStack {
                Image(systemName: "memorychip")
                    .font(.system(size: 12))
                    .foregroundStyle(SumiColors.secondary(colorScheme))
                    .frame(width: 20)

                Text("Memory")
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))

                Spacer()

                Text("\(Int(appState.systemStatus.memoryPercentage * 100))%")
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.primary(colorScheme))
            }

            // Disk
            HStack {
                Image(systemName: "internaldrive")
                    .font(.system(size: 12))
                    .foregroundStyle(SumiColors.secondary(colorScheme))
                    .frame(width: 20)

                Text("Disk")
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))

                Spacer()

                Text(formatBytes(appState.systemStatus.diskFree) + " free")
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.primary(colorScheme))
            }

            // Total Freed
            if appState.totalSpaceFreed > 0 {
                Divider()
                    .padding(.vertical, 4)

                HStack {
                    Image(systemName: "arrow.up.trash")
                        .font(.system(size: 12))
                        .foregroundStyle(SumiColors.accent(colorScheme))
                        .frame(width: 20)

                    Text("Total freed")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))

                    Spacer()

                    Text(formatBytes(appState.totalSpaceFreed))
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.accent(colorScheme))
                }
            }
        }
    }

    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 0) {
            MenuButton(
                title: "Quick Clean",
                icon: "trash",
                isLoading: isQuickCleaning
            ) {
                quickClean()
            }

            MenuButton(title: "Open DeepClean", icon: "macwindow") {
                openMainWindow()
            }

            MenuButton(title: "Scan Applications", icon: "magnifyingglass") {
                appState.selectedItem = .uninstall
                openMainWindow()
            }

            MenuButton(title: "System Status", icon: "waveform.path.ecg") {
                appState.selectedItem = .status
                openMainWindow()
            }
        }
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        HStack {
            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.plain)
            .font(SumiTypography.monoSmall)
            .foregroundStyle(SumiColors.secondary(colorScheme))

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(SumiTypography.monoSmall)
            .foregroundStyle(SumiColors.secondary(colorScheme))
        }
        .padding(12)
    }

    // MARK: - Actions
    private func quickClean() {
        isQuickCleaning = true

        Task {
            // Quick clean: user caches and browser caches only
            var quickCategories = CleanCategory.defaultCategories
            for i in quickCategories.indices {
                quickCategories[i].isSelected = quickCategories[i].name == "User Caches" ||
                    quickCategories[i].name == "Browser Caches"
            }

            let result = try? await CleanService.shared.clean(
                categories: quickCategories,
                dryRun: false,
                whitelist: WhitelistManager()
            ) { _, _ in }

            await MainActor.run {
                if let result = result {
                    appState.totalSpaceFreed += result.bytesFreed
                    appState.lastCleanedDate = Date()
                }
                isQuickCleaning = false
            }
        }
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Menu Button
struct MenuButton: View {
    let title: String
    let icon: String
    var isLoading: Bool = false
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    SumiSpinner()
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                        .frame(width: 16)
                }

                Text(title)
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.primary(colorScheme))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? SumiColors.accent(colorScheme).opacity(0.1) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppState())
}
