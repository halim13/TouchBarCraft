import Cocoa
import ImageIO

public struct SystemUtils {
    
    /// Memposting Auxiliary Key Event (seperti Brightness Up/Down) ke HID Event Tap secara aman.
    /// brightnessUp: 2 (NX_KEYTYPE_BRIGHTNESS_UP)
    /// brightnessDown: 3 (NX_KEYTYPE_BRIGHTNESS_DOWN)
    public static func postAuxiliaryKey(_ key: Int32) {
        func makeEvent(down: Bool) -> NSEvent? {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
            let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
            
            let ev = NSEvent.otherEvent(
                with: .systemDefined,
                location: NSPoint.zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8, // NX_SUBTYPE_AUX_CONTROL_BUTTONS
                data1: data1,
                data2: -1
            )
            return ev
        }
        
        if let downEvent = makeEvent(down: true)?.cgEvent {
            downEvent.post(tap: .cghidEventTap)
        }
        if let upEvent = makeEvent(down: false)?.cgEvent {
            upEvent.post(tap: .cghidEventTap)
        }
    }
    
    /// Mengekstrak frame gambar dari file GIF lokal
    public static func extractGifFrames(from path: String) -> [NSImage] {
        guard !path.isEmpty else { return [] }
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return []
        }
        
        var frames: [NSImage] = []
        let count = CGImageSourceGetCount(source)
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let nsImage = NSImage(cgImage: cgImage, size: NSZeroSize)
                frames.append(nsImage)
            }
        }
        return frames
    }
}
