import SwiftUI
import NearbyInteraction
import Network
import Combine

struct ContentView: View {
    @StateObject private var connectionManager: ConnectionManager
    @StateObject private var inputService: InputService
    @State private var selectedTab: Int = 0
    
    init() {
        let manager = ConnectionManager()
        _connectionManager = StateObject(wrappedValue: manager)
        let input = InputService(connectionManager: manager)
        _inputService = StateObject(wrappedValue: input)
    }
    
    var body: some View {
        ZStack {
            if connectionManager.isConnected {
                TabView(selection: $selectedTab) {
                    TrackpadView(inputService: inputService)
                        .tabItem {
                            Label("Trackpad", systemImage: "rectangle.and.hand.point.up.left")
                        }
                        .tag(0)
                        .disabled(!connectionManager.isConnected)
                    
                    KeyboardView(inputService: inputService)
                        .tabItem {
                            Label("Keyboard", systemImage: "keyboard")
                        }
                        .tag(1)
                        .disabled(!connectionManager.isConnected)
                    
                    ConnectionView(connectionManager: connectionManager)
                        .tabItem {
                            Label("Connection", systemImage: "wave.3.right")
                        }
                        .tag(2)
                }
                .onAppear {
                    // Start looking for devices when app launches
                    connectionManager.startDiscovery()
                }
                .onChange(of: connectionManager.isConnected) { _, connected in
                    withAnimation {
                        selectedTab = connected ? 0 : 2
                    }
                }
                .onChange(of: selectedTab) { _, newTab in
                    // If user tries to access a disabled tab, switch to Connection tab
                    if (newTab == 0 || newTab == 1) && !connectionManager.isConnected {
                        withAnimation {
                            selectedTab = 2
                        }
                    }
                }
            } else if connectionManager.isSearching {
                VStack(spacing: 24) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(2)
                    Text("Searching for nearby Macs...")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                // Fallback to ConnectionView if not searching and not connected
                ConnectionView(connectionManager: connectionManager)
            }
        }
    }
}
