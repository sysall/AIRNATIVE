import SwiftUI
import Network

@main
struct AirNativeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Make sure we have all required permissions
                    requestPermissionsIfNeeded()
                }
        }
    }
    
    private func requestPermissionsIfNeeded() {
        // Request local network permission by attempting to create a local server
        let listener = try? NWListener(using: .tcp, on: 51234)
        listener?.start(queue: .main)
        listener?.cancel()
    }
}
