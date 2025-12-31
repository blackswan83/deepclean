import Foundation
import AppKit

actor UninstallService {
    static let shared = UninstallService()

    private init() {}

    // MARK: - Residual Search Paths
    private let residualSearchPaths: [(path: String, type: InstalledApp.ResidualType)] = [
        ("~/Library/Application Support", .applicationSupport),
        ("~/Library/Caches", .caches),
        ("~/Library/Preferences", .preferences),
        ("~/Library/Logs", .logs),
        ("~/Library/WebKit", .webkitStorage),
        ("~/Library/Cookies", .cookies),
        ("~/Library/Application Scripts", .plugins),
        ("~/Library/Containers", .applicationSupport),
        ("~/Library/Group Containers", .applicationSupport),
        ("~/Library/LaunchAgents", .launchAgents),
        ("/Library/LaunchAgents", .launchAgents),
        ("/Library/LaunchDaemons", .launchAgents),
        ("~/Library/Saved Application State", .other)
    ]

    // MARK: - Scan Installed Applications
    func scanInstalledApps() async -> [InstalledApp] {
        let fileManager = FileManager.default
        let applicationsPath = "/Applications"

        var apps: [InstalledApp] = []

        guard let contents = try? fileManager.contentsOfDirectory(atPath: applicationsPath) else {
            return apps
        }

        for item in contents where item.hasSuffix(".app") {
            let appPath = "\(applicationsPath)/\(item)"

            guard let bundle = Bundle(path: appPath),
                  let bundleId = bundle.bundleIdentifier else {
                continue
            }

            let name = item.replacingOccurrences(of: ".app", with: "")
            let size = calculateAppSize(at: appPath)
            let lastUsed = getLastUsedDate(for: appPath)
            let icon = NSWorkspace.shared.icon(forFile: appPath)
            let residuals = await findResidualFiles(for: bundleId, appName: name)

            let app = InstalledApp(
                name: name,
                bundleId: bundleId,
                path: appPath,
                size: size,
                lastUsed: lastUsed,
                icon: icon,
                residualPaths: residuals
            )

            apps.append(app)
        }

        // Also scan user Applications folder
        let userAppsPath = NSHomeDirectory() + "/Applications"
        if let userContents = try? fileManager.contentsOfDirectory(atPath: userAppsPath) {
            for item in userContents where item.hasSuffix(".app") {
                let appPath = "\(userAppsPath)/\(item)"

                guard let bundle = Bundle(path: appPath),
                      let bundleId = bundle.bundleIdentifier else {
                    continue
                }

                let name = item.replacingOccurrences(of: ".app", with: "")
                let size = calculateAppSize(at: appPath)
                let lastUsed = getLastUsedDate(for: appPath)
                let icon = NSWorkspace.shared.icon(forFile: appPath)
                let residuals = await findResidualFiles(for: bundleId, appName: name)

                let app = InstalledApp(
                    name: name,
                    bundleId: bundleId,
                    path: appPath,
                    size: size,
                    lastUsed: lastUsed,
                    icon: icon,
                    residualPaths: residuals
                )

                apps.append(app)
            }
        }

        // Sort by size descending
        return apps.sorted { $0.size > $1.size }
    }

    // MARK: - Calculate App Size
    private nonisolated func calculateAppSize(at path: String) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else { return 0 }

        while let fileURL = enumerator.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                if resourceValues.isDirectory == false {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }

        return totalSize
    }

    // MARK: - Get Last Used Date
    private func getLastUsedDate(for path: String) -> Date? {
        let fileManager = FileManager.default
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            return attributes[.modificationDate] as? Date
        } catch {
            return nil
        }
    }

    // MARK: - Find Residual Files
    private func findResidualFiles(for bundleId: String, appName: String) async -> [InstalledApp.ResidualPath] {
        var residuals: [InstalledApp.ResidualPath] = []
        let fileManager = FileManager.default

        // Generate search patterns
        let patterns = generateSearchPatterns(bundleId: bundleId, appName: appName)

        for (searchPath, type) in residualSearchPaths {
            let expandedPath = (searchPath as NSString).expandingTildeInPath

            guard fileManager.fileExists(atPath: expandedPath) else { continue }

            do {
                let contents = try fileManager.contentsOfDirectory(atPath: expandedPath)

                for item in contents {
                    let itemLower = item.lowercased()
                    let matchesPattern = patterns.contains { pattern in
                        itemLower.contains(pattern.lowercased())
                    }

                    if matchesPattern {
                        let fullPath = "\(expandedPath)/\(item)"
                        let size = calculateAppSize(at: fullPath)

                        let residual = InstalledApp.ResidualPath(
                            path: fullPath,
                            size: size,
                            type: type
                        )
                        residuals.append(residual)
                    }
                }
            } catch {
                continue
            }
        }

        return residuals
    }

    // MARK: - Generate Search Patterns
    private func generateSearchPatterns(bundleId: String, appName: String) -> [String] {
        var patterns: [String] = []

        // Bundle ID patterns
        patterns.append(bundleId)

        // Components of bundle ID
        let components = bundleId.split(separator: ".").map(String.init)
        if components.count >= 2 {
            patterns.append(components.suffix(2).joined(separator: "."))
        }
        if let last = components.last {
            patterns.append(last)
        }

        // App name patterns
        patterns.append(appName)
        patterns.append(appName.replacingOccurrences(of: " ", with: ""))
        patterns.append(appName.replacingOccurrences(of: " ", with: "-"))
        patterns.append(appName.lowercased())

        return patterns
    }

    // MARK: - Uninstall Application
    func uninstall(app: InstalledApp, includeResiduals: Bool = true) async throws -> UninstallResult {
        let fileManager = FileManager.default
        var bytesFreed: Int64 = 0
        var filesDeleted = 0
        var errors: [String] = []

        // Move app to trash
        do {
            try fileManager.trashItem(at: URL(fileURLWithPath: app.path), resultingItemURL: nil)
            bytesFreed += app.size
            filesDeleted += 1
        } catch {
            errors.append("Failed to remove app: \(error.localizedDescription)")
        }

        // Remove residual files if requested
        if includeResiduals {
            for residual in app.residualPaths {
                do {
                    try fileManager.trashItem(at: URL(fileURLWithPath: residual.path), resultingItemURL: nil)
                    bytesFreed += residual.size
                    filesDeleted += 1
                } catch {
                    errors.append("Failed to remove \(residual.path): \(error.localizedDescription)")
                }
            }
        }

        return UninstallResult(
            appName: app.name,
            bytesFreed: bytesFreed,
            filesDeleted: filesDeleted,
            residualsRemoved: includeResiduals ? app.residualPaths.count : 0,
            errors: errors
        )
    }

    // MARK: - Batch Uninstall
    func batchUninstall(apps: [InstalledApp], includeResiduals: Bool = true) async throws -> [UninstallResult] {
        var results: [UninstallResult] = []

        for app in apps {
            let result = try await uninstall(app: app, includeResiduals: includeResiduals)
            results.append(result)
        }

        return results
    }
}

// MARK: - Uninstall Result
struct UninstallResult {
    let appName: String
    let bytesFreed: Int64
    let filesDeleted: Int
    let residualsRemoved: Int
    let errors: [String]

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: bytesFreed, countStyle: .file)
    }

    var success: Bool {
        errors.isEmpty
    }
}
