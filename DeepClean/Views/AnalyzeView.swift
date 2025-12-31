import SwiftUI

struct AnalyzeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var isScanning = false
    @State private var selectedItems: Set<String> = []
    @State private var showLargeFiles = false
    @State private var largeFiles: [DiskItem] = []
    @State private var diskUsage: (total: Int64, used: Int64, free: Int64) = (0, 0, 0)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(24)

            Divider()
                .background(SumiColors.border(colorScheme))

            // Disk Usage Bar
            diskUsageView
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

            Divider()
                .background(SumiColors.border(colorScheme))

            // Breadcrumb
            breadcrumbView
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

            // Content
            if isScanning {
                Spacer()
                VStack(spacing: 16) {
                    SumiSpinner()
                    Text("Scanning directory...")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                }
                Spacer()
            } else {
                contentView
            }
        }
        .background(SumiColors.background(colorScheme))
        .onAppear {
            loadDiskUsage()
            scanCurrentPath()
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
                    Text("analyze")
                        .font(SumiTypography.command)
                        .foregroundStyle(SumiColors.accent(colorScheme))
                    CursorBlinkView()
                }

                Text("Disk Space Analyzer")
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
            }

            Spacer()

            // View Toggle
            HStack(spacing: 8) {
                Button(action: { showLargeFiles = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text("Browse")
                    }
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(!showLargeFiles ? SumiColors.accent(colorScheme) : SumiColors.secondary(colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(!showLargeFiles ? SumiColors.accent(colorScheme).opacity(0.1) : .clear)
                    )
                }
                .buttonStyle(.plain)

                Button(action: {
                    showLargeFiles = true
                    scanLargeFiles()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.fill")
                        Text("Large Files")
                    }
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(showLargeFiles ? SumiColors.accent(colorScheme) : SumiColors.secondary(colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(showLargeFiles ? SumiColors.accent(colorScheme).opacity(0.1) : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Disk Usage View
    private var diskUsageView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Disk Usage")
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.primary(colorScheme))

                    Text("\(formatBytes(diskUsage.used)) of \(formatBytes(diskUsage.total))")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatBytes(diskUsage.free))
                        .font(SumiTypography.monoLarge)
                        .foregroundStyle(SumiColors.accent(colorScheme))

                    Text("available")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(SumiColors.border(colorScheme))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(diskUsageColor)
                        .frame(width: geometry.size.width * diskUsagePercent)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .sumiCard()
    }

    private var diskUsagePercent: Double {
        guard diskUsage.total > 0 else { return 0 }
        return Double(diskUsage.used) / Double(diskUsage.total)
    }

    private var diskUsageColor: Color {
        if diskUsagePercent > 0.9 {
            return .errorRed
        } else if diskUsagePercent > 0.75 {
            return .warningOrange
        }
        return SumiColors.accent(colorScheme)
    }

    // MARK: - Breadcrumb
    private var breadcrumbView: some View {
        HStack(spacing: 4) {
            Button(action: goToRoot) {
                Image(systemName: "house")
                    .font(.system(size: 12))
                    .foregroundStyle(SumiColors.accent(colorScheme))
            }
            .buttonStyle(.plain)

            let components = appState.currentPath.split(separator: "/").map(String.init)
            ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                Text("/")
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))

                Button(action: { navigateTo(index: index) }) {
                    Text(component)
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(index == components.count - 1 ? SumiColors.primary(colorScheme) : SumiColors.accent(colorScheme))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Navigation buttons
            HStack(spacing: 8) {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                }
                .buttonStyle(SumiTextButtonStyle())
                .disabled(appState.pathHistory.isEmpty)

                Button(action: scanCurrentPath) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(SumiTextButtonStyle())
            }
        }
    }

    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        if showLargeFiles {
            largeFilesView
        } else {
            directoryView
        }
    }

    // MARK: - Directory View
    private var directoryView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(appState.diskItems, id: \.path) { item in
                    DiskItemRow(
                        item: item,
                        isSelected: selectedItems.contains(item.path),
                        maxSize: appState.diskItems.first?.size ?? 1
                    ) {
                        if item.isDirectory {
                            navigateTo(path: item.path)
                        }
                    } onSelect: {
                        toggleSelection(item)
                    } onOpen: {
                        openItem(item)
                    } onReveal: {
                        revealInFinder(item)
                    } onDelete: {
                        deleteItem(item)
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Large Files View
    private var largeFilesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Files larger than 100 MB")
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.secondary(colorScheme))

                if largeFiles.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "No Large Files",
                        message: "No files larger than 100 MB found"
                    )
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(largeFiles, id: \.path) { item in
                            DiskItemRow(
                                item: item,
                                isSelected: selectedItems.contains(item.path),
                                maxSize: largeFiles.first?.size ?? 1
                            ) {
                                // No navigation for files
                            } onSelect: {
                                toggleSelection(item)
                            } onOpen: {
                                openItem(item)
                            } onReveal: {
                                revealInFinder(item)
                            } onDelete: {
                                deleteItem(item)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Actions
    private func loadDiskUsage() {
        Task {
            let usage = await AnalyzeService.shared.getDiskUsage()
            await MainActor.run {
                diskUsage = usage
            }
        }
    }

    private func scanCurrentPath() {
        isScanning = true

        Task {
            let items = await AnalyzeService.shared.scanDirectory(at: appState.currentPath)

            await MainActor.run {
                appState.diskItems = items
                isScanning = false
            }
        }
    }

    private func scanLargeFiles() {
        isScanning = true

        Task {
            let files = await AnalyzeService.shared.findLargeFiles(in: NSHomeDirectory())

            await MainActor.run {
                largeFiles = files
                isScanning = false
            }
        }
    }

    private func navigateTo(path: String) {
        appState.pathHistory.append(appState.currentPath)
        appState.currentPath = path
        scanCurrentPath()
    }

    private func navigateTo(index: Int) {
        let components = appState.currentPath.split(separator: "/").map(String.init)
        let newPath = "/" + components.prefix(index + 1).joined(separator: "/")

        if newPath != appState.currentPath {
            appState.pathHistory.append(appState.currentPath)
            appState.currentPath = newPath
            scanCurrentPath()
        }
    }

    private func goToRoot() {
        appState.pathHistory.append(appState.currentPath)
        appState.currentPath = NSHomeDirectory()
        scanCurrentPath()
    }

    private func goBack() {
        guard let previousPath = appState.pathHistory.popLast() else { return }
        appState.currentPath = previousPath
        scanCurrentPath()
    }

    private func toggleSelection(_ item: DiskItem) {
        if selectedItems.contains(item.path) {
            selectedItems.remove(item.path)
        } else {
            selectedItems.insert(item.path)
        }
    }

    private func openItem(_ item: DiskItem) {
        Task {
            await AnalyzeService.shared.openItem(item.path)
        }
    }

    private func revealInFinder(_ item: DiskItem) {
        Task {
            await AnalyzeService.shared.revealInFinder(item.path)
        }
    }

    private func deleteItem(_ item: DiskItem) {
        Task {
            try? await AnalyzeService.shared.deleteItem(at: item.path)
            await MainActor.run {
                selectedItems.remove(item.path)
                scanCurrentPath()
                loadDiskUsage()
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Disk Item Row
struct DiskItemRow: View {
    let item: DiskItem
    let isSelected: Bool
    let maxSize: Int64
    let onNavigate: () -> Void
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: item.isDirectory ? "folder.fill" : fileIcon)
                .font(.system(size: 16))
                .foregroundStyle(item.isDirectory ? .warningOrange : SumiColors.secondary(colorScheme))
                .frame(width: 24)

            // Name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.primary(colorScheme))
                        .lineLimit(1)

                    if let age = item.ageIndicator {
                        Text(age)
                            .font(SumiTypography.monoSmall)
                            .foregroundStyle(.warningOrange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.warningOrange.opacity(0.1))
                            )
                    }
                }

                if item.isDirectory, let count = item.childCount {
                    Text("\(count) items")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                }
            }

            Spacer()

            // Size Bar
            SizeBar(
                percentage: Double(item.size) / Double(maxSize),
                color: sizeColor
            )
            .frame(width: 100)

            // Size
            Text(formatBytes(item.size))
                .font(SumiTypography.mono)
                .foregroundStyle(SumiColors.accent(colorScheme))
                .frame(width: 80, alignment: .trailing)

            // Actions
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onOpen) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(SumiTextButtonStyle())
                    .help("Open")

                    Button(action: onReveal) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(SumiTextButtonStyle())
                    .help("Show in Finder")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(SumiTextButtonStyle(isAccent: false))
                    .help("Move to Trash")
                }
            }

            // Arrow for directories
            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(SumiColors.secondary(colorScheme))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? SumiColors.accent(colorScheme).opacity(0.1) : (isHovered ? SumiColors.surface(colorScheme) : .clear))
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            if item.isDirectory {
                onNavigate()
            } else {
                onOpen()
            }
        }
        .onTapGesture {
            onSelect()
        }
    }

    private var fileIcon: String {
        let ext = (item.name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.fill"
        case "jpg", "jpeg", "png", "gif", "heic": return "photo.fill"
        case "mp4", "mov", "avi", "mkv": return "film.fill"
        case "mp3", "wav", "aac", "m4a": return "music.note"
        case "zip", "tar", "gz", "rar": return "archivebox.fill"
        case "dmg", "iso": return "opticaldisc.fill"
        case "app": return "app.fill"
        default: return "doc.fill"
        }
    }

    private var sizeColor: Color {
        let percent = Double(item.size) / Double(maxSize)
        if percent > 0.5 {
            return .errorRed
        } else if percent > 0.25 {
            return .warningOrange
        }
        return SumiColors.accent(colorScheme)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

#Preview {
    AnalyzeView()
        .environmentObject(AppState())
        .frame(width: 900, height: 700)
}
