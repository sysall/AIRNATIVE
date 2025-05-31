import Foundation
import UIKit
import Network
import Combine

// ConnectionManager is in this same directory
public enum MouseButton: String, Codable {
    case left, right, middle
}

public enum MouseGestureType: String, Codable {
    case none           // No gesture
    case pinch         // Pinch gesture
    case rotate        // Rotation gesture
    case swipe         // Swipe gesture
    case smartZoom     // Two-finger double tap
}

public enum SwipeDirection: String, Codable {
    case left, right, up, down
}

public enum MouseEventType: String, Codable {
    case move          // Basic cursor movement
    case click        // Single click
    case doubleClick  // Double click
    case rightClick   // Right click
    case scroll       // Vertical/Horizontal scrolling
    case gesture      // Complex gesture (pinch, rotate, swipe)
    case dragStart    // Start of drag operation
    case dragMove     // Drag movement
    case dragEnd      // End of drag operation
}

public class InputService: ObservableObject {
    private let connectionManager: ConnectionManager
    private let session: URLSession
    
    public init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        self.session = URLSession(configuration: config)
    }
    
    public func sendKeyEvent(keyCode: UInt16, isKeyDown: Bool) {
        guard connectionManager.isConnected else { return }
        
        let data = KeyEventData(keyCode: keyCode, isKeyDown: isKeyDown)
        sendInputToMac(data: data)
    }
    
    public func sendMouseEvent(
        type: MouseEventType,
        deltaX: Float = 0,
        deltaY: Float = 0,
        deltaZ: Float = 0,
        button: MouseButton? = nil,
        rotation: Float = 0,
        gestureType: MouseGestureType = .none,
        gestureScale: Float = 1.0,
        swipeDirection: SwipeDirection? = nil,
        fingerCount: Int = 1
    ) {
        guard connectionManager.isConnected else { return }
        
        let data = MouseEventData(
            type: type,
            deltaX: deltaX,
            deltaY: deltaY,
            deltaZ: deltaZ,
            button: button,
            rotation: rotation,
            gestureType: gestureType,
            gestureScale: gestureScale,
            swipeDirection: swipeDirection,
            fingerCount: fingerCount
        )
        sendInputToMac(data: data)
    }
    
    private func sendInputToMac<T: Encodable>(data: T) {
        // Encode the input data
        guard let encodedData = try? JSONEncoder().encode(data) else { return }
        
        // Send based on connection method
        switch connectionManager.connectionMethod {
        case .network:
            // For network connection, send through NetworkService
            connectionManager.networkService.sendInputData(encodedData)
            
        case .nearbyInteraction:
            // For NearbyInteraction, send through NearbyInteractionService
            guard let macAddress = connectionManager.nearbyService.availableMacs.keys.first else { return }
            
            // Create URL for local network communication
            let urlString = "http://localhost:51234/input"
            guard let url = URL(string: urlString) else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = encodedData
            request.setValue(macAddress, forHTTPHeaderField: "X-Device-Token")
            
            let task = session.dataTask(with: request) { _, _, error in
                if let error = error {
                    print("Failed to send input: \(error.localizedDescription)")
                }
            }
            task.resume()
            
        case .determining:
            // If still determining, do nothing
            break
        }
    }
}

struct KeyEventData: Codable {
    let type: String
    let keyCode: UInt16
    let isKeyDown: Bool
    
    init(keyCode: UInt16, isKeyDown: Bool) {
        self.type = "keyboard"
        self.keyCode = keyCode
        self.isKeyDown = isKeyDown
    }
}

struct MouseEventData: Codable {
    let type: MouseEventType
    let deltaX: Float
    let deltaY: Float
    let deltaZ: Float
    let button: MouseButton?
    let rotation: Float
    let gestureType: MouseGestureType
    let gestureScale: Float        // For pinch gesture
    let swipeDirection: SwipeDirection?
    let fingerCount: Int           // Number of fingers used in gesture
    
    init(type: MouseEventType,
         deltaX: Float = 0,
         deltaY: Float = 0,
         deltaZ: Float = 0,
         button: MouseButton? = nil,
         rotation: Float = 0,
         gestureType: MouseGestureType = .none,
         gestureScale: Float = 1.0,
         swipeDirection: SwipeDirection? = nil,
         fingerCount: Int = 1) {
        self.type = type
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.deltaZ = deltaZ
        self.button = button
        self.rotation = rotation
        self.gestureType = gestureType
        self.gestureScale = gestureScale
        self.swipeDirection = swipeDirection
        self.fingerCount = fingerCount
    }
}
