import SwiftUI
import Network

struct KeyboardView: View {
    @ObservedObject var inputService: InputService
    
    @State private var layout: KeyboardLayout = .azerty
    @State private var shiftActive = false
    @State private var optionActive = false
    @State private var commandActive = false
    @State private var controlActive = false
    
    // Define key sizes for iPad
    private let keyWidth: CGFloat = 60
    private let keyHeight: CGFloat = 60
    private let keySpacing: CGFloat = 8
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: keySpacing) {
                // Layout switcher
                Picker("Layout", selection: $layout) {
                    Text("AZERTY").tag(KeyboardLayout.azerty)
                    Text("QWERTY").tag(KeyboardLayout.qwerty)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: keySpacing) {
                        // Top row: esc + function keys
                        HStack(spacing: keySpacing) {
                            KeyButton(text: "esc", width: keyWidth, height: keyHeight, isActive: false) {
                                sendKey(.esc)
                            }
                            ForEach(1...12, id: \.self) { num in
                                KeyButton(text: "F\(num)", width: keyWidth, height: keyHeight, isActive: false) {
                                    sendKey(.function(num))
                                }
                            }
                        }
                        // Numeric row under function keys
                        HStack(spacing: keySpacing) {
                            let numbers = ["1","2","3","4","5","6","7","8","9","0"]
                            ForEach(numbers, id: \.self) { key in
                                KeyButton(text: key, width: keyWidth, height: keyHeight, isActive: false) {
                                    sendKey(.number(key))
                                }
                            }
                        }
                        // Main keyboard rows
                        ForEach(layout.rows, id: \.self) { row in
                            HStack(spacing: keySpacing) {
                                ForEach(Array(row.enumerated()), id: \.offset) { index, key in
                                    let isActive = isModifierActive(key)
                                    KeyButton(text: key, width: keyWidth, height: keyHeight, isActive: isActive) {
                                        handleKeyPress(key)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func isModifierActive(_ key: String) -> Bool {
        switch key {
        case "⇧": return shiftActive
        case "option": return optionActive
        case "command": return commandActive
        case "control": return controlActive
        default: return false
        }
    }
    
    private func handleKeyPress(_ key: String) {
        switch key {
        case "⇧": shiftActive.toggle()
        case "option": optionActive.toggle()
        case "command": commandActive.toggle()
        case "control": controlActive.toggle()
        default:
            sendKey(.character(key))
            // Reset one-shot modifiers (like shift)
            if shiftActive { shiftActive = false }
        }
    }
    
    private func sendKey(_ key: KeyboardKey) {
        // Key label to macOS virtual keycode mapping for AZERTY
        let azertyKeyMap: [String: UInt16] = [
            // Top row
            "#": 0x0A, "&": 0x12, "é": 0x13, "\"": 0x14, "'": 0x15, "(": 0x17, "-": 0x1A, "è": 0x1C, "_": 0x1D, "ç": 0x1B, "à": 0x18, ")": 0x19, "=": 0x1E, "]": 0x1F,
            // First letter row
            "A": 0x00, "Z": 0x06, "E": 0x0E, "R": 0x0F, "T": 0x11, "Y": 0x10, "U": 0x20, "I": 0x22, "O": 0x1F, "P": 0x23, "^": 0x21, "$": 0x1E, "*": 0x1F,
            // Second letter row
            "Q": 0x0C, "S": 0x01, "D": 0x02, "F": 0x03, "G": 0x05, "H": 0x04, "J": 0x26, "K": 0x28, "L": 0x25, "M": 0x2E, "ù": 0x2F, "µ": 0x27,
            // Third letter row
            "<": 0x32, "W": 0x0D, "X": 0x07, "C": 0x08, "V": 0x09, "B": 0x0B, "N": 0x2D, ",": 0x2B, ";": 0x29, ":": 0x2A, "!": 0x2C,
            // Modifiers and arrows
            "esc": 0x35, "⏎": 0x24, "⇧": 0x38, "control": 0x3B, "option": 0x3A, "command": 0x37, " ": 0x31, "fn": 0x3F, "←": 0x7B, "↑": 0x7E, "↓": 0x7D, "→": 0x7C
        ]
        // QWERTY mapping (partial, add more as needed)
        let qwertyKeyMap: [String: UInt16] = [
            "`": 0x32, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D, "-": 0x1B, "=": 0x18, "⌫": 0x33,
            "Q": 0x0C, "W": 0x0D, "E": 0x0E, "R": 0x0F, "T": 0x11, "Y": 0x10, "U": 0x20, "I": 0x22, "O": 0x1F, "P": 0x23, "[": 0x21, "]": 0x1E, "\\": 0x2A,
            "A": 0x00, "S": 0x01, "D": 0x02, "F": 0x03, "G": 0x05, "H": 0x04, "J": 0x26, "K": 0x28, "L": 0x25, ";": 0x29, "'": 0x27, "⏎": 0x24,
            "Z": 0x06, "X": 0x07, "C": 0x08, "V": 0x09, "B": 0x0B, "N": 0x2D, "M": 0x2E, ",": 0x2B, ".": 0x2F, "/": 0x2C, "⇧": 0x38,
            "⇥": 0x30, "⇪": 0x39, "control": 0x3B, "option": 0x3A, "command": 0x37, " ": 0x31, "fn": 0x3F, "←": 0x7B, "↑": 0x7E, "↓": 0x7D, "→": 0x7C
        ]
        // Numeric row (shared)
        let numberKeyMap: [String: UInt16] = [
            "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D
        ]
        // Function keys
        func functionKeyCode(_ n: Int) -> UInt16 { return 0x7A + UInt16(n - 1) } // F1 = 0x7A
        // Get the keycode
        var keyCode: UInt16? = nil
        switch key {
        case .esc:
            keyCode = 0x35
        case .function(let n):
            keyCode = functionKeyCode(n)
        case .number(let n):
            keyCode = numberKeyMap[n]
        case .character(let label):
            if layout == .azerty {
                keyCode = azertyKeyMap[label]
            } else {
                keyCode = qwertyKeyMap[label]
            }
        }
        guard let code = keyCode else { return }
        // Modifiers
        var modifiers: [UInt16] = []
        if shiftActive { modifiers.append(0x38) }
        if optionActive { modifiers.append(0x3A) }
        if commandActive { modifiers.append(0x37) }
        if controlActive { modifiers.append(0x3B) }
        // Send modifier key down events first
        for mod in modifiers { inputService.sendKeyEvent(keyCode: mod, isKeyDown: true) }
        // Send main key down event
        inputService.sendKeyEvent(keyCode: code, isKeyDown: true)
        // Send main key up event
        inputService.sendKeyEvent(keyCode: code, isKeyDown: false)
        // Send modifier key up events
        for mod in modifiers.reversed() { inputService.sendKeyEvent(keyCode: mod, isKeyDown: false) }
    }
}

enum KeyboardLayout: String, CaseIterable, Identifiable {
    case azerty, qwerty
    var id: String { rawValue }
    
    var rows: [[String]] {
        switch self {
        case .azerty:
            return [
                ["#", "&", "é", "\"", "'", "(", "-", "è", "_", "ç", "à", ")", "=", "]"],
                ["→", "A", "Z", "E", "R", "T", "Y", "U", "I", "O", "P", "^", "$", "*"],
                ["⇧", "Q", "S", "D", "F", "G", "H", "J", "K", "L", "M", "ù", "µ", "⏎"],
                ["⇧", "<", "W", "X", "C", "V", "B", "N", ",", ";", ":", "!", "⇧"],
                ["fn", "control", "option", "command", " ", "command", "option", "←", "↑", "↓", "→"]
            ]
        case .qwerty:
            return [
                ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "⌫"],
                ["⇥", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\"],
                ["⇪", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "⏎"],
                ["⇧", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "⇧"],
                ["fn", "control", "option", "command", " ", "command", "option", "←", "↑", "↓", "→"]
            ]
        }
    }
}

enum KeyboardKey: Equatable {
    case esc
    case function(Int)
    case number(String)
    case character(String)
}

struct KeyButton: View {
    let text: String
    let width: CGFloat
    let height: CGFloat
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 20, weight: .medium))
                .frame(width: width, height: height)
                .background(isActive ? Color.blue.opacity(0.3) : Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
}
