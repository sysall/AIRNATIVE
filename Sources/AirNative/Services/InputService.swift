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
    private let inputQueue = DispatchQueue(label: "com.airnative.input", qos: .userInteractive)
    private let inputSemaphore = DispatchSemaphore(value: 1)
    
    public init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        self.session = URLSession(configuration: config)
    }
    
    public func sendKeyEvent(keyCode: UInt16, isKeyDown: Bool, modifiers: [UInt16] = []) {
        guard connectionManager.isConnected else { return }
        
        let data = KeyEventData(keyCode: keyCode, isKeyDown: isKeyDown, modifiers: modifiers.isEmpty ? nil : modifiers)
        sendInputToMac(data: data)
    }
    
    public func sendCharacter(_ character: String) {
        guard connectionManager.isConnected else { return }
        
        let data = KeyEventData(character: character)
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
        
        // Determine the button type based on finger count
        let buttonType: MouseButton? = {
            switch fingerCount {
            case 1:
                return .left
            case 2:
                return .right
            default:
                return button
            }
        }()
        
        let data = MouseEventData(
            type: type,
            deltaX: deltaX,
            deltaY: deltaY,
            deltaZ: deltaZ,
            button: buttonType,
            rotation: rotation,
            gestureType: gestureType,
            gestureScale: gestureScale,
            swipeDirection: swipeDirection,
            fingerCount: fingerCount
        )
        
        // Debug output
        print("🖱️ iOS: Sending mouse event - type: \(type), button: \(buttonType?.rawValue ?? "nil"), fingerCount: \(fingerCount)")
        
        sendInputToMac(data: data)
    }
    
    private func sendInputToMac<T: Encodable>(data: T) {
        // Use a serial queue to ensure sequential processing of input events
        inputQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Wait for the semaphore to ensure sequential processing
            self.inputSemaphore.wait()
            
        // Encode the input data
            guard let encodedData = try? JSONEncoder().encode(data) else {
                self.inputSemaphore.signal()
                return
            }
        
        // Send based on connection method
            switch self.connectionManager.connectionMethod {
        case .network:
            // For network connection, send through NetworkService
                self.sendNetworkData(encodedData)
            
        case .nearbyInteraction:
            // For NearbyInteraction, send through NearbyInteractionService
                self.sendNearbyInteractionData(encodedData)
                
            case .determining:
                // If still determining, do nothing
                self.inputSemaphore.signal()
                break
            }
        }
    }
    
    private func sendNetworkData(_ encodedData: Data) {
        // Create a completion group to wait for the network operation
        let group = DispatchGroup()
        group.enter()
        
        // Send the data
        connectionManager.networkService.sendInputData(encodedData) {
            group.leave()
        }
        
        // Wait for completion before allowing next input
        group.wait()
        
        // Remove the delay to improve responsiveness
        // Thread.sleep(forTimeInterval: 0.01) // 10ms delay
        
        inputSemaphore.signal()
    }
    
    private func sendNearbyInteractionData(_ encodedData: Data) {
        guard let macAddress = connectionManager.nearbyService.availableMacs.keys.first else {
            inputSemaphore.signal()
            return
        }
            
            // Create URL for local network communication
            let urlString = "http://localhost:51234/input"
        guard let url = URL(string: urlString) else {
            inputSemaphore.signal()
            return
        }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = encodedData
            request.setValue(macAddress, forHTTPHeaderField: "X-Device-Token")
        
        // Create a completion group to wait for the network operation
        let group = DispatchGroup()
        group.enter()
            
            let task = session.dataTask(with: request) { _, _, error in
                if let error = error {
                    print("Failed to send input: \(error.localizedDescription)")
                }
            group.leave()
            }
            task.resume()
            
        // Wait for completion before allowing next input
        group.wait()
        
        // Remove the delay to improve responsiveness
        // Thread.sleep(forTimeInterval: 0.01) // 10ms delay
        
        inputSemaphore.signal()
    }
}

struct KeyEventData: Codable {
    let type: String
    let keyCode: UInt16?
    let isKeyDown: Bool
    let modifiers: [UInt16]?
    let character: String?
    
    // For character-based input
    init(character: String) {
        self.type = "keyboard"
        self.keyCode = nil
        self.isKeyDown = true
        self.modifiers = nil
        self.character = character
    }
    
    // For key-based input (backward compatibility)
    init(keyCode: UInt16, isKeyDown: Bool, modifiers: [UInt16]? = nil) {
        self.type = "keyboard"
        self.keyCode = keyCode
        self.isKeyDown = isKeyDown
        self.modifiers = modifiers
        self.character = nil
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
