import Foundation
import IOKit.hid

let batteryUsagePage = 0x06
let batteryUsage = 0x20

struct Reading {
    let name: String
    let percent: Int
}

var sawLockedDevice = false

func batteryPercent(for device: IOHIDDevice) -> Int? {
    let criteria: [String: Any] = [
        kIOHIDElementUsagePageKey: batteryUsagePage,
        kIOHIDElementUsageKey: batteryUsage,
    ]
    guard let elements = IOHIDDeviceCopyMatchingElements(device, criteria as CFDictionary, 0) as? [IOHIDElement],
          let element = elements.first else { return nil }

    let reportID = IOHIDElementGetReportID(element)
    guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
        sawLockedDevice = true
        return nil
    }
    defer { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }

    var buffer = [UInt8](repeating: 0, count: 8)
    var length = buffer.count
    guard IOHIDDeviceGetReport(device, kIOHIDReportTypeInput, CFIndex(reportID), &buffer, &length) == kIOReturnSuccess, length > 0 else { return nil }

    let payload = (buffer[0] == UInt8(reportID) && length > 1) ? Int(buffer[1]) : Int(buffer[0])
    return (0...100).contains(payload) ? payload : nil
}

func readings(matching filter: String?) -> [Reading] {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(manager, nil)
    guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
          let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }

    var seen = Set<String>()
    var result: [Reading] = []
    for device in devices {
        guard let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String else { continue }
        if let filter, !name.localizedCaseInsensitiveContains(filter) { continue }
        guard !seen.contains(name), let percent = batteryPercent(for: device) else { continue }
        seen.insert(name)
        result.append(Reading(name: name, percent: percent))
    }
    return result.sorted { $0.name < $1.name }
}

var filter: String? = "Keychron"
var jsonOutput = false
var quiet = false
var args = Array(CommandLine.arguments.dropFirst())
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--all": filter = nil
    case "--json": jsonOutput = true
    case "--quiet", "-q": quiet = true
    case "--match": filter = args.isEmpty ? filter : args.removeFirst()
    case "--help", "-h":
        print("""
        keyboard-battery — read the battery level of HID keyboards that report one

          --match <text>  device name substring (default: Keychron)
          --all           every device that exposes a battery element
          --json          machine-readable output
          --quiet         print just the number
        """)
        exit(0)
    default:
        FileHandle.standardError.write("unknown option: \(arg)\n".data(using: .utf8)!)
        exit(64)
    }
}

let found = readings(matching: filter)
guard !found.isEmpty else {
    if jsonOutput {
        print("[]")
    } else if !quiet {
        let message = sawLockedDevice
            ? "cannot open the keyboard: grant Input Monitoring to this program in System Settings > Privacy & Security\n"
            : "no matching device with a battery report (is it connected over Bluetooth?)\n"
        FileHandle.standardError.write(message.data(using: .utf8)!)
    }
    exit(sawLockedDevice ? 3 : 1)
}

if jsonOutput {
    let payload = found.map { ["name": $0.name, "percent": $0.percent] as [String: Any] }
    let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    print(String(data: data, encoding: .utf8)!)
} else if quiet {
    found.forEach { print($0.percent) }
} else {
    found.forEach { print("\($0.name): \($0.percent)%") }
}
