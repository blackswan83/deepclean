import SwiftUI
import Combine

// MARK: - Navigation
enum NavigationItem: String, CaseIterable, Identifiable {
    case clean = "clean"
    case uninstall = "uninstall"
    case analyze = "analyze"
    case optimize = "optimize"
    case status = "status"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clean: return "Deep Clean"
        case .uninstall: return "Uninstall"
        case .analyze: return "Analyze"
        case .optimize: return "Optimize"
        case .status: return "Status"
        }
    }

    var icon: String {
        switch self {
        case .clean: return "trash"
        case .uninstall: return "xmark.app"
        case .analyze: return "chart.pie"
        case .optimize: return "bolt"
        case .status: return "waveform.path.ecg"
        }
    }

    var command: String {
        switch self {
        case .clean: return "mo clean"
        case .uninstall: return "mo uninstall"
        case .analyze: return "mo analyze"
        case .optimize: return "mo optimize"
        case .status: return "mo status"
        }
    }

    var description: String {
        switch self {
        case .clean: return "Clear caches, logs, and temporary files"
        case .uninstall: return "Remove apps and residual files"
        case .analyze: return "Explore disk usage visually"
        case .optimize: return "Rebuild system databases"
        case .status: return "Monitor system health"
        }
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var selectedItem: NavigationItem = .clean
    @Published var isProcessing: Bool = false
    @Published var lastCleanedDate: Date?
    @Published var totalSpaceFreed: Int64 = 0
    @Published var showSettings: Bool = false

    // Clean State
    @Published var cleanCategories: [CleanCategory] = CleanCategory.defaultCategories
    @Published var isDryRun: Bool = true
    @Published var cleanProgress: Double = 0
    @Published var cleanStatus: String = ""

    // Uninstall State
    @Published var installedApps: [InstalledApp] = []
    @Published var selectedApps: Set<String> = []
    @Published var isScanning: Bool = false

    // Analyze State
    @Published var diskItems: [DiskItem] = []
    @Published var currentPath: String = NSHomeDirectory()
    @Published var pathHistory: [String] = []

    // Optimize State
    @Published var optimizeTasks: [OptimizeTask] = OptimizeTask.defaultTasks

    // Status State
    @Published var systemStatus: SystemStatus = SystemStatus()

    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Clean Category
struct CleanCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    var isSelected: Bool
    var estimatedSize: Int64
    var paths: [String]

    static var defaultCategories: [CleanCategory] {
        [
            CleanCategory(
                name: "User Caches",
                icon: "folder.badge.minus",
                description: "Application caches in ~/Library/Caches",
                isSelected: true,
                estimatedSize: 0,
                paths: ["~/Library/Caches"]
            ),
            CleanCategory(
                name: "Browser Caches",
                icon: "globe",
                description: "Chrome, Safari, Firefox caches",
                isSelected: true,
                estimatedSize: 0,
                paths: [
                    "~/Library/Caches/Google/Chrome",
                    "~/Library/Caches/com.apple.Safari",
                    "~/Library/Caches/Firefox"
                ]
            ),
            CleanCategory(
                name: "Developer Tools",
                icon: "hammer",
                description: "Xcode, npm, CocoaPods, Gradle caches",
                isSelected: false,
                estimatedSize: 0,
                paths: [
                    "~/Library/Developer/Xcode/DerivedData",
                    "~/Library/Developer/Xcode/Archives",
                    "~/.npm/_cacache",
                    "~/Library/Caches/CocoaPods",
                    "~/.gradle/caches"
                ]
            ),
            CleanCategory(
                name: "System Logs",
                icon: "doc.text",
                description: "System and application logs",
                isSelected: true,
                estimatedSize: 0,
                paths: [
                    "~/Library/Logs",
                    "/var/log"
                ]
            ),
            CleanCategory(
                name: "App Caches",
                icon: "app.badge",
                description: "Spotify, Dropbox, Slack, etc.",
                isSelected: true,
                estimatedSize: 0,
                paths: [
                    "~/Library/Caches/com.spotify.client",
                    "~/Library/Caches/com.dropbox.DropboxMacUpdate",
                    "~/Library/Caches/com.tinyspeck.slackmacgap"
                ]
            ),
            CleanCategory(
                name: "Trash",
                icon: "trash",
                description: "Empty Trash",
                isSelected: false,
                estimatedSize: 0,
                paths: ["~/.Trash"]
            )
        ]
    }
}

// MARK: - Installed App
struct InstalledApp: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleId: String
    let path: String
    let size: Int64
    let lastUsed: Date?
    let icon: NSImage?

    var residualPaths: [ResidualPath]

    struct ResidualPath: Identifiable, Hashable {
        let id = UUID()
        let path: String
        let size: Int64
        let type: ResidualType
    }

    enum ResidualType: String {
        case applicationSupport = "Application Support"
        case caches = "Caches"
        case preferences = "Preferences"
        case logs = "Logs"
        case webkitStorage = "WebKit"
        case cookies = "Cookies"
        case plugins = "Plugins"
        case launchAgents = "Launch Agents"
        case other = "Other"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleId)
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.bundleId == rhs.bundleId
    }
}

// MARK: - Disk Item
struct DiskItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let isDirectory: Bool
    let modificationDate: Date?
    let childCount: Int?

    var ageIndicator: String? {
        guard let date = modificationDate else { return nil }
        let months = Calendar.current.dateComponents([.month], from: date, to: Date()).month ?? 0
        if months >= 12 {
            return ">\(months/12)y"
        } else if months >= 6 {
            return ">6mo"
        } else if months >= 3 {
            return ">3mo"
        }
        return nil
    }
}

// MARK: - Optimize Task
struct OptimizeTask: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let command: String
    var isCompleted: Bool = false
    var isRunning: Bool = false
    var requiresSudo: Bool

    static var defaultTasks: [OptimizeTask] {
        [
            OptimizeTask(
                name: "Rebuild Launch Services",
                icon: "arrow.triangle.2.circlepath",
                description: "Rebuild the Launch Services database",
                command: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user",
                requiresSudo: false
            ),
            OptimizeTask(
                name: "Rebuild Spotlight Index",
                icon: "magnifyingglass",
                description: "Reindex Spotlight for faster searches",
                command: "mdutil -E /",
                requiresSudo: true
            ),
            OptimizeTask(
                name: "Clear System Caches",
                icon: "xmark.bin",
                description: "Remove system-level cache files",
                command: "rm -rf /Library/Caches/*",
                requiresSudo: true
            ),
            OptimizeTask(
                name: "Reset Network Services",
                icon: "network",
                description: "Reset network preferences and configurations",
                command: "networksetup -setnetworkserviceenabled Wi-Fi off && networksetup -setnetworkserviceenabled Wi-Fi on",
                requiresSudo: true
            ),
            OptimizeTask(
                name: "Refresh Finder",
                icon: "folder",
                description: "Restart Finder to clear cached data",
                command: "killall Finder",
                requiresSudo: false
            ),
            OptimizeTask(
                name: "Refresh Dock",
                icon: "dock.rectangle",
                description: "Restart Dock to apply changes",
                command: "killall Dock",
                requiresSudo: false
            ),
            OptimizeTask(
                name: "Clear DNS Cache",
                icon: "globe",
                description: "Flush the DNS resolver cache",
                command: "dscacheutil -flushcache && killall -HUP mDNSResponder",
                requiresSudo: true
            ),
            OptimizeTask(
                name: "Clean Diagnostic Reports",
                icon: "stethoscope",
                description: "Remove crash logs and diagnostic data",
                command: "rm -rf ~/Library/Logs/DiagnosticReports/*",
                requiresSudo: false
            )
        ]
    }
}

// MARK: - System Status
struct SystemStatus {
    var healthScore: Int = 0

    // CPU
    var cpuUsage: Double = 0
    var cpuTemperature: Double = 0
    var loadAverage: (Double, Double, Double) = (0, 0, 0)

    // Memory
    var memoryUsed: Int64 = 0
    var memoryFree: Int64 = 0
    var memoryTotal: Int64 = 0
    var memoryPressure: Double = 0

    // Disk
    var diskUsed: Int64 = 0
    var diskFree: Int64 = 0
    var diskTotal: Int64 = 0
    var diskReadSpeed: Double = 0
    var diskWriteSpeed: Double = 0

    // Network
    var networkUpload: Double = 0
    var networkDownload: Double = 0
    var isProxyEnabled: Bool = false

    // Battery
    var batteryLevel: Int = 0
    var isCharging: Bool = false
    var batteryHealth: Int = 0
    var cycleCount: Int = 0
    var batteryTemperature: Double = 0
    var fanRPM: Int = 0

    // Top Processes
    var topProcesses: [ProcessInfo] = []

    struct ProcessInfo: Identifiable {
        let id = UUID()
        let name: String
        let pid: Int32
        let cpuUsage: Double
        let memoryUsage: Int64
    }

    var memoryPercentage: Double {
        guard memoryTotal > 0 else { return 0 }
        return Double(memoryUsed) / Double(memoryTotal)
    }

    var diskPercentage: Double {
        guard diskTotal > 0 else { return 0 }
        return Double(diskUsed) / Double(diskTotal)
    }

    var healthDescription: String {
        switch healthScore {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        case 20..<40: return "Poor"
        default: return "Critical"
        }
    }

    var healthColor: Color {
        switch healthScore {
        case 80...100: return .successGreen
        case 60..<80: return .terminalGreen
        case 40..<60: return .warningOrange
        default: return .errorRed
        }
    }
}

// MARK: - Whitelist
struct WhitelistItem: Identifiable, Codable {
    let id: UUID
    let path: String
    let addedDate: Date
    let reason: String?

    init(path: String, reason: String? = nil) {
        self.id = UUID()
        self.path = path
        self.addedDate = Date()
        self.reason = reason
    }
}

class WhitelistManager: ObservableObject {
    @Published var items: [WhitelistItem] = []

    private let storageKey = "DeepClean.Whitelist"

    init() {
        load()
    }

    func add(_ path: String, reason: String? = nil) {
        let item = WhitelistItem(path: path, reason: reason)
        items.append(item)
        save()
    }

    func remove(_ item: WhitelistItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func isWhitelisted(_ path: String) -> Bool {
        items.contains { path.hasPrefix($0.path) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode([WhitelistItem].self, from: data) {
            items = loaded
        }
    }
}
