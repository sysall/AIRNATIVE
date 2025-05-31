import SwiftUI
import MultipeerConnectivity
import NearbyInteraction
import Network
import Combine

// Relative import to ensure we can access the Services directory
@_exported import struct Foundation.Notification
@_exported import class Foundation.NotificationCenter

struct ConnectionView: View {
    @ObservedObject var connectionManager: ConnectionManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            if connectionManager.isConnected {
                // Connected state
                VStack(spacing: 20) {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "macbook.and.ipad")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                        )
                    
                    Text("Connected to Mac")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text(connectionManager.connectionMethod.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    if let error = connectionManager.connectionError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    
                    Button(action: {
                        connectionManager.stopDiscovery()
                    }) {
                        Text("Disconnect")
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red, lineWidth: 1)
                            )
                    }
                }
            } else {
                // Discovery state
                VStack(spacing: 25) {
                    Circle()
                        .fill(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "wave.3.right")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                                .symbolEffect(.pulse, options: .repeating)
                        )
                    
                    Text("Available Macs")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text(connectionManager.connectionMethod.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    if !hasAvailableMacs {
                        VStack(spacing: 10) {
                            if connectionManager.isSearching {
                                Text("Looking for nearby Macs...")
                                    .foregroundColor(.gray)
                                Text("Make sure your Mac is nearby\nand has required services enabled")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("No Macs Found")
                                    .foregroundColor(.gray)
                                    .font(.headline)
                                
                                if let error = connectionManager.connectionError {
                                    Text(error)
                                        .foregroundColor(.red)
                                        .font(.subheadline)
                                        .multilineTextAlignment(.center)
                                        .padding()
                                }
                                
                                Button(action: {
                                    connectionManager.startDiscovery()
                                }) {
                                    Label("Try Again", systemImage: "arrow.clockwise")
                                        .foregroundColor(.blue)
                                }
                                .padding(.top)
                            }
                        }
                        .padding(.top)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                // Show NearbyInteraction devices
                                ForEach(Array(connectionManager.nearbyService.availableMacs.keys), id: \.self) { macId in
                                    MacDeviceRow(
                                        name: "Mac (Nearby)",
                                        type: .nearbyInteraction
                                    ) {
                                        guard let session = connectionManager.nearbyService.availableMacs[macId] else { return }
                                        session.run(NINearbyPeerConfiguration(peerToken: session.discoveryToken!))
                                    }
                                }
                                
                                // Show Network devices
                                ForEach(Array(connectionManager.networkService.availableMacs.keys), id: \.self) { macId in
                                    MacDeviceRow(
                                        name: "Mac (Network)",
                                        type: .network
                                    ) {
                                        guard let result = connectionManager.networkService.availableMacs[macId] else { return }
                                        connectionManager.networkService.connectToMac(endpoint: result.endpoint)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 300)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colorScheme == .dark ? Color.black : Color.gray.opacity(0.05))
        .animation(.easeInOut, value: connectionManager.isConnected)
    }
    
    private var hasAvailableMacs: Bool {
        !connectionManager.nearbyService.availableMacs.isEmpty ||
        !connectionManager.networkService.availableMacs.isEmpty
    }
}

struct MacDeviceRow: View {
    let name: String
    let type: ConnectionManager.ConnectionMethod
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "macbook")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(name)
                    .font(.headline)
                
                Spacer()
                
                Text(type.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
