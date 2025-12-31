import Foundation
import IOKit
import IOKit.ps

actor StatusService {
    static let shared = StatusService()

    private init() {}

    // MARK: - Collect All Metrics
    func collectMetrics() async -> SystemStatus {
        var status = SystemStatus()

        // CPU
        let cpuInfo = getCPUUsage()
        status.cpuUsage = cpuInfo.usage
        status.loadAverage = getLoadAverage()

        // Memory
        let memInfo = getMemoryInfo()
        status.memoryUsed = memInfo.used
        status.memoryFree = memInfo.free
        status.memoryTotal = memInfo.total
        status.memoryPressure = memInfo.pressure

        // Disk
        let diskInfo = await getDiskInfo()
        status.diskUsed = diskInfo.used
        status.diskFree = diskInfo.free
        status.diskTotal = diskInfo.total

        // Battery
        let batteryInfo = getBatteryInfo()
        status.batteryLevel = batteryInfo.level
        status.isCharging = batteryInfo.isCharging
        status.batteryHealth = batteryInfo.health
        status.cycleCount = batteryInfo.cycleCount

        // Top Processes
        status.topProcesses = getTopProcesses()

        // Calculate health score
        status.healthScore = calculateHealthScore(status)

        return status
    }

    // MARK: - CPU Usage
    private func getCPUUsage() -> (usage: Double, perCore: [Double]) {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0

        let err = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCpus,
            &cpuInfo,
            &numCpuInfo
        )

        guard err == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            return (0, [])
        }

        var totalUsage: Double = 0
        var perCore: [Double] = []

        for i in 0..<Int(numCpus) {
            let offset = Int32(CPU_STATE_MAX) * Int32(i)
            let user = Double(cpuInfo[Int(offset + CPU_STATE_USER)])
            let system = Double(cpuInfo[Int(offset + CPU_STATE_SYSTEM)])
            let idle = Double(cpuInfo[Int(offset + CPU_STATE_IDLE)])
            let nice = Double(cpuInfo[Int(offset + CPU_STATE_NICE)])

            let total = user + system + idle + nice
            let usage = total > 0 ? ((user + system + nice) / total) * 100 : 0
            perCore.append(usage)
            totalUsage += usage
        }

        let avgUsage = numCpus > 0 ? totalUsage / Double(numCpus) : 0

        // Deallocate
        let cpuInfoSize = vm_size_t(MemoryLayout<integer_t>.stride * Int(numCpuInfo))
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), cpuInfoSize)

        return (avgUsage, perCore)
    }

    // MARK: - Load Average
    private func getLoadAverage() -> (Double, Double, Double) {
        var loadAvg: [Double] = [0, 0, 0]
        getloadavg(&loadAvg, 3)
        return (loadAvg[0], loadAvg[1], loadAvg[2])
    }

    // MARK: - Memory Info
    private func getMemoryInfo() -> (used: Int64, free: Int64, total: Int64, pressure: Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (0, 0, 0, 0)
        }

        let pageSize = Int64(vm_kernel_page_size)
        let active = Int64(stats.active_count) * pageSize
        let wired = Int64(stats.wire_count) * pageSize
        let compressed = Int64(stats.compressor_page_count) * pageSize

        let total = ProcessInfo.processInfo.physicalMemory
        let used = active + wired + compressed
        let actualFree = Int64(total) - used

        // Memory pressure (simplified)
        let pressure = Double(used) / Double(total)

        return (used, actualFree, Int64(total), pressure)
    }

    // MARK: - Disk Info
    private func getDiskInfo() async -> (used: Int64, free: Int64, total: Int64) {
        let fileManager = FileManager.default

        do {
            let attrs = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            let total = attrs[.systemSize] as? Int64 ?? 0
            let free = attrs[.systemFreeSize] as? Int64 ?? 0
            let used = total - free

            return (used, free, total)
        } catch {
            return (0, 0, 0)
        }
    }

    // MARK: - Battery Info
    private func getBatteryInfo() -> (level: Int, isCharging: Bool, health: Int, cycleCount: Int, temperature: Double) {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] ?? []

        guard let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            return (0, false, 100, 0, 0)
        }

        let level = info[kIOPSCurrentCapacityKey] as? Int ?? 0
        let isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
        let health = info[kIOPSBatteryHealthKey] as? Int ?? 100
        // kIOPSCycleCountKey is not available in all macOS versions
        let cycleCount = info["BatteryCycleCount"] as? Int ?? 0

        return (level, isCharging, health, cycleCount, 0)
    }

    // MARK: - Top Processes
    private func getTopProcesses(limit: Int = 5) -> [SystemStatus.ProcessInfo] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-Aceo", "pid,pcpu,rss,comm", "-r"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            var processes: [SystemStatus.ProcessInfo] = []

            let lines = output.split(separator: "\n").dropFirst() // Skip header
            for line in lines.prefix(limit) {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 4 else { continue }

                let pid = Int32(parts[0]) ?? 0
                let cpu = Double(parts[1]) ?? 0
                let memory = Int64(parts[2]) ?? 0 // In KB
                let name = String(parts[3...].joined(separator: " "))

                processes.append(SystemStatus.ProcessInfo(
                    name: name,
                    pid: pid,
                    cpuUsage: cpu,
                    memoryUsage: memory * 1024 // Convert to bytes
                ))
            }

            return processes
        } catch {
            return []
        }
    }

    // MARK: - Calculate Health Score
    private func calculateHealthScore(_ status: SystemStatus) -> Int {
        var score = 100

        // CPU penalty (high usage = lower score)
        if status.cpuUsage > 80 {
            score -= 20
        } else if status.cpuUsage > 60 {
            score -= 10
        }

        // Memory penalty
        let memoryPercent = status.memoryPercentage * 100
        if memoryPercent > 90 {
            score -= 25
        } else if memoryPercent > 75 {
            score -= 15
        } else if memoryPercent > 60 {
            score -= 5
        }

        // Disk penalty
        let diskPercent = status.diskPercentage * 100
        if diskPercent > 95 {
            score -= 30
        } else if diskPercent > 90 {
            score -= 20
        } else if diskPercent > 80 {
            score -= 10
        }

        // Battery penalty
        if status.batteryLevel < 20 && !status.isCharging {
            score -= 10
        }

        return max(0, min(100, score))
    }

    // MARK: - Network Info
    func getNetworkInfo() async -> (upload: Double, download: Double, isProxyEnabled: Bool) {
        // Simplified network info - in production would use Network.framework
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/networksetup")
        process.arguments = ["-getwebproxy", "Wi-Fi"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            let isProxyEnabled = output.contains("Enabled: Yes")

            return (0, 0, isProxyEnabled)
        } catch {
            return (0, 0, false)
        }
    }
}
