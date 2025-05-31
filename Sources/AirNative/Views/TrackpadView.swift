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
    @State private var lastTouchCount = 0
    @State private var lastClickLocation = CGPoint.zero
    @State private var twoFingerTranslation = CGSize.zero

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Basic touch handling for movement and clicks
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($dragState) { value, state, _ in
                            // Only handle single finger gestures here
                            guard lastTouchCount <= 1 else { return }
                            
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
                // Two finger scrolling
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Only handle two finger gestures
                            guard lastTouchCount == 2 else { return }
                            
                            let delta = CGSize(
                                width: value.translation.width - twoFingerTranslation.width,
                                height: value.translation.height - twoFingerTranslation.height
                            )
                            
                            inputService.sendMouseEvent(
                                type: .scroll,
                                deltaX: Float(delta.width),
                                deltaY: Float(delta.height),
                                fingerCount: 2
                            )
                            
                            twoFingerTranslation = value.translation
                        }
                        .onEnded { _ in
                            twoFingerTranslation = .zero
                        }
                )
                // Enhanced tap gesture handling
                .gesture(
                    SpatialTapGesture(count: 1)
                        .onEnded { _ in
                            let now = Date()
                            // Only handle single finger taps
                            guard lastTouchCount <= 1 else { return }
                            
                            if now.timeIntervalSince(lastGestureTime) < 0.3 {
                                inputService.sendMouseEvent(type: .doubleClick, button: .left)
                                isDoubleTapping = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isDoubleTapping = false
                                }
                            } else {
                                inputService.sendMouseEvent(type: .click, button: .left)
                                isTapping = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isTapping = false
                                }
                            }
                            lastGestureTime = now
                        }
                )
                // Improved right-click handling
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.4)
                        .onEnded { _ in
                            // Only handle single finger long press
                            guard lastTouchCount <= 1 else { return }
                            inputService.sendMouseEvent(type: .rightClick, button: .right)
                        }
                )
                // Enhanced two finger gestures (pinch, rotate)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                // Only handle two finger gestures
                                guard lastTouchCount == 2 else { return }
                                
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
                            },
                        RotationGesture()
                            .onChanged { angle in
                                // Only handle two finger gestures
                                guard lastTouchCount == 2 else { return }
                                
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
                )
                // Three finger swipe detection
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            // Only handle three finger swipes
                            guard lastTouchCount == 3 else { return }
                            
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
