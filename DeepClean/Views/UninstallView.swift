import SwiftUI

struct UninstallView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .size
    @State private var showResiduals = true
    @State private var isUninstalling = false
    @State private var uninstallResults: [UninstallResult] = []
    @State private var showResults = false

    enum SortOrder: String, CaseIterable {
        case size = "Size"
        case name = "Name"
        case recent = "Recent"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(24)

            Divider()
                .background(SumiColors.border(colorScheme))

            // Toolbar
            toolbarView
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

            // App List
            if appState.isScanning {
                Spacer()
                VStack(spacing: 16) {
                    SumiSpinner()
                    Text("Scanning applications...")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                }
                Spacer()
            } else if filteredApps.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "app.badge.checkmark",
                    title: "No Applications Found",
                    message: searchText.isEmpty ? "No applications found in /Applications" : "No applications match your search"
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredApps, id: \.bundleId) { app in
                            AppRow(
                                app: app,
                                isSelected: appState.selectedApps.contains(app.bundleId),
                                showResiduals: showResiduals
                            ) {
                                toggleSelection(app)
                            }
                        }
                    }
                    .padding(24)
                }
            }

            Divider()
                .background(SumiColors.border(colorScheme))

            // Footer
            footerView
                .padding(24)
        }
        .background(SumiColors.background(colorScheme))
        .sheet(isPresented: $showResults) {
            UninstallResultsView(results: uninstallResults) {
                showResults = false
            }
        }
        .onAppear {
            if appState.installedApps.isEmpty {
                scanApps()
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
                    Text("uninstall")
                        .font(SumiTypography.command)
                        .foregroundStyle(SumiColors.accent(colorScheme))
                    CursorBlinkView()
                }

                Text("Smart App Uninstaller")
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
            }

            Spacer()
        }
    }

    // MARK: - Toolbar
    private var toolbarView: some View {
        HStack(spacing: 16) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(SumiColors.secondary(colorScheme))

                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(SumiTypography.mono)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(SumiColors.secondary(colorScheme))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(SumiColors.surface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Sort
            Picker("Sort", selection: $sortOrder) {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            // Show Residuals Toggle
            Toggle("Show Residuals", isOn: $showResiduals)
                .toggleStyle(.switch)
                .font(SumiTypography.monoSmall)

            Spacer()

            // Refresh
            Button(action: scanApps) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(SumiTextButtonStyle())
            .disabled(appState.isScanning)
        }
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(appState.selectedApps.count) selected")
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.primary(colorScheme))

                Text("Total: \(formatBytes(selectedTotalSize))")
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
            }

            Spacer()

            Button("Clear Selection") {
                appState.selectedApps.removeAll()
            }
            .buttonStyle(SumiTextButtonStyle(isAccent: false))
            .disabled(appState.selectedApps.isEmpty)

            Button("Uninstall Selected") {
                uninstallSelected()
            }
            .buttonStyle(SumiPrimaryButtonStyle())
            .disabled(appState.selectedApps.isEmpty || isUninstalling)
        }
    }

    // MARK: - Computed Properties
    private var filteredApps: [InstalledApp] {
        var apps = appState.installedApps

        // Filter by search
        if !searchText.isEmpty {
            apps = apps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleId.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort
        switch sortOrder {
        case .size:
            apps.sort { $0.size > $1.size }
        case .name:
            apps.sort { $0.name < $1.name }
        case .recent:
            apps.sort { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
        }

        return apps
    }

    private var selectedTotalSize: Int64 {
        appState.installedApps
            .filter { appState.selectedApps.contains($0.bundleId) }
            .reduce(0) { total, app in
                total + app.size + app.residualPaths.reduce(0) { $0 + $1.size }
            }
    }

    // MARK: - Actions
    private func toggleSelection(_ app: InstalledApp) {
        if appState.selectedApps.contains(app.bundleId) {
            appState.selectedApps.remove(app.bundleId)
        } else {
            appState.selectedApps.insert(app.bundleId)
        }
    }

    private func scanApps() {
        appState.isScanning = true

        Task {
            let apps = await UninstallService.shared.scanInstalledApps()

            await MainActor.run {
                appState.installedApps = apps
                appState.isScanning = false
            }
        }
    }

    private func uninstallSelected() {
        isUninstalling = true

        let appsToUninstall = appState.installedApps.filter {
            appState.selectedApps.contains($0.bundleId)
        }

        Task {
            do {
                let results = try await UninstallService.shared.batchUninstall(
                    apps: appsToUninstall,
                    includeResiduals: showResiduals
                )

                await MainActor.run {
                    uninstallResults = results
                    showResults = true
                    isUninstalling = false

                    // Update total space freed
                    let totalFreed = results.reduce(0) { $0 + $1.bytesFreed }
                    appState.totalSpaceFreed += totalFreed

                    // Clear selection and rescan
                    appState.selectedApps.removeAll()
                    scanApps()
                }
            } catch {
                await MainActor.run {
                    isUninstalling = false
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - App Row
struct AppRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let showResiduals: Bool
    let onToggle: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Checkbox
                Button(action: onToggle) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? SumiColors.accent(colorScheme) : SumiColors.border(colorScheme), lineWidth: 1.5)
                            .frame(width: 18, height: 18)

                        if isSelected {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(SumiColors.accent(colorScheme))
                                .frame(width: 18, height: 18)

                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                // App Icon
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                        .frame(width: 32, height: 32)
                }

                // App Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.primary(colorScheme))

                    Text(app.bundleId)
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                }

                Spacer()

                // Last Used
                if let lastUsed = app.lastUsed {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Last used")
                            .font(SumiTypography.monoSmall)
                            .foregroundStyle(SumiColors.secondary(colorScheme))
                        Text(lastUsed, style: .relative)
                            .font(SumiTypography.monoSmall)
                            .foregroundStyle(SumiColors.secondary(colorScheme))
                    }
                }

                // Size
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatBytes(totalSize))
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.accent(colorScheme))

                    if showResiduals && !app.residualPaths.isEmpty {
                        Text("+\(formatBytes(residualSize)) residuals")
                            .font(SumiTypography.monoSmall)
                            .foregroundStyle(SumiColors.secondary(colorScheme))
                    }
                }

                // Expand Button
                if showResiduals && !app.residualPaths.isEmpty {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(SumiColors.secondary(colorScheme))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)

            // Residuals
            if isExpanded && showResiduals {
                Divider()
                    .background(SumiColors.border(colorScheme))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Residual Files (\(app.residualPaths.count) locations)")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))

                    ForEach(app.residualPaths, id: \.id) { residual in
                        HStack {
                            Text(residual.type.rawValue)
                                .font(SumiTypography.monoSmall)
                                .foregroundStyle(SumiColors.accent(colorScheme))
                                .frame(width: 120, alignment: .leading)

                            Text(residual.path)
                                .font(SumiTypography.monoSmall)
                                .foregroundStyle(SumiColors.secondary(colorScheme))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Text(formatBytes(residual.size))
                                .font(SumiTypography.monoSmall)
                                .foregroundStyle(SumiColors.secondary(colorScheme))
                        }
                    }
                }
                .padding(12)
            }
        }
        .sumiCard()
    }

    private var totalSize: Int64 {
        app.size
    }

    private var residualSize: Int64 {
        app.residualPaths.reduce(0) { $0 + $1.size }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Uninstall Results View
struct UninstallResultsView: View {
    let results: [UninstallResult]
    let onDismiss: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: successCount == results.count ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(successCount == results.count ? SumiColors.accent(colorScheme) : Color.warningOrange)

            // Title
            Text("Uninstall Complete")
                .font(SumiTypography.monoTitle)
                .foregroundStyle(SumiColors.primary(colorScheme))

            // Summary
            VStack(spacing: 12) {
                HStack {
                    Text("Apps removed:")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                    Spacer()
                    Text("\(successCount) / \(results.count)")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.primary(colorScheme))
                }

                HStack {
                    Text("Space freed:")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                    Spacer()
                    Text(formatBytes(totalFreed))
                        .font(SumiTypography.monoLarge)
                        .foregroundStyle(SumiColors.accent(colorScheme))
                }

                HStack {
                    Text("Residuals removed:")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                    Spacer()
                    Text("\(totalResiduals)")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.primary(colorScheme))
                }
            }
            .padding(16)
            .sumiCard()

            // Details
            if results.contains(where: { !$0.success }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(results.filter { !$0.success }, id: \.appName) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.appName)
                                    .font(SumiTypography.mono)
                                    .foregroundStyle(Color.errorRed)

                                ForEach(result.errors, id: \.self) { error in
                                    Text("• \(error)")
                                        .font(SumiTypography.monoSmall)
                                        .foregroundStyle(SumiColors.secondary(colorScheme))
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
                .padding(16)
                .sumiCard()
            }

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

    private var totalFreed: Int64 {
        results.reduce(0) { $0 + $1.bytesFreed }
    }

    private var totalResiduals: Int {
        results.reduce(0) { $0 + $1.residualsRemoved }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

#Preview {
    UninstallView()
        .environmentObject(AppState())
        .frame(width: 900, height: 700)
}
