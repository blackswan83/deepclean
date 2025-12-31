import SwiftUI

struct CleanView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var whitelistManager = WhitelistManager()
    @State private var isScanning = false
    @State private var isCleaning = false
    @State private var cleanResult: CleanResult?
    @State private var showResult = false

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
                    // Options
                    optionsSection

                    // Categories
                    categoriesSection

                    // Actions
                    actionsSection
                }
                .padding(24)
            }
        }
        .background(SumiColors.background(colorScheme))
        .sheet(isPresented: $showResult) {
            if let result = cleanResult {
                CleanResultView(result: result) {
                    showResult = false
                }
            }
        }
        .onAppear {
            scanCategories()
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
                    Text("clean")
                        .font(SumiTypography.command)
                        .foregroundStyle(SumiColors.accent(colorScheme))
                    CursorBlinkView()
                }

                Text("Deep System Cleanup")
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
            }

            Spacer()

            if isScanning || isCleaning {
                HStack(spacing: 8) {
                    SumiSpinner()
                    Text(isScanning ? "Scanning..." : "Cleaning...")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                }
            }
        }
    }

    // MARK: - Options Section
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Options")

            HStack(spacing: 24) {
                SumiCheckbox(isChecked: $appState.isDryRun, label: "Dry Run (Preview Only)")

                Spacer()

                if appState.isDryRun {
                    StatusBadge(status: .info, text: "No files will be deleted")
                }
            }
            .padding(16)
            .sumiCard()
        }
    }

    // MARK: - Categories Section
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Categories")

                Spacer()

                Button("Select All") {
                    selectAll()
                }
                .buttonStyle(SumiTextButtonStyle())

                Button("Deselect All") {
                    deselectAll()
                }
                .buttonStyle(SumiTextButtonStyle(isAccent: false))
            }

            VStack(spacing: 8) {
                ForEach(appState.cleanCategories.indices, id: \.self) { index in
                    CategoryRow(
                        category: $appState.cleanCategories[index],
                        whitelistManager: whitelistManager
                    )
                }
            }
        }
    }

    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 16) {
            // Progress
            if isCleaning {
                CLIProgressBar(
                    progress: appState.cleanProgress,
                    label: appState.cleanStatus
                )
            }

            // Summary
            summaryView

            // Buttons
            HStack(spacing: 16) {
                Button("Rescan") {
                    scanCategories()
                }
                .buttonStyle(SumiSecondaryButtonStyle())
                .disabled(isScanning || isCleaning)

                Spacer()

                Button(appState.isDryRun ? "Preview Clean" : "Start Clean") {
                    startClean()
                }
                .buttonStyle(SumiPrimaryButtonStyle())
                .disabled(isScanning || isCleaning || !hasSelectedCategories)
            }
        }
        .padding(16)
        .sumiCard()
    }

    // MARK: - Summary View
    private var summaryView: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Selected")
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
                Text("\(selectedCount) categories")
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.primary(colorScheme))
            }

            Divider()
                .frame(height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text("Estimated")
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
                Text(appState.formatBytes(estimatedSize))
                    .font(SumiTypography.monoLarge)
                    .foregroundStyle(SumiColors.accent(colorScheme))
            }

            Spacer()
        }
    }

    // MARK: - Computed Properties
    private var selectedCount: Int {
        appState.cleanCategories.filter(\.isSelected).count
    }

    private var estimatedSize: Int64 {
        appState.cleanCategories.filter(\.isSelected).reduce(0) { $0 + $1.estimatedSize }
    }

    private var hasSelectedCategories: Bool {
        appState.cleanCategories.contains(where: \.isSelected)
    }

    // MARK: - Actions
    private func selectAll() {
        for index in appState.cleanCategories.indices {
            appState.cleanCategories[index].isSelected = true
        }
    }

    private func deselectAll() {
        for index in appState.cleanCategories.indices {
            appState.cleanCategories[index].isSelected = false
        }
    }

    private func scanCategories() {
        isScanning = true

        Task {
            let updated = await CleanService.shared.scanCategories(appState.cleanCategories)

            await MainActor.run {
                appState.cleanCategories = updated
                isScanning = false
            }
        }
    }

    private func startClean() {
        isCleaning = true
        appState.cleanProgress = 0
        appState.cleanStatus = "Starting..."

        Task {
            do {
                let result = try await CleanService.shared.clean(
                    categories: appState.cleanCategories,
                    dryRun: appState.isDryRun,
                    whitelist: whitelistManager
                ) { progress, status in
                    Task { @MainActor in
                        appState.cleanProgress = progress
                        appState.cleanStatus = status
                    }
                }

                await MainActor.run {
                    cleanResult = result
                    showResult = true
                    isCleaning = false

                    if !result.wasDryRun {
                        appState.totalSpaceFreed += result.bytesFreed
                        appState.lastCleanedDate = Date()
                    }

                    // Rescan after cleaning
                    scanCategories()
                }
            } catch {
                await MainActor.run {
                    isCleaning = false
                    appState.cleanStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Category Row
struct CategoryRow: View {
    @Binding var category: CleanCategory
    @ObservedObject var whitelistManager: WhitelistManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: { category.isSelected.toggle() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(category.isSelected ? SumiColors.accent(colorScheme) : SumiColors.border(colorScheme), lineWidth: 1.5)
                            .frame(width: 18, height: 18)

                        if category.isSelected {
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

                Image(systemName: category.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(SumiColors.accent(colorScheme))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.primary(colorScheme))

                    Text(category.description)
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                }

                Spacer()

                Text(formatBytes(category.estimatedSize))
                    .font(SumiTypography.mono)
                    .foregroundStyle(category.estimatedSize > 0 ? SumiColors.accent(colorScheme) : SumiColors.secondary(colorScheme))

                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            if isExpanded {
                Divider()
                    .background(SumiColors.border(colorScheme))

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(category.paths, id: \.self) { path in
                        HStack {
                            Text(path)
                                .font(SumiTypography.monoSmall)
                                .foregroundStyle(SumiColors.secondary(colorScheme))

                            Spacer()

                            if whitelistManager.isWhitelisted((path as NSString).expandingTildeInPath) {
                                StatusBadge(status: .warning, text: "Protected")
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
        .sumiCard()
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Clean Result View
struct CleanResultView: View {
    let result: CleanResult
    let onDismiss: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: result.wasDryRun ? "eye.fill" : "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(SumiColors.accent(colorScheme))

            // Title
            Text(result.wasDryRun ? "Preview Complete" : "Cleanup Complete")
                .font(SumiTypography.monoTitle)
                .foregroundStyle(SumiColors.primary(colorScheme))

            // Stats
            VStack(spacing: 12) {
                HStack {
                    Text("Space \(result.wasDryRun ? "to free" : "freed"):")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                    Spacer()
                    Text(result.formattedSize)
                        .font(SumiTypography.monoLarge)
                        .foregroundStyle(SumiColors.accent(colorScheme))
                }

                HStack {
                    Text("Files \(result.wasDryRun ? "to delete" : "deleted"):")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                    Spacer()
                    Text("\(result.filesDeleted)")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.primary(colorScheme))
                }

                if !result.errors.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Errors:")
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
            .padding(16)
            .sumiCard()

            // Button
            Button("Done", action: onDismiss)
                .buttonStyle(SumiPrimaryButtonStyle())
        }
        .padding(32)
        .frame(width: 400)
        .background(SumiColors.background(colorScheme))
    }
}

#Preview {
    CleanView()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
