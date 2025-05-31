import Foundation
import NearbyInteraction
import CoreBluetooth

public class NearbyInteractionService: NSObject, ObservableObject {
    @Published public var isConnected = false
    @Published public var availableMacs: [String: NISession] = [:]
    @Published public var connectionError: String?
    @Published public var isSearching = false
    
    private var niSession: NISession?
    private var discoveryToken: NIDiscoveryToken?
    
    public override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        // Check both software and hardware support
        guard NISession.isSupported else {
            connectionError = "This device does not support Nearby Interaction. Please use an iPad Pro (2021 or later) with U1 chip."
            return
        }
        
        niSession = NISession()
        
        guard niSession != nil else {
            connectionError = "Failed to initialize Nearby Interaction. Please ensure you have granted necessary permissions."
            return
        }
        niSession?.delegate = self
        
        // Get the discovery token for this device
        discoveryToken = niSession?.discoveryToken
        
        // Start the session
        let config = NINearbyPeerConfiguration(peerToken: discoveryToken!)
        niSession?.run(config)
    }
    
    public func startDiscovery() {
        guard NISession.isSupported else { return }
        isSearching = true
        connectionError = nil
        
        // Configure and run the session
        if let session = niSession, let token = discoveryToken {
            let config = NINearbyPeerConfiguration(peerToken: token)
            session.run(config)
        }
    }
    
    public func stopDiscovery() {
        isSearching = false
        niSession?.invalidate()
        availableMacs.removeAll()
    }
}

extension NearbyInteractionService: NISessionDelegate {
    public func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        // Handle updates about nearby devices
        DispatchQueue.main.async {
            for object in nearbyObjects {
                if let distance = object.distance {
                    // If device is within reasonable range (2 meters)
                    if distance < 2.0 {
                        // Add to available devices if not already present
                        if !self.availableMacs.keys.contains(object.discoveryToken.description) {
                            self.availableMacs[object.discoveryToken.description] = session
                        }
                    }
                }
            }
        }
    }
    
    public func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // Remove devices that are no longer nearby
        DispatchQueue.main.async {
            for object in nearbyObjects {
                self.availableMacs.removeValue(forKey: object.discoveryToken.description)
            }
        }
    }
    
    public func session(_ session: NISession, didInvalidateWith error: Error) {
        DispatchQueue.main.async {
            self.connectionError = error.localizedDescription
            self.isSearching = false
        }
    }
}