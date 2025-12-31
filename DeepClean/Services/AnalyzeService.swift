import Foundation
import AppKit

actor AnalyzeService {
    static let shared = AnalyzeService()

    private init() {}

    // MARK: - Scan Directory
    func scanDirectory(at path: String) async -> [DiskItem] {
        let fileManager = FileManager.default
        var items: [DiskItem] = []

        let expandedPath = (path as NSString).expandingTildeInPath

        guard let contents = try? fileManager.contentsOfDirectory(atPath: expandedPath) else {
            return items
        }

        for item in contents {
            // Skip hidden files by default
            if item.hasPrefix(".") { continue }

            let fullPath = "\(expandedPath)/\(item)"

            do {
                let attributes = try fileManager.attributesOfItem(atPath: fullPath)
                let isDirectory = attributes[.type] as? FileAttributeType == .typeDirectory
                let modDate = attributes[.modificationDate] as? Date

                let size: Int64
                let childCount: Int?

                if isDirectory {
                    size = await calculateDirectorySize(at: fullPath)
                    childCount = try? fileManager.contentsOfDirectory(atPath: fullPath).count
                } else {
                    size = (attributes[.size] as? Int64) ?? 0
                    childCount = nil
                }

                let diskItem = DiskItem(
                    name: item,
                    path: fullPath,
                    size: size,
                    isDirectory: isDirectory,
                    modificationDate: modDate,
                    childCount: childCount
                )

                items.append(diskItem)
            } catch {
                continue
            }
        }

        // Sort by size descending
        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Scan Home Directory Overview
    func scanHomeOverview() async -> [DiskItem] {
        let homeDir = NSHomeDirectory()
        let keyFolders = [
            "Desktop",
            "Documents",
            "Downloads",
            "Movies",
            "Music",
            "Pictures",
            "Library",
            "Applications"
        ]

        var items: [DiskItem] = []
        let fileManager = FileManager.default

        for folder in keyFolders {
            let path = "\(homeDir)/\(folder)"

            guard fileManager.fileExists(atPath: path) else { continue }

            let size = await calculateDirectorySize(at: path)
            let childCount = try? fileManager.contentsOfDirectory(atPath: path).count
            let attributes = try? fileManager.attributesOfItem(atPath: path)
            let modDate = attributes?[.modificationDate] as? Date

            let item = DiskItem(
                name: folder,
                path: path,
                size: size,
                isDirectory: true,
                modificationDate: modDate,
                childCount: childCount
            )

            items.append(item)
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Scan Root Overview
    func scanRootOverview() async -> [DiskItem] {
        var items: [DiskItem] = []
        let fileManager = FileManager.default

        // Home directory
        let homeSize = await calculateDirectorySize(at: NSHomeDirectory())
        items.append(DiskItem(
            name: "Home (~)",
            path: NSHomeDirectory(),
            size: homeSize,
            isDirectory: true,
            modificationDate: nil,
            childCount: nil
        ))

        // Applications
        let appsPath = "/Applications"
        if fileManager.fileExists(atPath: appsPath) {
            let appsSize = await calculateDirectorySize(at: appsPath)
            items.append(DiskItem(
                name: "Applications",
                path: appsPath,
                size: appsSize,
                isDirectory: true,
                modificationDate: nil,
                childCount: nil
            ))
        }

        // Library
        let libPath = "/Library"
        if fileManager.fileExists(atPath: libPath) {
            let libSize = await calculateDirectorySize(at: libPath)
            items.append(DiskItem(
                name: "System Library",
                path: libPath,
                size: libSize,
                isDirectory: true,
                modificationDate: nil,
                childCount: nil
            ))
        }

        // Volumes
        let volumesPath = "/Volumes"
        if fileManager.fileExists(atPath: volumesPath) {
            if let volumes = try? fileManager.contentsOfDirectory(atPath: volumesPath) {
                for volume in volumes where !volume.hasPrefix(".") {
                    let volumePath = "\(volumesPath)/\(volume)"
                    if let attrs = try? fileManager.attributesOfFileSystem(forPath: volumePath) {
                        let totalSize = attrs[.systemSize] as? Int64 ?? 0
                        let freeSize = attrs[.systemFreeSize] as? Int64 ?? 0
                        let usedSize = totalSize - freeSize

                        items.append(DiskItem(
                            name: volume,
                            path: volumePath,
                            size: usedSize,
                            isDirectory: true,
                            modificationDate: nil,
                            childCount: nil
                        ))
                    }
                }
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Find Large Files
    func findLargeFiles(in path: String, minSize: Int64 = 100_000_000) async -> [DiskItem] {
        let fileManager = FileManager.default
        var largeFiles: [DiskItem] = []

        let expandedPath = (path as NSString).expandingTildeInPath

        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: expandedPath),
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else { return [] }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)

                guard resourceValues.isDirectory == false else { continue }

                let size = Int64(resourceValues.fileSize ?? 0)
                guard size >= minSize else { continue }

                let item = DiskItem(
                    name: fileURL.lastPathComponent,
                    path: fileURL.path,
                    size: size,
                    isDirectory: false,
                    modificationDate: resourceValues.contentModificationDate,
                    childCount: nil
                )

                largeFiles.append(item)
            } catch {
                continue
            }
        }

        return largeFiles.sorted { $0.size > $1.size }
    }

    // MARK: - Find Old Files
    func findOldFiles(in path: String, olderThan months: Int = 6) async -> [DiskItem] {
        let fileManager = FileManager.default
        var oldFiles: [DiskItem] = []

        let expandedPath = (path as NSString).expandingTildeInPath
        let cutoffDate = Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()

        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: expandedPath),
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else { return [] }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)

                guard resourceValues.isDirectory == false else { continue }

                guard let modDate = resourceValues.contentModificationDate,
                      modDate < cutoffDate else { continue }

                let size = Int64(resourceValues.fileSize ?? 0)

                let item = DiskItem(
                    name: fileURL.lastPathComponent,
                    path: fileURL.path,
                    size: size,
                    isDirectory: false,
                    modificationDate: modDate,
                    childCount: nil
                )

                oldFiles.append(item)
            } catch {
                continue
            }
        }

        return oldFiles.sorted { $0.size > $1.size }
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

    // MARK: - Get Disk Usage Stats
    func getDiskUsage() async -> (total: Int64, used: Int64, free: Int64) {
        let fileManager = FileManager.default

        do {
            let attrs = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            let total = attrs[.systemSize] as? Int64 ?? 0
            let free = attrs[.systemFreeSize] as? Int64 ?? 0
            let used = total - free

            return (total, used, free)
        } catch {
            return (0, 0, 0)
        }
    }

    // MARK: - Delete Item
    func deleteItem(at path: String, moveToTrash: Bool = true) async throws {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)

        if moveToTrash {
            try fileManager.trashItem(at: url, resultingItemURL: nil)
        } else {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - Open in Finder
    func revealInFinder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Open Item
    func openItem(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
}
