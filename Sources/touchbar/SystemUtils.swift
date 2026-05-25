import Foundation
import AppKit
import ImageIO
import IOKit.hid

public struct SystemUtils {
    // Dynamic function pointer types for private IOHIDEventSystem APIs
    private typealias IOHIDEventSystemClientCreateType = @convention(c) (CFAllocator?) -> AnyObject?
    private typealias IOHIDEventCreateAuxiliaryControlButtonType = @convention(c) (CFAllocator?, UInt32, Bool, UInt32) -> AnyObject?
    private typealias IOHIDEventSystemClientDispatchEventType = @convention(c) (AnyObject?, AnyObject?) -> Void

    // Dynamic function pointer types for private DisplayServices APIs
    private typealias DisplayServicesGetBrightnessType = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias DisplayServicesSetBrightnessType = @convention(c) (CGDirectDisplayID, Float) -> Int32

    // MARK: - Auxiliary Key via NSEvent (legacy)
    /// Sends an auxiliary key event (like Brightness Up/Down) using the traditional NSEvent method.
    /// This method may be ignored by newer macOS versions but retained for compatibility.
    public static func postAuxiliaryKey(_ key: Int32) {
        func postEvent(down: Bool) {
            let state: Int = down ? 0xa : 0xb
            let data1 = (Int(key) << 16) | (state << 8)
            let ev = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: down ? NSEvent.ModifierFlags(rawValue: 0xa00) : NSEvent.ModifierFlags(rawValue: 0xb00),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            ev?.cgEvent?.post(tap: .cghidEventTap)
        }
        postEvent(down: true)
        postEvent(down: false)
    }

    // MARK: - Auxiliary Key via IOHID (reliable for brightness)
    /// Sends an auxiliary key event using IOHIDEventSystemClient, which works reliably for brightness keys.
    public static func postAuxiliaryKeyIOHID(_ key: Int32) {
        let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW)
        guard let clientCreateSym = dlsym(handle, "IOHIDEventSystemClientCreate"),
              let eventCreateSym = dlsym(handle, "IOHIDEventCreateAuxiliaryControlButton"),
              let dispatchEventSym = dlsym(handle, "IOHIDEventSystemClientDispatchEvent") else {
            // Fallback if dynamic loading fails
            postAuxiliaryKey(key)
            return
        }
        
        let clientCreate = unsafeBitCast(clientCreateSym, to: IOHIDEventSystemClientCreateType.self)
        let eventCreate = unsafeBitCast(eventCreateSym, to: IOHIDEventCreateAuxiliaryControlButtonType.self)
        let dispatchEvent = unsafeBitCast(dispatchEventSym, to: IOHIDEventSystemClientDispatchEventType.self)
        
        guard let client = clientCreate(kCFAllocatorDefault) else { return }
        
        let downEvent = eventCreate(kCFAllocatorDefault, UInt32(key), true, 0)
        let upEvent = eventCreate(kCFAllocatorDefault, UInt32(key), false, 0)
        
        if let down = downEvent, let up = upEvent {
            dispatchEvent(client, down)
            dispatchEvent(client, up)
        }
    }

    // MARK: - Screen Brightness Control via DisplayServices
    /// Adjusts screen brightness up or down.
    public static func adjustBrightness(up: Bool) {
        let displayID = CGMainDisplayID()
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
        if let handle = handle,
           let getBrightnessSym = dlsym(handle, "DisplayServicesGetBrightness"),
           let setBrightnessSym = dlsym(handle, "DisplayServicesSetBrightness") {
            let getBrightness = unsafeBitCast(getBrightnessSym, to: DisplayServicesGetBrightnessType.self)
            let setBrightness = unsafeBitCast(setBrightnessSym, to: DisplayServicesSetBrightnessType.self)
            
            var current: Float = 0.5
            if getBrightness(displayID, &current) == 0 {
                let step: Float = 0.0625
                let newBrightness = up ? min(1.0, current + step) : max(0.0, current - step)
                _ = setBrightness(displayID, newBrightness)
                dlclose(handle)
                return
            }
            dlclose(handle)
        }
        
        // Fallback to IOHID if DisplayServices is not available or fails
        let key: Int32 = up ? 2 : 3
        postAuxiliaryKeyIOHID(key)
    }

    // MARK: - GIF Frame Extraction
    /// Extracts frames from a local GIF file.
    public static func extractGifFrames(from path: String) -> [NSImage] {
        guard !path.isEmpty else { return [] }
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return [] }
        var frames: [NSImage] = []
        let count = CGImageSourceGetCount(source)
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                frames.append(NSImage(cgImage: cgImage, size: NSZeroSize))
            }
        }
        return frames
    }
}
