import SwiftUI
import Network

struct KeyboardView: View {
    @ObservedObject var inputService: InputService
    
    @State private var layout: KeyboardLayout = .azerty
    @State private var isShiftPressed = false
    @State private var isOptionPressed = false
    @State private var isCommandPressed = false
    @State private var isControlPressed = false
    
    // MARK: - Constants
    private let keyWidth: CGFloat = 60
    private let keyHeight: CGFloat = 60
    private let keySpacing: CGFloat = 8
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: keySpacing) {
                layoutPicker
                
                ScrollView {
                    VStack(spacing: keySpacing) {
                        numberRow(geometry: geometry)
                        keyboardRows(geometry: geometry)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - UI Components
    private var layoutPicker: some View {
        Picker("Layout", selection: $layout) {
            Text("AZERTY").tag(KeyboardLayout.azerty)
            Text("QWERTY").tag(KeyboardLayout.qwerty)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    private func numberRow(geometry: GeometryProxy) -> some View {
        let numbers = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        return keyRow(keys: numbers, geometry: geometry) { key in
            sendKey(.character(key))
        }
    }
    
    private func keyboardRows(geometry: GeometryProxy) -> some View {
        ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
            keyRow(keys: row, geometry: geometry) { key in
                handleKeyPress(key)
            }
        }
    }
    
    private func keyRow(keys: [String], geometry: GeometryProxy, action: @escaping (String) -> Void) -> some View {
        HStack(spacing: keySpacing) {
            let (baseKeyWidth, spaceWidth) = calculateKeyWidths(for: keys, geometry: geometry)
            
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                let width = key == " " ? spaceWidth : baseKeyWidth
                let isActive = isModifierActive(key)
                
                KeyButton(
                    text: displayText(for: key),
                    width: width,
                    height: keyHeight,
                    isActive: isActive
                ) {
                    action(key)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func calculateKeyWidths(for keys: [String], geometry: GeometryProxy) -> (base: CGFloat, space: CGFloat) {
        let spaceMultiplier: CGFloat = 5
        let spaceCount = keys.filter { $0 == " " }.count
        let normalKeyCount = CGFloat(keys.count - spaceCount)
        let totalSpacing = keySpacing * CGFloat(keys.count - 1)
        let availableWidth = geometry.size.width - totalSpacing - 32 // padding
        
        let totalUnits = normalKeyCount + CGFloat(spaceCount) * spaceMultiplier
        let baseWidth = availableWidth / totalUnits
        
        return (base: baseWidth, space: baseWidth * spaceMultiplier)
    }
    
    private func displayText(for key: String) -> String {
        // Show lowercase letters when shift is not active, uppercase when it is
        if key.count == 1, key.rangeOfCharacter(from: .letters) != nil {
            return isShiftPressed ? key.uppercased() : key.lowercased()
        }
        return key
    }
    
    private func isModifierActive(_ key: String) -> Bool {
        switch key {
        case "⇧": return isShiftPressed
        case "⌥": return isOptionPressed
        case "⌘": return isCommandPressed
        case "⌃": return isControlPressed
        default: return false
        }
    }
    
    // MARK: - Key Handling
    private func handleKeyPress(_ key: String) {
        switch key {
        case "⇧":
            toggleModifier(&isShiftPressed, keyCode: VirtualKeyCode.shift)
        case "⌥":
            toggleModifier(&isOptionPressed, keyCode: VirtualKeyCode.option)
        case "⌘":
            toggleModifier(&isCommandPressed, keyCode: VirtualKeyCode.command)
        case "⌃":
            toggleModifier(&isControlPressed, keyCode: VirtualKeyCode.control)
        default:
            sendKey(.character(key))
            
            // Auto-release shift after typing a character (one-shot behavior)
            if isShiftPressed {
                isShiftPressed = false
            }
        }
    }
    
    private func toggleModifier(_ isActive: inout Bool, keyCode: UInt16) {
        isActive.toggle()
        inputService.sendKeyEvent(keyCode: keyCode, isKeyDown: isActive)
    }
    
    private func sendKey(_ key: KeyboardKey) {
        // For characters (letters, numbers, symbols), send the actual character
        if case .character(let char) = key {
            let finalChar = determineFinalCharacter(char)
            print("📤 Sending character: '\(finalChar)'")
            inputService.sendCharacter(finalChar)
            return
        }
        
        // For special keys (function keys, arrows, etc.), use key codes
        guard let keyMapping = getKeyMapping(for: key) else { return }
        
        // Build modifiers including current modifier state
        let modifiers = buildModifiers(for: keyMapping, key: key)
        
        // Send key sequence with modifiers
        sendKeySequence(keyCode: keyMapping.keyCode, modifiers: modifiers)
    }
    
    private func determineFinalCharacter(_ char: String) -> String {
        // For letters, return uppercase if shift is pressed
        if layout.isLetter(char) {
            return isShiftPressed ? char.uppercased() : char.lowercased()
        }
        
        // For other characters, return as-is (they're already the final character)
        return char
    }
    
    private func getKeyMapping(for key: KeyboardKey) -> KeyMapping? {
        switch key {
        case .esc:
            return KeyMapping(keyCode: VirtualKeyCode.escape)
        case .function(let n):
            return KeyMapping(keyCode: VirtualKeyCode.function(n))
        case .number(let number):
            return KeyMapping(keyCode: VirtualKeyCode.number(number))
        case .character(let char):
            return layout.keyMapping(for: char)
        }
    }
    
    private func buildModifiers(for keyMapping: KeyMapping, key: KeyboardKey) -> [UInt16] {
        var modifiers: [UInt16] = []
        
        // Only add modifiers for special keys that require them
        if keyMapping.needsShift {
            modifiers.append(VirtualKeyCode.shift)
        }
        if keyMapping.needsOption {
            modifiers.append(VirtualKeyCode.option)
        }
        
        return modifiers
    }
    
    private func sendKeySequence(keyCode: UInt16, modifiers: [UInt16]) {
        // Send main key with modifiers applied
        inputService.sendKeyEvent(keyCode: keyCode, isKeyDown: true, modifiers: modifiers)
        inputService.sendKeyEvent(keyCode: keyCode, isKeyDown: false)
    }
}

// MARK: - Supporting Types
struct KeyMapping {
    let keyCode: UInt16
    let needsShift: Bool
    let needsOption: Bool
    
    init(keyCode: UInt16, needsShift: Bool = false, needsOption: Bool = false) {
        self.keyCode = keyCode
        self.needsShift = needsShift
        self.needsOption = needsOption
    }
}

enum VirtualKeyCode {
    static let escape: UInt16 = 0x35
    static let shift: UInt16 = 0x38
    static let option: UInt16 = 0x3A
    static let command: UInt16 = 0x37
    static let control: UInt16 = 0x3B
    static let enter: UInt16 = 0x24
    static let space: UInt16 = 0x31
    static let backspace: UInt16 = 0x33
    static let capsLock: UInt16 = 0x39
    
    // Arrow keys
    static let leftArrow: UInt16 = 0x7B
    static let rightArrow: UInt16 = 0x7C
    static let downArrow: UInt16 = 0x7D
    static let upArrow: UInt16 = 0x7E
    
    // Numbers (keypad for direct output)
    static func number(_ n: String) -> UInt16 {
        switch n {
        case "1": return 0x53
        case "2": return 0x54
        case "3": return 0x55
        case "4": return 0x56
        case "5": return 0x57
        case "6": return 0x58
        case "7": return 0x59
        case "8": return 0x5B
        case "9": return 0x5C
        case "0": return 0x52
        default: return 0x52
        }
    }
    
    // Function keys
    static func function(_ n: Int) -> UInt16 {
        return 0x7A + UInt16(max(1, min(12, n)) - 1)
    }
    

}

enum KeyboardLayout: String, CaseIterable, Identifiable {
    case azerty, qwerty
    var id: String { rawValue }
    
    var rows: [[String]] {
        switch self {
        case .azerty:
            return [
                ["&", "é", "\"", "'", "(", ")", "è", "!", "/", "ç", "à", "+", "-", "{", "}"],
                ["@", "a", "z", "e", "r", "t", "y", "u", "i", "o", "p", "^", "_", "%", "⌫"],
                ["⇪", "\\", "q", "s", "d", "f", "g", "h", "j", "k", "l", "m", "$", "*", "⏎"],
                ["⇧", "<", ">", "w", "x", "c", "v", "b", "n", ",", ";", ".", "?", "↑", "="],
                ["#", "⌥", "⌘", " ", "⌘", "⌥", "←", "↓", "→"]
            ]
        case .qwerty:
            return [
                ["&", "\"", "'", "(", "[", "!", "{", "}", ")", "$", "]", "-", "+", "\\"],
                ["@", "q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "%", "|", "_", "⌫"],
                ["⇪", "/", "a", "s", "d", "f", "g", "h", "j", "k", "l", "m", ":", "⏎"],
                ["⇧", "<", ">", "z", "x", "c", "v", "b", "n", ";", ",", ".", "?", "↑", "="],
                ["#", "⌥", "⌘", " ", "⌘", "⌥", "←", "↓", "→"]
            ]
        }
    }
    
    func keyMapping(for character: String) -> KeyMapping? {
        // Only return mappings for special control keys
        return controlKeyMapping[character]
    }
    
    func isLetter(_ character: String) -> Bool {
        return character.count == 1 && character.rangeOfCharacter(from: .letters) != nil
    }
    
    private var controlKeyMapping: [String: KeyMapping] {
        [
            // Control keys only
            "⏎": KeyMapping(keyCode: VirtualKeyCode.enter),
            " ": KeyMapping(keyCode: VirtualKeyCode.space),
            "⌫": KeyMapping(keyCode: VirtualKeyCode.backspace),
            "←": KeyMapping(keyCode: VirtualKeyCode.leftArrow),
            "→": KeyMapping(keyCode: VirtualKeyCode.rightArrow),
            "↑": KeyMapping(keyCode: VirtualKeyCode.upArrow),
            "↓": KeyMapping(keyCode: VirtualKeyCode.downArrow),
            "⇪": KeyMapping(keyCode: VirtualKeyCode.capsLock)
        ]
    }
}

enum KeyboardKey: Equatable {
    case esc
    case function(Int)
    case number(String)
    case character(String)
    
    var character: String? {
        switch self {
        case .character(let char):
            return char
        default:
            return nil
        }
    }
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
