import Foundation
import IOKit.ps
import MachO

public final class SystemMonitorHelper: @unchecked Sendable {
    public static let shared = SystemMonitorHelper()
    
    private var previousCpuInfo: processor_info_array_t?
    private var previousCpuInfoCount: mach_msg_type_number_t = 0
    private let cpuInfoLock = NSLock()
    
    private init() {}
    
    public func getBatteryInfo() -> (percentage: Int, isCharging: Bool, isFull: Bool) {
        let snapshot = IOPSCopyPowerSourcesInfo()
        guard let rawSnapshot = snapshot else { return (100, false, true) }
        let info = rawSnapshot.takeRetainedValue()
        let sourcesList = IOPSCopyPowerSourcesList(info)
        guard let rawSourcesList = sourcesList else { return (100, false, true) }
        let list = rawSourcesList.takeRetainedValue() as [CFTypeRef]
        
        for source in list {
            if let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] {
                let capacity = description[kIOPSCurrentCapacityKey] as? Int ?? 100
                let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
                let isCharged = description[kIOPSIsChargedKey] as? Bool ?? (capacity >= 100)
                return (capacity, isCharging, isCharged)
            }
        }
        return (100, false, true)
    }
    
    public func getBatteryPercentage() -> Int {
        return getBatteryInfo().percentage
    }
    
    public func getCPUUsage() -> Double {
        var numCPUs: UInt32 = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0
        
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &processorInfo,
            &processorInfoCount
        )
        
        guard result == KERN_SUCCESS, let cpuInfo = processorInfo else {
            return 0.0
        }
        
        cpuInfoLock.lock()
        defer { cpuInfoLock.unlock() }
        
        guard let prevInfo = previousCpuInfo else {
            previousCpuInfo = cpuInfo
            previousCpuInfoCount = processorInfoCount
            return 1.5 // Initial baseline
        }
        
        var totalUsage: Double = 0.0
        let numCPUsInt = Int(numCPUs)
        
        for i in 0..<numCPUsInt {
            let offset = i * Int(CPU_STATE_MAX)
            let user = Double(cpuInfo[offset + Int(CPU_STATE_USER)] - prevInfo[offset + Int(CPU_STATE_USER)])
            let system = Double(cpuInfo[offset + Int(CPU_STATE_SYSTEM)] - prevInfo[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Double(cpuInfo[offset + Int(CPU_STATE_IDLE)] - prevInfo[offset + Int(CPU_STATE_IDLE)])
            let nice = Double(cpuInfo[offset + Int(CPU_STATE_NICE)] - prevInfo[offset + Int(CPU_STATE_NICE)])
            
            let total = user + system + idle + nice
            if total > 0 {
                totalUsage += (user + system + nice) / total
            }
        }
        
        // Deallocate previous info memory
        let prevSize = MemoryLayout<integer_t>.size * Int(previousCpuInfoCount)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), vm_size_t(prevSize))
        
        previousCpuInfo = cpuInfo
        previousCpuInfoCount = processorInfoCount
        
        let finalUsage = (totalUsage / Double(numCPUsInt)) * 100.0
        return Double(String(format: "%.1f", finalUsage)) ?? finalUsage
    }
    
    public func getRAMUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return 0.0
        }
        
        let pageSize = Double(getpagesize())
        let active = Double(stats.active_count) * pageSize
        let wire = Double(stats.wire_count) * pageSize
        
        let usedMemory = active + wire
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        
        let usagePercentage = (usedMemory / totalMemory) * 100.0
        return Double(String(format: "%.1f", usagePercentage)) ?? usagePercentage
    }
}
