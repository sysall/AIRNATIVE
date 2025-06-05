import Foundation

struct KeyboardMapping {
    // Maps iPad keyboard keycodes to macOS virtual keycodes
    static func getMacOSKeyCode(from ipadKeyCode: UInt16) -> UInt16 {
        // This mapping is based on the standard US keyboard layout
        switch ipadKeyCode {
        // Letters (A-Z)
        case 0x61...0x7A: // a-z in ASCII
            return ipadKeyCode - 0x61 + 0x00 // Maps to macOS virtual keycodes 0x00-0x19
        case 0x41...0x5A: // A-Z in ASCII
            return ipadKeyCode - 0x41 + 0x00 // Same mapping for uppercase
            
        // Numbers (0-9)
        case 0x30...0x39: // 0-9 in ASCII
            return ipadKeyCode - 0x30 + 0x1D // Maps to macOS virtual keycodes 0x1D-0x26
            
        // Special characters
        case 0x20: return 0x31 // Space
        case 0x2D: return 0x1B // Minus
        case 0x3D: return 0x18 // Equals
        case 0x5B: return 0x21 // Left bracket
        case 0x5D: return 0x1E // Right bracket
        case 0x5C: return 0x2A // Backslash
        case 0x3B: return 0x29 // Semicolon
        case 0x27: return 0x27 // Quote
        case 0x2C: return 0x2B // Comma
        case 0x2E: return 0x2F // Period
        case 0x2F: return 0x2C // Forward slash
        case 0x60: return 0x32 // Backtick
        
        // Return key
        case 0x0A, 0x0D: return 0x24 // Return/Enter
        
        // Function keys (F1-F12)
        case 0x70...0x7B: // F1-F12 in ASCII
            return ipadKeyCode - 0x70 + 0x3A // Maps to macOS virtual keycodes 0x3A-0x45
            
        // Arrow keys
        case 0x2190: return 0x7B // Left arrow
        case 0x2191: return 0x7E // Up arrow
        case 0x2192: return 0x7C // Right arrow
        case 0x2193: return 0x7D // Down arrow
        
        // Other special keys
        case 0x08: return 0x33 // Backspace
        case 0x09: return 0x30 // Tab
        case 0x1B: return 0x35 // Escape
        case 0x7F: return 0x75 // Delete
        
        default:
            return 0x00 // Unknown key
        }
    }
} 