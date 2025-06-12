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
                            let functionRow = ["esc"] + (1...12).map { "F\($0)" }
                            let spaceMultiplier: CGFloat = 5
                            let spaceCount = functionRow.filter { $0 == " " }.count
                            let normalKeyCount = CGFloat(functionRow.count) - CGFloat(spaceCount) + CGFloat(spaceCount) * spaceMultiplier
                            let totalSpacing = keySpacing * CGFloat(functionRow.count - 1)
                            let availableWidth = geometry.size.width - totalSpacing - 32 // 32 for padding
                            let baseKeyWidth = availableWidth / normalKeyCount
                            ForEach(Array(functionRow.enumerated()), id: \.offset) { index, key in
                                let isActive = false
                                let isSpace = key == " "
                                let keyW: CGFloat = isSpace ? baseKeyWidth * spaceMultiplier : baseKeyWidth
                                KeyButton(text: key, width: keyW, height: keyHeight, isActive: isActive) {
                                    if key == "esc" {
                                        sendKey(.esc)
                                    } else if key.starts(with: "F"), let num = Int(key.dropFirst()) {
                                        sendKey(.function(num))
                                    }
                                }
                            }
                        }
                        // Numeric row under function keys
                        HStack(spacing: keySpacing) {
                            let numbers = ["1","2","3","4","5","6","7","8","9","0"]
                            let spaceMultiplier: CGFloat = 5
                            let spaceCount = numbers.filter { $0 == " " }.count
                            let normalKeyCount = CGFloat(numbers.count) - CGFloat(spaceCount) + CGFloat(spaceCount) * spaceMultiplier
                            let totalSpacing = keySpacing * CGFloat(numbers.count - 1)
                            let availableWidth = geometry.size.width - totalSpacing - 32 // 32 for padding
                            let baseKeyWidth = availableWidth / normalKeyCount
                            ForEach(Array(numbers.enumerated()), id: \.offset) { index, key in
                                let isActive = false
                                let isSpace = key == " "
                                let keyW: CGFloat = isSpace ? baseKeyWidth * spaceMultiplier : baseKeyWidth
                                KeyButton(text: key, width: keyW, height: keyHeight, isActive: isActive) {
                                    sendKey(.number(key))
                                }
                            }
                        }
                        // Main keyboard rows
                        ForEach(layout.rows, id: \.self) { row in
                            HStack(spacing: keySpacing) {
                                let spaceMultiplier: CGFloat = 5
                                let spaceCount = row.filter { $0 == " " }.count
                                let normalKeyCount = CGFloat(row.count) - CGFloat(spaceCount) + CGFloat(spaceCount) * spaceMultiplier
                                let totalSpacing = keySpacing * CGFloat(row.count - 1)
                                let availableWidth = geometry.size.width - totalSpacing - 32 // 32 for padding
                                let baseKeyWidth = availableWidth / normalKeyCount
                                ForEach(Array(row.enumerated()), id: \.offset) { index, key in
                                    let isActive = isModifierActive(key)
                                    let isSpace = key == " "
                                    let keyW: CGFloat = isSpace ? baseKeyWidth * spaceMultiplier : baseKeyWidth
                                    KeyButton(text: key, width: keyW, height: keyHeight, isActive: isActive) {
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
        case "⌥": optionActive.toggle()
        case "⌘": commandActive.toggle()
        case "⌃": controlActive.toggle()
        default:
            sendKey(.character(key))
            // Reset one-shot modifiers (like shift)
            if shiftActive { shiftActive = false }
        }
    }
    
    private func sendKey(_ key: KeyboardKey) {
        // Key label to macOS virtual keycode mapping for AZERTY
        let azertyKeyMap: [String: UInt16] = [
            // Chiffres
            "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
            "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,

            // Ligne 1 symboles
            "&": 0x12, // 1 key
            "é": 0x13, // 2 key
            "\"": 0x14, // 3 key
            "'": 0x15, // 4 key
            "(": 0x17, // 5 key
            "-": 0x1B, // - key
            "è": 0x1C, // 7 key
            "_": 0x1F, // underscore (usually needs shift, but mapped directly)
            "ç": 0x1B, // c-cedilla (same as - key, but needs option/alt)
            "à": 0x18, // = key
            ")": 0x19, // 9 key
            "=": 0x1E, // = key
            "+": 0x18, // = key (shifted)
            "*": 0x17, // 5 key (shifted)

            // More symbols
            "#": 0x29, // ; key (shifted)
            "[": 0x21, // [ key
            "]": 0x1E, // ] key
            "{": 0x21, // [ key (shifted)
            "}": 0x1E, // ] key (shifted)
            "`": 0x32, // backtick
            "°": 0x27, // ' key (shifted)
            "|": 0x2A, // backslash (shifted)
            "~": 0x32, // backtick (shifted)
            "€": 0x21, // [ key (option/alt)
            "£": 0x23, // p key (option/alt)
            "¨": 0x2A, // backslash (option/alt)
            "!": 0x12, // 1 key (shifted)
            "/": 0x2C, // slash
            "@": 0x21, // [ key (option/alt)
            "\\": 0x2A, // backslash
            "%": 0x17, // 5 key (shifted)

            // Lettres
            "A": 0x0C, "Z": 0x0D, "E": 0x0E, "R": 0x0F, "T": 0x11,
            "Y": 0x10, "U": 0x20, "I": 0x22, "O": 0x1F, "P": 0x23,
            "^": 0x21, "$": 0x1E,

            "Q": 0x00, "S": 0x01, "D": 0x02, "F": 0x03, "G": 0x05,
            "H": 0x04, "J": 0x26, "K": 0x28, "L": 0x25, "M": 0x29,
            "ù": 0x2F, "µ": 0x27,

            "W": 0x06, "X": 0x07, "C": 0x08, "V": 0x09, "B": 0x0B,
            "N": 0x2D, ",": 0x2E, ";": 0x2B, ".": 0x2F, "<": 0x32,
            ">": 0x2A, // backslash (shifted)
            "?": 0x2C, // slash (shifted)

            // Modificateurs et spéciaux
            "⏎": 0x24, "fn": 0x3F, "⌃": 0x3B, "⌥": 0x3A,
            "⌘": 0x37, " ": 0x31, "←": 0x7B, "↑": 0x7E,
            "↓": 0x7D, "→": 0x7C, "⌫": 0x33
        ]

        // QWERTY mapping (now more complete)
        let qwertyKeyMap: [String: UInt16] = [
            // Ligne 1
            "`": 0x32, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15,
            "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19,
            "0": 0x1D, "-": 0x1B, "=": 0x18, "+": 0x18, // = key (shifted)
            "!": 0x12, // 1 key (shifted)
            "@": 0x21, // [ key (option/alt)
            "#": 0x29, // ; key (shifted)
            "$": 0x21, // [ key (option/alt)
            "%": 0x17, // 5 key (shifted)
            "^": 0x21, // [ key (option/alt)
            "&": 0x12, // 1 key (shifted)
            "*": 0x17, // 5 key (shifted)
            "(": 0x19, // 9 key (shifted)
            ")": 0x1D, // 0 key (shifted)

            // Ligne 2
            "Q": 0x00, "W": 0x06, "E": 0x0E, "R": 0x0F, "T": 0x11,
            "Y": 0x10, "U": 0x20, "I": 0x22, "O": 0x1F, "P": 0x23,
            "[": 0x21, "]": 0x1E, "\\": 0x2A, "{": 0x21, "}": 0x1E,
            "|": 0x2A, // backslash (shifted)

            // Ligne 3
            "A": 0x0C, "S": 0x01, "D": 0x02, "F": 0x03, "G": 0x05,
            "H": 0x04, "J": 0x26, "K": 0x28, "L": 0x25, ";": 0x2B,
            "'": 0x27, "⏎": 0x24, "_": 0x1B, // - key (shifted)
            "/": 0x2C, // slash
            "?": 0x2C, // slash (shifted)
            "%": 0x17, // 5 key (shifted)
            "@": 0x21, // [ key (option/alt)

            // Ligne 4
            "Z": 0x0D, "X": 0x07, "C": 0x08, "V": 0x09, "B": 0x0B,
            "N": 0x2D, "M": 0x29, ",": 0x2E, ".": 0x2F, "<": 0x32,
            ">": 0x2A, // backslash (shifted)
            "=": 0x18, // = key
            ";": 0x2B, // semicolon

            // Modificateurs et spéciaux
            "fn": 0x3F, "⌃": 0x3B, "⌥": 0x3A, "⌘": 0x37,
            " ": 0x31, "←": 0x7B, "↑": 0x7E, "↓": 0x7D, "→": 0x7C, "⌫": 0x33
        ]

        // Numeric row (shared)
        let numberKeyMap: [String: UInt16] = [
            "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
            "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D
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
                ["#","é", "&","\"", "{", "}", "è",  "[", "!", "/", "]", "à","(", ")", "+"],
                ["@", "A", "Z", "E", "R", "T", "Y", "U", "I", "O", "P", "^", "-", "%", "⌫"],
                ["\\", "Q", "S", "D", "F", "G", "H", "J", "K", "L", "M", "$","*", "_","⏎"],
                ["<", ">", "W", "X", "C", "V", "B", "N", ",", ";", ".", "?", "↑", "="],
                ["fn", "⌃\ncontrol", "⌥", "⌘", " ", "⌘", "⌥", "←", "↓", "→"]
            ]
        case .qwerty:
            return [
                ["&", "\"", "'", "(", "[", "!", "{", "'", "}", ")","$",  "]", "-", "+"],
                ["#","Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "⌫"],
                ["@", "A", "S", "D", "F", "G", "H", "J", "K", "L", "M", "/","_","%","⏎"],
                ["<", ">","Z", "X", "C", "V", "B", "N", ";", ",", ".", "?", "↑", "="],
                ["fn", "⌃\ncontrol", "⌥", "⌘", " ", "⌘", "⌥", "←", "↓", "→"]
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
                .background(isActive ? Color.blue.opacity(0.3) : Color.black)
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
}
