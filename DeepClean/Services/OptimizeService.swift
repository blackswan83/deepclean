import Foundation
import AppKit

actor OptimizeService {
    static let shared = OptimizeService()

    private init() {}

    // MARK: - Run Optimization Task
    func runTask(_ task: OptimizeTask) async throws -> OptimizeResult {
        let startTime = Date()

        if task.requiresSudo {
            return try await runWithPrivileges(task)
        } else {
            return try await runDirectly(task)
        }
    }

    // MARK: - Run Without Privileges
    private func runDirectly(_ task: OptimizeTask) async throws -> OptimizeResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", task.command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""

            return OptimizeResult(
                taskName: task.name,
                success: process.terminationStatus == 0,
                output: output,
                error: error.isEmpty ? nil : error,
                duration: Date().timeIntervalSince(Date())
            )
        } catch {
            throw OptimizeError.executionFailed(error.localizedDescription)
        }
    }

    // MARK: - Run With Privileges
    private func runWithPrivileges(_ task: OptimizeTask) async throws -> OptimizeResult {
        // Use AppleScript to request admin privileges
        let script = """
        do shell script "\(task.command.replacingOccurrences(of: "\"", with: "\\\""))" with administrator privileges
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let output = scriptObject.executeAndReturnError(&error)

            if let error = error {
                let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                return OptimizeResult(
                    taskName: task.name,
                    success: false,
                    output: "",
                    error: errorMessage,
                    duration: 0
                )
            }

            return OptimizeResult(
                taskName: task.name,
                success: true,
                output: output.stringValue ?? "",
                error: nil,
                duration: 0
            )
        }

        throw OptimizeError.scriptCreationFailed
    }

    // MARK: - Rebuild Launch Services Database
    func rebuildLaunchServices() async throws -> OptimizeResult {
        let command = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return OptimizeResult(
            taskName: "Rebuild Launch Services",
            success: process.terminationStatus == 0,
            output: output,
            error: nil,
            duration: 0
        )
    }

    // MARK: - Rebuild Spotlight Index
    func rebuildSpotlight() async throws -> OptimizeResult {
        let script = """
        do shell script "mdutil -E /" with administrator privileges
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let output = scriptObject.executeAndReturnError(&error)

            if let error = error {
                let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                return OptimizeResult(
                    taskName: "Rebuild Spotlight Index",
                    success: false,
                    output: "",
                    error: errorMessage,
                    duration: 0
                )
            }

            return OptimizeResult(
                taskName: "Rebuild Spotlight Index",
                success: true,
                output: output.stringValue ?? "Spotlight reindexing started",
                error: nil,
                duration: 0
            )
        }

        throw OptimizeError.scriptCreationFailed
    }

    // MARK: - Flush DNS Cache
    func flushDNS() async throws -> OptimizeResult {
        let script = """
        do shell script "dscacheutil -flushcache && killall -HUP mDNSResponder" with administrator privileges
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let output = scriptObject.executeAndReturnError(&error)

            if let error = error {
                let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                return OptimizeResult(
                    taskName: "Flush DNS Cache",
                    success: false,
                    output: "",
                    error: errorMessage,
                    duration: 0
                )
            }

            return OptimizeResult(
                taskName: "Flush DNS Cache",
                success: true,
                output: output.stringValue ?? "DNS cache flushed",
                error: nil,
                duration: 0
            )
        }

        throw OptimizeError.scriptCreationFailed
    }

    // MARK: - Restart Finder
    func restartFinder() async throws -> OptimizeResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]

        try process.run()
        process.waitUntilExit()

        return OptimizeResult(
            taskName: "Restart Finder",
            success: process.terminationStatus == 0,
            output: "Finder restarted",
            error: nil,
            duration: 0
        )
    }

    // MARK: - Restart Dock
    func restartDock() async throws -> OptimizeResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]

        try process.run()
        process.waitUntilExit()

        return OptimizeResult(
            taskName: "Restart Dock",
            success: process.terminationStatus == 0,
            output: "Dock restarted",
            error: nil,
            duration: 0
        )
    }

    // MARK: - Clean Diagnostic Reports
    func cleanDiagnosticReports() async throws -> OptimizeResult {
        let paths = [
            "\(NSHomeDirectory())/Library/Logs/DiagnosticReports",
            "/Library/Logs/DiagnosticReports"
        ]

        let fileManager = FileManager.default
        var deletedCount = 0

        for path in paths {
            guard fileManager.fileExists(atPath: path) else { continue }

            do {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                for item in contents {
                    let itemPath = "\(path)/\(item)"
                    try? fileManager.removeItem(atPath: itemPath)
                    deletedCount += 1
                }
            } catch {
                continue
            }
        }

        return OptimizeResult(
            taskName: "Clean Diagnostic Reports",
            success: true,
            output: "Removed \(deletedCount) diagnostic reports",
            error: nil,
            duration: 0
        )
    }

    // MARK: - Purge Memory
    func purgeMemory() async throws -> OptimizeResult {
        let script = """
        do shell script "purge" with administrator privileges
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let output = scriptObject.executeAndReturnError(&error)

            if let error = error {
                let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                return OptimizeResult(
                    taskName: "Purge Memory",
                    success: false,
                    output: "",
                    error: errorMessage,
                    duration: 0
                )
            }

            return OptimizeResult(
                taskName: "Purge Memory",
                success: true,
                output: output.stringValue ?? "Memory purged",
                error: nil,
                duration: 0
            )
        }

        throw OptimizeError.scriptCreationFailed
    }

    // MARK: - Run All Tasks
    func runAllTasks(_ tasks: [OptimizeTask], progress: @escaping (Double, String) -> Void) async -> [OptimizeResult] {
        var results: [OptimizeResult] = []
        let total = Double(tasks.count)

        for (index, task) in tasks.enumerated() {
            progress(Double(index) / total, "Running \(task.name)...")

            do {
                let result = try await runTask(task)
                results.append(result)
            } catch {
                results.append(OptimizeResult(
                    taskName: task.name,
                    success: false,
                    output: "",
                    error: error.localizedDescription,
                    duration: 0
                ))
            }
        }

        progress(1.0, "Optimization complete")
        return results
    }
}

// MARK: - Optimize Result
struct OptimizeResult: Identifiable {
    let id = UUID()
    let taskName: String
    let success: Bool
    let output: String
    let error: String?
    let duration: TimeInterval
}

// MARK: - Optimize Error
enum OptimizeError: Error, LocalizedError {
    case executionFailed(String)
    case scriptCreationFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .scriptCreationFailed:
            return "Failed to create AppleScript"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}
