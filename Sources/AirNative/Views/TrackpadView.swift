import SwiftUI
import Network

struct TrackpadView: View {
    @ObservedObject var inputService: InputService
    @GestureState private var dragState = CGSize.zero
    @State private var previousTranslation = CGSize.zero
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Angle = .zero
    @State private var isTapping = false
    @State private var isDoubleTapping = false
    @State private var isDragging = false
    @State private var lastGestureTime = Date()
    @State private var lastClickLocation = CGPoint.zero
    @State private var twoFingerTranslation = CGSize.zero
    @State private var isInTwoFingerGesture = false

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Combined gesture for smooth movement and tap detection
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($dragState) { value, state, _ in
                            // Only handle single finger movement - ignore if in two-finger gesture
                            guard !isInTwoFingerGesture else { 
                                print("Single finger gesture blocked - two finger gesture active")
                                return 
                            }
                            
                            let delta = CGSize(
                                width: value.translation.width - previousTranslation.width,
                                height: value.translation.height - previousTranslation.height
                            )
                            state = delta
                            lastClickLocation = value.location
                            
                            if !isDragging {
                                inputService.sendMouseEvent(
                                    type: .move,
                                    deltaX: Float(delta.width),
                                    deltaY: Float(delta.height),
                                    fingerCount: 1
                                )
                            }
                            previousTranslation = value.translation
                        }
                        .onEnded { value in
                            previousTranslation = .zero
                            
                            // Only handle single finger gestures - ignore if in two-finger gesture
                            guard !isInTwoFingerGesture else { return }
                            
                            // Check if this was a tap (minimal movement)
                            let totalMovement = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                            if totalMovement < 5 { // Less than 5 points of movement = tap
                                print("Single finger tap recognized as left click")
                                inputService.sendMouseEvent(type: .click, fingerCount: 1)
                                isTapping = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isTapping = false
                                }
                            } else if isDragging {
                                inputService.sendMouseEvent(type: .dragEnd, fingerCount: 1)
                                isDragging = false
                            }
                        }
                )
                // Two finger detection using MagnificationGesture - higher priority
                .highPriorityGesture(
                    MagnificationGesture(minimumScaleDelta: 0)
                        .onChanged { value in
                            // Mark that we're in a two-finger gesture immediately
                            if !isInTwoFingerGesture {
                                print("Two finger gesture detected - blocking single finger gestures")
                                isInTwoFingerGesture = true
                            }
                        }
                        .onEnded { value in
                            // If magnification ends at 1.0 (no scaling), it was likely a tap
                            if abs(value - 1.0) < 0.1 {
                                print("Two finger tap recognized as right-click - scale: \(value)")
                                inputService.sendMouseEvent(type: .rightClick, fingerCount: 2)
                            } else {
                                print("Two finger gesture ended but not a tap - scale: \(value)")
                            }
                            
                            // Delay resetting the flag to prevent single-finger interference
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isInTwoFingerGesture = false
                            }
                        }
                )
                // Two finger scroll gesture
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            // Two finger pinch gesture
                            print("Pinching gesture recognized with scale: \(value)")
                            let delta = value / scale
                            scale = value
                            inputService.sendMouseEvent(
                                type: .gesture,
                                deltaZ: Float(delta - 1.0) * 10,
                                gestureType: .pinch,
                                gestureScale: Float(value),
                                fingerCount: 2
                            )
                        }
                        .onEnded { _ in
                            scale = 1.0
                        }
                )
                // Two finger rotation
                .simultaneousGesture(
                    RotationGesture()
                        .onChanged { angle in
                            // Two finger rotation gesture
                            print("Rotating gesture recognized with angle: \(angle)")
                            let delta = angle - rotation
                            rotation = angle
                            inputService.sendMouseEvent(
                                type: .gesture,
                                rotation: Float(delta.radians),
                                gestureType: .rotate,
                                fingerCount: 2
                            )
                        }
                        .onEnded { _ in
                            rotation = .zero
                        }
                )
                // Scroll gesture with higher minimum distance to avoid conflicts
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10) // Increased minimum distance
                        .onChanged { value in
                            // Only treat as scroll if there's significant movement
                            guard isInTwoFingerGesture else { return }
                            
                            let delta = CGSize(
                                width: value.translation.width - twoFingerTranslation.width,
                                height: value.translation.height - twoFingerTranslation.height
                            )
                            
                            inputService.sendMouseEvent(
                                type: .scroll,
                                deltaX: Float(delta.width * 0.5), // Reduce sensitivity
                                deltaY: Float(-delta.height * 0.5), // Invert Y and reduce sensitivity
                                fingerCount: 2
                            )
                            
                            twoFingerTranslation = value.translation
                        }
                        .onEnded { value in
                            twoFingerTranslation = .zero
                            
                            // Check if this was a tap (minimal movement) when not in magnification gesture
                            if !isInTwoFingerGesture {
                                let totalMovement = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                                if totalMovement < 10 { // Less than 10 points = tap
                                    print("Two finger tap detected via scroll gesture")
                                    inputService.sendMouseEvent(type: .rightClick, fingerCount: 2)
                                }
                            }
                        }
                )
                // Three finger swipe
                .simultaneousGesture(
                    DragGesture(minimumDistance: 30)
                        .onChanged { value in
                            // Three finger swipe gesture
                            print("Swiping gesture recognized with translation: \(value.translation)")
                            // Only handle swipe if within reasonable bounds
                            guard abs(value.translation.width) < 200 && abs(value.translation.height) < 200 else {
                                return
                            }
                            
                            // Determine swipe direction based on the primary axis of movement
                            let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                            let amount = isHorizontal ? value.translation.width : value.translation.height
                            let threshold: CGFloat = 50 // Min distance for a swipe
                            
                            guard abs(amount) > threshold else { return }
                            
                            let direction: SwipeDirection
                            if isHorizontal {
                                direction = amount > 0 ? .right : .left
                            } else {
                                direction = amount > 0 ? .down : .up
                            }
                            
                            // Send as gesture event with swipe type
                            inputService.sendMouseEvent(
                                type: .gesture,
                                gestureType: .swipe,
                                swipeDirection: direction,
                                fingerCount: 3
                            )
                        }
                )
                .overlay(
                    // Visual feedback
                    VStack {
                        Text("Trackpad")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .opacity(isTapping || isDoubleTapping || isDragging ? 0 : 0.3)
                        if isDragging {
                            Text("Dragging")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .animation(.easeInOut, value: isTapping)
                    .animation(.easeInOut, value: isDoubleTapping)
                    .animation(.easeInOut, value: isDragging)
                )
        }
        .padding()
    }
}
