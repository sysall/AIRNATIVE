import Foundation
import NearbyInteraction
import Network
import Combine

// Make sure this is accessible to all files that need it
public final class ConnectionManager: NSObject, ObservableObject {
    @Published public var isConnected = false
    @Published public var connectionError: String?
    @Published public var isSearching = false
    @Published public var connectionMethod: ConnectionMethod = .determining
    
    public let nearbyService: NearbyInteractionService
    public let networkService: NetworkService
    private var cancellables = Set<AnyCancellable>()
    
    public enum ConnectionMethod: String {
        case determining
        case nearbyInteraction
        case network
        
        public var description: String {
            switch self {
            case .determining: return "Checking device compatibility..."
            case .nearbyInteraction: return "Using Nearby Interaction"
            case .network: return "Using Wi-Fi"
            }
        }
    }
    
    public override init() {
        self.nearbyService = NearbyInteractionService()
        self.networkService = NetworkService()
        
        super.init()
        setupObservers()
        determineConnectionMethod()
    }
    
    private func setupObservers() {
        // Observe NearbyInteractionService
        nearbyService.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                if self?.connectionMethod == .nearbyInteraction {
                    self?.isConnected = connected
                }
            }
            .store(in: &cancellables)
        
        nearbyService.$connectionError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if self?.connectionMethod == .nearbyInteraction {
                    self?.connectionError = error
                }
            }
            .store(in: &cancellables)
        
        // Observe NetworkService
        networkService.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                if self?.connectionMethod == .network {
                    self?.isConnected = connected
                }
            }
            .store(in: &cancellables)
        
        networkService.$connectionError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if self?.connectionMethod == .network {
                    self?.connectionError = error
                }
            }
            .store(in: &cancellables)
    }
    
    private func determineConnectionMethod() {
        if NISession.isSupported {
            connectionMethod = .nearbyInteraction
            startNearbyInteractionDiscovery()
        } else {
            connectionMethod = .network
            startNetworkDiscovery()
        }
    }
    
    public func startDiscovery() {
        isSearching = true
        connectionError = nil
        
        switch connectionMethod {
        case .nearbyInteraction:
            startNearbyInteractionDiscovery()
        case .network:
            startNetworkDiscovery()
        case .determining:
            determineConnectionMethod()
        }
    }
    
    public func stopDiscovery() {
        isSearching = false
        nearbyService.stopDiscovery()
        networkService.stopDiscovery()
    }
    
    private func startNearbyInteractionDiscovery() {
        nearbyService.startDiscovery()
    }
    
    private func startNetworkDiscovery() {
        networkService.startDiscovery()
    }
    
    deinit {
        stopDiscovery()
        cancellables.removeAll()
    }
}
