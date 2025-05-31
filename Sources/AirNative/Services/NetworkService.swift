import Foundation
import Network
import Combine

public class NetworkService: NSObject, ObservableObject {
    @Published public var isConnected = false
    @Published public var availableMacs: [String: NWBrowser.Result] = [:]
    @Published public var connectionError: String?
    @Published public var isSearching = false
    
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private let bonjourService = "_airnative._tcp"
    private let port: NWEndpoint.Port = 51234
    
    private let queue = DispatchQueue(label: "com.airnative.network")
    private var inputBuffer = Data()
    private var retryCount = 0
    private let maxRetries = 3
    private var retryTimer: Timer?
    
    public override init() {
        super.init()
        print("NetworkService initialized")
    }
    
    // Send mouse or keyboard event data
    public func sendInputData(_ data: Data) {
        guard isConnected else {
            print("Cannot send data: Not connected")
            return
        }
        send(data: data)
    }
    
    private func setupBonjourDiscovery() {
        print("Setting up Bonjour discovery")
        // Create NWParameters for TCP
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        
        // Browse for services
        let browserDescriptor = NWBrowser.Descriptor.bonjour(type: bonjourService, domain: "local")
        let browser = NWBrowser(for: browserDescriptor, using: parameters)
        
        browser.stateUpdateHandler = { [weak self] state in
            print("Browser state updated: \(state)")
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isSearching = true
                    self?.connectionError = nil
                    self?.retryCount = 0 // Reset retry count on success
                case .failed(let error):
                    print("Browser failed: \(error)")
                    self?.handleBrowserFailure(error)
                case .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }
        
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            print("Browse results changed: \(results.count) results")
            DispatchQueue.main.async {
                self?.handleBrowseResults(results)
            }
        }
        
        self.browser = browser
        browser.start(queue: queue)
    }
    
    private func handleBrowserFailure(_ error: Error) {
        connectionError = "Discovery failed: \(error.localizedDescription)"
        isSearching = false
        
        // Retry logic
        if retryCount < maxRetries {
            retryCount += 1
            print("Retrying discovery... Attempt \(retryCount)")
            
            // Cancel any existing retry timer
            retryTimer?.invalidate()
            
            // Schedule retry after delay
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                self?.startDiscovery()
            }
        } else {
            print("Max retry attempts reached")
            connectionError = "Unable to discover Mac. Please check your network settings and permissions."
        }
    }
    
    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            if case .service(let name, _, _, _) = result.endpoint {
                print("Found service: \(name)")
                if !availableMacs.keys.contains(name) {
                    availableMacs[name] = result
                    // Automatically connect to the first Mac found
                    if availableMacs.count == 1 {
                        connectToMac(endpoint: result.endpoint)
                    }
                }
            }
        }
    }
    
    public func connectToMac(endpoint: NWEndpoint) {
        print("Connecting to Mac: \(endpoint)")
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        
        let connection = NWConnection(to: endpoint, using: parameters)
        connection.stateUpdateHandler = { [weak self] state in
            print("Connection state updated: \(state)")
            DispatchQueue.main.async {
                self?.handleConnectionState(state)
            }
        }
        
        self.connection = connection
        connection.start(queue: queue)
    }
    
    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            print("Connection ready")
            isConnected = true
            connectionError = nil
            startReceiving()
        case .failed(let error):
            print("Connection failed: \(error)")
            isConnected = false
            connectionError = "Connection failed: \(error.localizedDescription)"
            cleanup()
        case .cancelled:
            print("Connection cancelled")
            isConnected = false
            connectionError = nil
            cleanup()
        default:
            break
        }
    }
    
    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let error = error {
                print("Receive error: \(error)")
                DispatchQueue.main.async {
                    self?.connectionError = "Receive error: \(error.localizedDescription)"
                }
                return
            }
            
            if let data = data {
                print("Received data of length: \(data.count)")
                self?.inputBuffer.append(data)
                self?.processInputBuffer()
            }
            
            if !isComplete {
                self?.startReceiving()
            }
        }
    }
    
    private func processInputBuffer() {
        while !inputBuffer.isEmpty {
            if let messageEndIndex = inputBuffer.firstIndex(of: 0x0A) {
                let messageData = inputBuffer[..<messageEndIndex]
                if let message = String(data: messageData, encoding: .utf8) {
                    print("Received message: \(message)")
                }
                inputBuffer.removeSubrange(...messageEndIndex)
            } else {
                break
            }
        }
    }
    
    public func send(data: Data) {
        // Add a newline character to separate messages
        var messageData = data
        messageData.append(0x0A) // Add newline character
        
        connection?.send(content: messageData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("Send error: \(error)")
                DispatchQueue.main.async {
                    self?.connectionError = "Send error: \(error.localizedDescription)"
                }
            } else {
                print("Data sent successfully")
            }
        })
    }
    
    public func startDiscovery() {
        print("Starting discovery")
        retryTimer?.invalidate()
        retryTimer = nil
        setupBonjourDiscovery()
        isSearching = true
    }
    
    public func stopDiscovery() {
        print("Stopping discovery")
        retryTimer?.invalidate()
        retryTimer = nil
        browser?.cancel()
        cleanup()
        isSearching = false
    }
    
    private func cleanup() {
        connection?.cancel()
        connection = nil
        availableMacs.removeAll()
    }
    
    deinit {
        print("NetworkService deinit")
        retryTimer?.invalidate()
        cleanup()
    }
}
