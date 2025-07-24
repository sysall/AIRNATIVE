import SwiftUI
import Network

struct TrackpadView: View {
    @ObservedObject var inputService: InputService
    @GestureState private var dragState = CGSize.zero
    @State private var previousTranslation = CGSize.zero
    @State private var isTapping = false
    @State private var isDragging = false
    @State private var lastClickTime = Date.distantPast
    @State private var clickCount = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Main trackpad area for movement (top 80%)
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: geometry.size.height * 0.8)
                    // Movement gesture - only in the main area
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($dragState) { value, state, _ in
                                let delta = CGSize(
                                    width: value.translation.width - previousTranslation.width,
                                    height: value.translation.height - previousTranslation.height
                                )
                                state = delta
                                
                                if !isDragging {
                                    inputService.sendMouseEvent(
                                        type: .move,
                                        deltaX: Float(delta.width),
                                        deltaY: Float(delta.height)
                                    )
                                }
                                previousTranslation = value.translation
                            }
                            .onEnded { value in
                                previousTranslation = .zero
                                if isDragging {
                                    inputService.sendMouseEvent(type: .dragEnd)
                                    isDragging = false
                                }
                            }
                    )
                
                // Click buttons area (bottom 20%)
                HStack(spacing: 1) {
                    // Left click button
                    Button(action: {
                        let now = Date()
                        let timeSinceLastClick = now.timeIntervalSince(lastClickTime)
                        
                        if timeSinceLastClick < 0.4 { // Double-click window
                            // This is a double-click
                            clickCount = 0 // Reset count
                            inputService.sendMouseEvent(type: .doubleClick, button: .left)
                            print("Double-click detected")
                        } else {
                            // This is a single click
                            clickCount = 1
                            inputService.sendMouseEvent(type: .click, button: .left)
                            print("Single click detected")
                        }
                        
                        lastClickTime = now
                        isTapping = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTapping = false
                        }
                    }) {
                        Rectangle()
                            .fill(isTapping ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
                            .frame(height: geometry.size.height * 0.2)
                            .overlay(
                                Text("L")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Right click button
                    Button(action: {
                        inputService.sendMouseEvent(type: .rightClick, button: .right)
                    }) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: geometry.size.height * 0.2)
                            .overlay(
                                Text("R")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
    }
}
