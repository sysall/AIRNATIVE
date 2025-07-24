import Foundation
import Network
import Combine
import CoreGraphics
import AppKit
import ApplicationServices

// MARK: - Data Types
enum MouseEventType: String, Codable {
    case move, click, doubleClick, rightClick, scroll
    case gesture, dragStart, dragMove, dragEnd
}

enum MouseButton: String, Codable {
    case left, right, middle
}

enum MouseGestureType: String, Codable {
    case none, pinch, rotate, swipe, smartZoom
}

enum SwipeDirection: String, Codable {
    case left, right, up, down
}

struct MouseEventData: Codable {
    let type: String
    let deltaX: Float
    let deltaY: Float
    let deltaZ: Float
    let button: MouseButton?
    let gestureType: MouseGestureType?
    let gestureScale: Float?
    let rotation: Float?
    let swipeDirection: SwipeDirection?
    let fingerCount: Int?
    
    var eventType: MouseEventType? {
        return MouseEventType(rawValue: type)
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

// MARK: - Main Class
public class ConnectionManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published public var isConnected = false
    @Published public var connectionError: String?
    @Published public var isListening = false
    @Published public var connectedDevices: [String: DeviceInfo] = [:]
    @Published public var hasAccessibilityPermission = false
    
    // MARK: - Private Properties
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let bonjourService = "_airnative._tcp"
    private let port: NWEndpoint.Port = 51234
    private let queue = DispatchQueue(label: "com.airnative.mac.network")
    private var cancellables = Set<AnyCancellable>()
    private var permissionCheckTimer: Timer?
    
    public struct DeviceInfo {
        let name: String
        let connection: NWConnection
    }
    
    // MARK: - Initialization
    public override init() {
        super.init()
        print("ConnectionManager initialized")
        setupPermissionChecking()
    }
    
    deinit {
        print("ConnectionManager deinit")
        permissionCheckTimer?.invalidate()
        stopListening()
    }
}

// MARK: - Permission Handling
extension ConnectionManager {
    private func setupPermissionChecking() {
        checkAccessibilityPermission()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkAccessibilityPermission()
        }
    }
    
    private func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        DispatchQueue.main.async { [weak self] in
            let wasGranted = self?.hasAccessibilityPermission ?? false
            self?.hasAccessibilityPermission = trusted
            
            if !wasGranted && trusted {
                print("Accessibility permission granted")
                self?.connectionError = nil
            } else if wasGranted && !trusted {
                print("Accessibility permission revoked")
                self?.connectionError = "Please grant accessibility permissions in System Settings > Privacy & Security > Accessibility"
            }
        }
    }
    
    public func requestAccessibilityPermission() {
        print("Requesting accessibility permission")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Try to trigger the system prompt by attempting a mouse event
            let currentMouseLocation = NSEvent.mouseLocation
            if let mouseMoveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, 
                                          mouseCursorPosition: currentMouseLocation, mouseButton: .left) {
                mouseMoveEvent.post(tap: .cghidEventTap)
            }
            
            DispatchQueue.main.async { [weak self] in
                // Check if we have permission
                let trusted = AXIsProcessTrusted()
                print("Accessibility permission check result: \(trusted)")
                
                if trusted {
                    self?.hasAccessibilityPermission = true
                    self?.connectionError = nil
                } else {
                    self?.hasAccessibilityPermission = false
                    self?.connectionError = "Please grant accessibility permissions in System Settings"
                    
                    // If still no permission, show the prompt and optionally open settings
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
                    if !AXIsProcessTrustedWithOptions(options) {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
            }
        }
    }
}

// MARK: - Network Handling
extension ConnectionManager {
    private func setupNetworkListener() {
        print("Setting up network listener")
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        
        do {
            listener = try NWListener(using: parameters, on: port)
            listener?.service = NWListener.Service(type: bonjourService)
            
            listener?.stateUpdateHandler = { [weak self] state in
                print("Listener state updated: \(state)")
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isListening = true
                        self?.connectionError = nil
                    case .failed(let error):
                        self?.connectionError = "Listener failed: \(error.localizedDescription)"
                        self?.isListening = false
                    case .cancelled:
                        self?.isListening = false
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                print("New connection received")
                self?.handleNewConnection(connection)
            }
            
            listener?.start(queue: queue)
            print("Network listener started")
        } catch {
            print("Failed to start listener: \(error)")
            connectionError = "Failed to start listener: \(error.localizedDescription)"
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        print("Handling new connection")
        connection.stateUpdateHandler = { [weak self] state in
            print("Connection state updated: \(state)")
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.connectionError = nil
                    self?.startReceiving(connection)
                case .failed(let error):
                    self?.connectionError = "Connection failed: \(error.localizedDescription)"
                    self?.cleanupConnection(connection)
                case .cancelled:
                    self?.cleanupConnection(connection)
                default:
                    break
                }
            }
        }
        
        connection.start(queue: queue)
        connections.append(connection)
    }
    
    private func cleanupConnection(_ connection: NWConnection) {
        print("Cleaning up connection")
        connection.cancel()
        if let index = connections.firstIndex(where: { $0 === connection }) {
            connections.remove(at: index)
        }
        if connections.isEmpty {
            isConnected = false
        }
    }
}

// MARK: - Data Handling
extension ConnectionManager {
    private func startReceiving(_ connection: NWConnection) {
        print("Starting to receive data")
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let error = error {
                print("Receive error: \(error)")
                DispatchQueue.main.async {
                    self?.connectionError = "Receive error: \(error.localizedDescription)"
                }
                return
            }
            
            if let data = data {
                print("Received data of length: \(data.count)")
                let messages = data.split(separator: 0x0A)
                for messageData in messages {
                    self?.handleReceivedData(Data(messageData), from: connection)
                }
            }
            
            if !isComplete {
                self?.startReceiving(connection)
            }
        }
    }
    
    private func handleReceivedData(_ data: Data, from connection: NWConnection) {
        print("Raw received data: \(data.count) bytes")
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Received JSON string: \(jsonString)")
        }
        
        do {
            if let mouseData = try? JSONDecoder().decode(MouseEventData.self, from: data),
               let eventType = mouseData.eventType {
                print("Decoded mouse event - type: \(eventType), deltaX: \(mouseData.deltaX), deltaY: \(mouseData.deltaY)")
                handleMouseEvent(mouseData)
                return
            }
            
            if let keyData = try? JSONDecoder().decode(KeyEventData.self, from: data) {
                print("🔍 MAC: Decoded keyboard event - keyCode: \(keyData.keyCode?.description ?? "nil"), character: \(keyData.character ?? "nil"), isKeyDown: \(keyData.isKeyDown)")
                handleKeyEvent(keyData)
                return
            }
            
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: [],
                debugDescription: "Failed to decode as mouse or keyboard event"
            ))
        } catch {
            print("Failed to decode input data: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }
    
    private func handleKeyEvent(_ data: KeyEventData) {
        print("🎹 MAC: Received key event - keyCode: \(data.keyCode?.description ?? "nil"), character: \(data.character ?? "nil"), isKeyDown: \(data.isKeyDown)")
        
        guard hasAccessibilityPermission else {
            print("❌ MAC: Cannot handle key event: No accessibility permission")
            requestAccessibilityPermission()
            return
        }
        
        // Handle character-based input
        if let character = data.character {
            print("📝 MAC: Handling character input: '\(character)'")
            insertText(character)
            return
        }
        
        // Handle key-based input (backward compatibility)
        guard let keyCode = data.keyCode else {
            print("❌ MAC: No keyCode or character provided")
            return
        }
        
        print("⌨️ MAC: Handling key code: \(keyCode)")
        let source = CGEventSource(stateID: .privateState)
        let keyEvent = CGEvent(keyboardEventSource: source,
                             virtualKey: CGKeyCode(keyCode),
                             keyDown: data.isKeyDown)
        
        // Apply modifier flags if provided
        if let modifiers = data.modifiers, !modifiers.isEmpty {
            var flags: CGEventFlags = []
            for modifier in modifiers {
                switch modifier {
                case 0x38: // Shift
                    flags.insert(.maskShift)
                case 0x3A: // Option
                    flags.insert(.maskAlternate)
                case 0x37: // Command
                    flags.insert(.maskCommand)
                case 0x3B: // Control
                    flags.insert(.maskControl)
                default:
                    break
                }
            }
            keyEvent?.flags = flags
        }
        
        keyEvent?.post(tap: CGEventTapLocation.cghidEventTap)
    }
    
    private func insertText(_ text: String) {
        print("🔤 Attempting to insert text: '\(text)'")
        
        // Method 1: Try using pasteboard + Command+V
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string)
        
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Send Command+V to paste
        let source = CGEventSource(stateID: .privateState)
        
        // Command down
        if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) {
            cmdDown.flags = .maskCommand
            cmdDown.post(tap: .cghidEventTap)
        }
        
        // V down
        if let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
            vDown.flags = .maskCommand
            vDown.post(tap: .cghidEventTap)
        }
        
        // V up
        if let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            vUp.post(tap: .cghidEventTap)
        }
        
        // Command up
        if let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) {
            cmdUp.post(tap: .cghidEventTap)
        }
        
        // Restore original pasteboard contents after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let oldContents = oldContents {
                pasteboard.clearContents()
                pasteboard.setString(oldContents, forType: .string)
            }
        }
        
        print("✅ Text inserted using pasteboard method")
    }
}

// MARK: - Mouse Event Handling
extension ConnectionManager {
    private func handleMouseEvent(_ data: MouseEventData) {
        guard let eventType = data.eventType else {
            print("Invalid mouse event type: \(data.type)")
            return
        }
        
        print("Handling mouse event: \(eventType)")
        let screenFrame = NSScreen.main?.frame ?? CGRect.zero
        
        let location: CGPoint
        if case .move = eventType {
            let currentLocation = NSEvent.mouseLocation
            location = CGPoint(
                x: min(max(currentLocation.x + CGFloat(data.deltaX), 0), screenFrame.width),
                y: min(max(screenFrame.height - currentLocation.y + CGFloat(data.deltaY), 0), screenFrame.height)
            )
        } else {
            // For clicks, use the current mouse location without transformation
            let currentLocation = NSEvent.mouseLocation
            location = CGPoint(
                x: currentLocation.x,
                y: currentLocation.y
            )
        }
        
        print("Mouse event details - Location: \(location), Type: \(eventType)")
        
        DispatchQueue.main.async { [weak self] in
            switch eventType {
            case .move:
                if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                         mouseCursorPosition: location, mouseButton: .left) {
                    moveEvent.setIntegerValueField(.eventSourceStateID, value: Int64(CGEventSourceStateID.privateState.rawValue))
                    moveEvent.post(tap: CGEventTapLocation.cghidEventTap)
                }
                
            case .click:
                let currentCursor = NSEvent.mouseLocation
                print("🖱️ Click event - Cursor at: \(currentCursor), Clicking at: \(location)")
                
                let source = CGEventSource(stateID: .privateState)
                if let downEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                                         mouseCursorPosition: location, mouseButton: .left) {
                    downEvent.post(tap: CGEventTapLocation.cghidEventTap)
                    Thread.sleep(forTimeInterval: 0.05)
                    
                    if let upEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                                           mouseCursorPosition: location, mouseButton: .left) {
                        upEvent.post(tap: CGEventTapLocation.cghidEventTap)
                    }
                }
                
            case .doubleClick:
                let source = CGEventSource(stateID: .privateState)
                // Send first click
                if let downEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                                         mouseCursorPosition: location, mouseButton: .left) {
                    downEvent.setIntegerValueField(.mouseEventClickState, value: 1)
                    downEvent.post(tap: CGEventTapLocation.cghidEventTap)
                    Thread.sleep(forTimeInterval: 0.05)
                    
                    if let upEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                                           mouseCursorPosition: location, mouseButton: .left) {
                        upEvent.setIntegerValueField(.mouseEventClickState, value: 1)
                        upEvent.post(tap: CGEventTapLocation.cghidEventTap)
                    }
                }
                
                Thread.sleep(forTimeInterval: 0.05) // Short delay between clicks
                
                // Send second click with click count = 2
                if let downEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                                         mouseCursorPosition: location, mouseButton: .left) {
                    downEvent.setIntegerValueField(.mouseEventClickState, value: 2)
                    downEvent.post(tap: CGEventTapLocation.cghidEventTap)
                    Thread.sleep(forTimeInterval: 0.05)
                    
                    if let upEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                                           mouseCursorPosition: location, mouseButton: .left) {
                        upEvent.setIntegerValueField(.mouseEventClickState, value: 2)
                        upEvent.post(tap: CGEventTapLocation.cghidEventTap)
                    }
                }
                
            case .rightClick:
                let source = CGEventSource(stateID: .privateState)
                if let downEvent = CGEvent(mouseEventSource: source, mouseType: .rightMouseDown,
                                         mouseCursorPosition: location, mouseButton: .right) {
                    downEvent.post(tap: CGEventTapLocation.cghidEventTap)
                    Thread.sleep(forTimeInterval: 0.05)
                    
                    if let upEvent = CGEvent(mouseEventSource: source, mouseType: .rightMouseUp,
                                           mouseCursorPosition: location, mouseButton: .right) {
                        upEvent.post(tap: CGEventTapLocation.cghidEventTap)
                    }
                }
                
            case .dragStart:
                let source = CGEventSource(stateID: .privateState)
                if let downEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                                         mouseCursorPosition: location, mouseButton: .left) {
                    downEvent.post(tap: CGEventTapLocation.cghidEventTap)
                }
                
            case .dragMove:
                let source = CGEventSource(stateID: .privateState)
                if let dragEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged,
                                         mouseCursorPosition: location, mouseButton: .left) {
                    dragEvent.post(tap: CGEventTapLocation.cghidEventTap)
                }
                
            case .dragEnd:
                let source = CGEventSource(stateID: .privateState)
                if let upEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                                       mouseCursorPosition: location, mouseButton: .left) {
                    upEvent.post(tap: CGEventTapLocation.cghidEventTap)
                }
                
            case .gesture, .scroll:
                // Simplified trackpad - no gesture or scroll support
                print("Gesture/scroll events not supported in simplified mode")
            }
        }
    }

}

// MARK: - Public Interface
extension ConnectionManager {
    public func startListening() {
        print("Starting to listen for connections")
        isListening = true
        connectionError = nil
        setupNetworkListener()
    }
    
    public func stopListening() {
        print("Stopping listener")
        isListening = false
        connections.forEach { $0.cancel() }
        connections.removeAll()
        listener?.cancel()
        listener = nil
        connectedDevices.removeAll()
    }
}