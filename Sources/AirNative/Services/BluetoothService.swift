import Foundation
import MultipeerConnectivity

class BluetoothService: NSObject, ObservableObject {
    // Service type must follow Bonjour naming conventions
    private let serviceType = "air-remote"
    private var peerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    @Published var isConnected = false
    @Published var availablePeers: [MCPeerID] = []
    @Published var connectionError: String?
    @Published var isMacDevice = false
    @Published var isSearching = false
    
    private var isAdvertising = false
    private var isBrowsing = false
    private var retryCount = 0
    private let maxRetries = 3
    
    private var discoveryWorkItem: DispatchWorkItem?
    
    override init() {
        // Create a unique identifier for this device
        let uuid = UUID().uuidString.prefix(4)
        let deviceName = "\(UIDevice.current.name)-\(uuid)"
        self.peerID = MCPeerID(displayName: deviceName)
        
        // Initialize session with security
        self.session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        
        super.init()
        
        session.delegate = self
        
        // Start discovery after initialization is complete
        DispatchQueue.main.async { [weak self] in
            self?.startDiscovery()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopDiscovery()
        disconnect()
    }
    
    @objc private func handleBackgroundTransition() {
        stopDiscovery()
        disconnect()  // Make sure to disconnect when going to background
    }
    
    @objc private func handleForegroundTransition() {
        retryCount = 0  // Reset retry count when coming back to foreground
        startDiscovery()
    }
    
    func startDiscovery() {
        guard !isSearching else { return }
        
        print("Starting discovery and advertising...")
        isSearching = true
        connectionError = nil
        
        // Cancel any pending discovery work
        discoveryWorkItem?.cancel()
        
        // Create new discovery work
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Add basic discovery info
            let discoveryInfo = [
                "type": "iPad",
                "name": UIDevice.current.name,
                "uuid": UUID().uuidString
            ]
            
            // Initialize and start advertising
            self.advertiser = MCNearbyServiceAdvertiser(
                peer: self.peerID,
                discoveryInfo: discoveryInfo,
                serviceType: self.serviceType
            )
            self.advertiser?.delegate = self
            self.advertiser?.startAdvertisingPeer()
            self.isAdvertising = true
            
            // Initialize and start browsing
            self.browser = MCNearbyServiceBrowser(
                peer: self.peerID,
                serviceType: self.serviceType
            )
            self.browser?.delegate = self
            self.browser?.startBrowsingForPeers()
            self.isBrowsing = true
        }
        
        // Store and execute the work item
        discoveryWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
    
    func stopDiscovery() {
        print("Stopping discovery and advertising...")
        
        // Cancel any pending discovery work
        discoveryWorkItem?.cancel()
        discoveryWorkItem = nil
        
        // Stop advertising if active
        if isAdvertising {
            advertiser?.stopAdvertisingPeer()
            advertiser?.delegate = nil
            advertiser = nil
            isAdvertising = false
        }
        
        // Stop browsing if active
        if isBrowsing {
            browser?.stopBrowsingForPeers()
            browser?.delegate = nil
            browser = nil
            isBrowsing = false
        }
        
        // Clear state
        isSearching = false
        availablePeers.removeAll()
        connectionError = nil
    }
    
    func connectToPeer(_ peer: MCPeerID) {
        guard let browser = self.browser else {
            connectionError = "Connection service not initialized"
            startDiscovery()
            return
        }
        
        // Send device info as context for authentication
        let deviceInfo = [
            "deviceType": "iPad",
            "deviceName": UIDevice.current.name,
            "deviceID": UIDevice.current.identifierForVendor?.uuidString ?? "",
            "appName": Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "AirNative"
        ]
        
        if let contextData = try? JSONSerialization.data(withJSONObject: deviceInfo) {
            print("Inviting peer: \(peer.displayName)")
            browser.invitePeer(peer, to: session, withContext: contextData, timeout: 30)
        }
    }
    
    func disconnect() {
        session.disconnect()
        isConnected = false
        isMacDevice = false
        connectionError = nil
        stopDiscovery()
    }
    
    func sendInputData(_ data: Data) {
        guard isConnected else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

// MARK: - MCSessionDelegate
extension BluetoothService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("Connected to peer: \(peerID.displayName)")
                self.isConnected = true
                self.connectionError = nil
                
                // Check if the connected device is a Mac
                if peerID.displayName.contains("MacBook") || peerID.displayName.contains("iMac") {
                    self.isMacDevice = true
                    
                    // Send a test message to verify connection
                    let testMessage = "connection_test"
                    if let data = testMessage.data(using: .utf8) {
                        try? session.send(data, toPeers: [peerID], with: .reliable)
                    }
                }
                self.stopDiscovery() // Stop looking for more peers once connected
                
            case .notConnected:
                print("Disconnected from peer: \(peerID.displayName)")
                self.isConnected = false
                self.isMacDevice = false
                if self.connectionError == nil {
                    self.connectionError = "Disconnected from Mac"
                }
                self.startDiscovery() // Start looking for peers again
                
            case .connecting:
                print("Connecting to peer: \(peerID.displayName)")
                self.connectionError = nil
                
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle acknowledgments or responses from Mac if needed
        if let response = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                if response == "error" {
                    self.connectionError = "Failed to execute command on Mac"
                }
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension BluetoothService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            // Try to parse the context data
            var deviceInfo: [String: String] = [:]
            if let contextData = context {
                deviceInfo = (try? JSONSerialization.jsonObject(with: contextData) as? [String: String]) ?? [:]
            }
            
            // Create alert for user authorization
            let deviceName = deviceInfo["deviceName"] ?? peerID.displayName
            let deviceType = deviceInfo["deviceType"] ?? "Unknown device"
            let appName = deviceInfo["appName"] ?? "Unknown app"
            
            // Only show alert for Mac devices
            if peerID.displayName.contains("MacBook") || peerID.displayName.contains("iMac") {
                let alert = UIAlertController(
                    title: "Connection Request",
                    message: "\(deviceName) (\(deviceType)) wants to connect to control your Mac through \(appName). Do you want to accept?",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "Accept", style: .default) { _ in
                    self.connectionError = nil
                    invitationHandler(true, self.session)
                })
                
                alert.addAction(UIAlertAction(title: "Decline", style: .cancel) { _ in
                    self.connectionError = "Connection declined by user"
                    invitationHandler(false, nil)
                })
                
                // Get the top-most view controller to present the alert
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let viewController = windowScene.windows.first?.rootViewController {
                    viewController.present(alert, animated: true)
                }
            } else {
                self.connectionError = "Received invitation from non-Mac device"
                invitationHandler(false, nil)
            }
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async {
            self.connectionError = "Failed to start advertising: \(error.localizedDescription)"
            
            // Retry logic
            if self.retryCount < self.maxRetries {
                self.retryCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    print("Retrying Bluetooth advertising... Attempt \(self.retryCount)")
                    self.stopDiscovery()
                    self.startDiscovery()
                }
            } else {
                self.isSearching = false
                self.connectionError = "Unable to advertise service. Please check your Bluetooth and network settings."
            }
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension BluetoothService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async {
            // Only add the peer if it's not already in the list and appears to be a Mac
            if !self.availablePeers.contains(peerID) &&
               (peerID.displayName.contains("MacBook") || 
                peerID.displayName.contains("iMac") || 
                info?["device"] == "Mac") {
                self.availablePeers.append(peerID)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.availablePeers.removeAll { $0 == peerID }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            self.connectionError = "Failed to start browsing: \(error.localizedDescription)"
            
            // Retry logic
            if self.retryCount < self.maxRetries {
                self.retryCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    print("Retrying Bluetooth discovery... Attempt \(self.retryCount)")
                    self.stopDiscovery()
                    self.startDiscovery()
                }
            } else {
                self.isSearching = false
                self.connectionError = "Unable to search for devices. Please check your Bluetooth and network settings."
            }
        }
    }
}
