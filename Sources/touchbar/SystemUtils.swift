import Cocoa
import ImageIO

public struct SystemUtils {
    
    /// Memposting Auxiliary Key Event (seperti Brightness Up/Down) ke HID Event Tap secara aman.
    /// brightnessUp: 2 (NX_KEYTYPE_BRIGHTNESS_UP)
    /// brightnessDown: 3 (NX_KEYTYPE_BRIGHTNESS_DOWN)
    public static func postAuxiliaryKey(_ key: Int32) {
        // Correct layout for media/brightness auxiliary keys in macOS:
        // subtype is 8 (NX_SUBTYPE_AUX_CONTROL_BUTTONS)
        // data1 consists of: (key << 16) | (NX_KEYSTATE_DOWN/UP << 8)
        func postEvent(down: Bool) {
            let state: Int = down ? 0xa : 0xb
            let data1 = (Int(key) << 16) | (state << 8)
            
            let ev = NSEvent.otherEvent(
                with: .systemDefined,
                location: NSPoint.zero,
                modifierFlags: down ? NSEvent.ModifierFlags(rawValue: 0xa00) : NSEvent.ModifierFlags(rawValue: 0xb00),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            
            if let cgEvent = ev?.cgEvent {
                cgEvent.post(tap: .cghidEventTap)
            }
        }
        
        postEvent(down: true)
        postEvent(down: false)
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
