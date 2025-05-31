import SwiftUI
import Network

struct KeyboardView: View {
    @ObservedObject var inputService: InputService
    @State private var text = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Invisible text editor that will trigger the keyboard
                TextEditor(text: $text)
                    .frame(width: 1, height: 1)
                    .opacity(0.01) // Almost invisible but still interactive
                    .focused($isFocused)
                    .onChange(of: text) { oldValue, newValue in
                        if let lastChar = newValue.last {
                            inputService.sendKeyEvent(keyCode: UInt16(lastChar.asciiValue ?? 0), isKeyDown: true)
                            // Reset text after sending
                            text = ""
                        }
                    }
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
                
                // Visual indicator
                VStack {
                    Image(systemName: "keyboard")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Tap anywhere to type")
                        .foregroundColor(.gray)
                }
            }
            .contentShape(Rectangle()) // Makes the entire view tappable
            .onTapGesture {
                isFocused = true
            }
        }
        .onAppear {
            // Automatically show keyboard when view appears
            isFocused = true
        }
    }
}
