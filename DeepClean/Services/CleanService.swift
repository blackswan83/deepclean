import Foundation
import AppKit

actor CleanService {
    static let shared = CleanService()

    private init() {}

    // MARK: - Scan for cleanable items
    func scanCategories(_ categories: [CleanCategory]) async -> [CleanCategory] {
        var updatedCategories = categories

        for (index, category) in categories.enumerated() {
            var totalSize: Int64 = 0

            for path in category.paths {
                let expandedPath = (path as NSString).expandingTildeInPath
                totalSize += await calculateDirectorySize(at: expandedPath)
            }

            updatedCategories[index].estimatedSize = totalSize
        }

        return updatedCategories
    }

    // MARK: - Calculate Directory Size
    private func calculateDirectorySize(at path: String) async -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        guard fileManager.fileExists(atPath: path) else { return 0 }

        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
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

    // MARK: - Clean Selected Categories
    func clean(
        categories: [CleanCategory],
        dryRun: Bool,
        whitelist: WhitelistManager,
        progress: @escaping (Double, String) -> Void
    ) async throws -> CleanResult {
        var totalFreed: Int64 = 0
        var filesDeleted = 0
        var errors: [String] = []

        let selectedCategories = categories.filter { $0.isSelected }
        let totalCategories = Double(selectedCategories.count)
        var currentCategory = 0.0

        for category in selectedCategories {
            progress(currentCategory / totalCategories, "Cleaning \(category.name)...")

            for path in category.paths {
                let expandedPath = (path as NSString).expandingTildeInPath

                // Check whitelist
                if whitelist.isWhitelisted(expandedPath) {
                    continue
                }

                do {
                    let result = try await cleanPath(expandedPath, dryRun: dryRun, whitelist: whitelist)
                    totalFreed += result.bytesFreed
                    filesDeleted += result.filesDeleted
                } catch {
                    errors.append("Failed to clean \(path): \(error.localizedDescription)")
                }
            }

            currentCategory += 1
        }

        progress(1.0, dryRun ? "Scan complete" : "Cleaning complete")

        return CleanResult(
            bytesFreed: totalFreed,
            filesDeleted: filesDeleted,
            errors: errors,
            wasDryRun: dryRun
        )
    }

    // MARK: - Clean Path
    private func cleanPath(_ path: String, dryRun: Bool, whitelist: WhitelistManager) async throws -> (bytesFreed: Int64, filesDeleted: Int) {
        let fileManager = FileManager.default
        var bytesFreed: Int64 = 0
        var filesDeleted = 0

        guard fileManager.fileExists(atPath: path) else {
            return (0, 0)
        }

        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: Array(resourceKeys),
            options: [],
            errorHandler: nil
        ) else {
            return (0, 0)
        }

        var pathsToDelete: [(URL, Int64)] = []

        for case let fileURL as URL in enumerator {
            // Check whitelist
            if whitelist.isWhitelisted(fileURL.path) {
                enumerator.skipDescendants()
                continue
            }

            do {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                if resourceValues.isDirectory == false {
                    let size = Int64(resourceValues.fileSize ?? 0)
                    pathsToDelete.append((fileURL, size))
                }
            } catch {
                continue
            }
        }

        for (url, size) in pathsToDelete {
            if !dryRun {
                do {
                    try fileManager.removeItem(at: url)
                    bytesFreed += size
                    filesDeleted += 1
                } catch {
                    // Skip files we can't delete
                    continue
                }
            } else {
                bytesFreed += size
                filesDeleted += 1
            }
        }

        return (bytesFreed, filesDeleted)
    }

    // MARK: - Empty Trash
    func emptyTrash(dryRun: Bool) async throws -> Int64 {
        let trashPath = NSHomeDirectory() + "/.Trash"
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: trashPath) else { return 0 }

        var totalSize: Int64 = 0

        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]

        if let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: trashPath),
            includingPropertiesForKeys: Array(resourceKeys),
            options: [],
            errorHandler: nil
        ) {
            for case let fileURL as URL in enumerator {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                    if resourceValues.isDirectory == false {
                        totalSize += Int64(resourceValues.fileSize ?? 0)
                    }
                } catch {
                    continue
                }
            }
        }

        if !dryRun {
            // Use NSWorkspace to properly empty trash
            if let url = URL(string: "file://\(trashPath)") {
                try? fileManager.removeItem(at: url)
            }
        }

        return totalSize
    }

    // MARK: - Browser Specific Cleanup
    func cleanBrowserCaches(dryRun: Bool) async throws -> Int64 {
        let browsers: [(name: String, paths: [String])] = [
            ("Chrome", [
                "~/Library/Caches/Google/Chrome",
                "~/Library/Application Support/Google/Chrome/Default/Cache",
                "~/Library/Application Support/Google/Chrome/Default/Code Cache"
            ]),
            ("Safari", [
                "~/Library/Caches/com.apple.Safari",
                "~/Library/Caches/com.apple.Safari.SafeBrowsing"
            ]),
            ("Firefox", [
                "~/Library/Caches/Firefox",
                "~/Library/Caches/org.mozilla.firefox"
            ]),
            ("Edge", [
                "~/Library/Caches/Microsoft Edge"
            ]),
            ("Brave", [
                "~/Library/Caches/BraveSoftware/Brave-Browser"
            ])
        ]

        var totalFreed: Int64 = 0

        for browser in browsers {
            for path in browser.paths {
                let expandedPath = (path as NSString).expandingTildeInPath
                totalFreed += await calculateDirectorySize(at: expandedPath)

                if !dryRun {
                    try? FileManager.default.removeItem(atPath: expandedPath)
                }
            }
        }

        return totalFreed
    }

    // MARK: - Developer Tools Cleanup
    func cleanDeveloperCaches(dryRun: Bool) async throws -> Int64 {
        let devPaths = [
            // Xcode
            "~/Library/Developer/Xcode/DerivedData",
            "~/Library/Developer/Xcode/Archives",
            "~/Library/Developer/Xcode/iOS DeviceSupport",
            "~/Library/Developer/CoreSimulator/Caches",

            // Node.js / npm
            "~/.npm/_cacache",
            "~/.npm/_logs",
            "~/Library/Caches/Yarn",

            // CocoaPods
            "~/Library/Caches/CocoaPods",

            // Gradle
            "~/.gradle/caches",
            "~/.gradle/wrapper",

            // Maven
            "~/.m2/repository",

            // Rust
            "~/.cargo/registry/cache",

            // Go
            "~/go/pkg/mod/cache"
        ]

        var totalFreed: Int64 = 0

        for path in devPaths {
            let expandedPath = (path as NSString).expandingTildeInPath
            totalFreed += await calculateDirectorySize(at: expandedPath)

            if !dryRun {
                try? FileManager.default.removeItem(atPath: expandedPath)
            }
        }

        return totalFreed
    }
}

// MARK: - Clean Result
struct CleanResult {
    let bytesFreed: Int64
    let filesDeleted: Int
    let errors: [String]
    let wasDryRun: Bool

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: bytesFreed, countStyle: .file)
    }
}
