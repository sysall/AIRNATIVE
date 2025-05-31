import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Status Section
            VStack(alignment: .leading, spacing: 10) {
                Text("Status")
                    .font(.headline)
                
                HStack {
                    Circle()
                        .fill(connectionManager.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(connectionManager.isConnected ? "Connected" : "Not Connected")
                        .foregroundColor(connectionManager.isConnected ? .green : .red)
                }
                
                if let error = connectionManager.connectionError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            .cornerRadius(10)
            
            // Accessibility Permission Section
            VStack(alignment: .leading, spacing: 10) {
                Text("Accessibility Permission")
                    .font(.headline)
                
                HStack {
                    Circle()
                        .fill(connectionManager.hasAccessibilityPermission ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(connectionManager.hasAccessibilityPermission ? "Granted" : "Required")
                        .foregroundColor(connectionManager.hasAccessibilityPermission ? .green : .red)
                }
                
                if !connectionManager.hasAccessibilityPermission {
                    Text("Please grant accessibility permissions in System Settings > Privacy & Security > Accessibility")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Button("Request Permission") {
                        connectionManager.requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.vertical, 5)
                    
                    Button("Open System Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            .cornerRadius(10)
            
            // Connected Devices Section
            if !connectionManager.connectedDevices.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Connected Devices")
                        .font(.headline)
                    
                    ForEach(Array(connectionManager.connectedDevices.keys), id: \.self) { deviceId in
                        if let device = connectionManager.connectedDevices[deviceId] {
                            HStack {
                                Text(device.name)
                                Spacer()
                                Text("Wi-Fi")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.windowBackgroundColor))
                .cornerRadius(10)
            }
            
            Spacer()
            
            // Control Buttons
            HStack {
                Button(action: {
                    if connectionManager.isListening {
                        connectionManager.stopListening()
                    } else {
                        connectionManager.startListening()
                    }
                }) {
                    Text(connectionManager.isListening ? "Stop Listening" : "Start Listening")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .padding()
        .frame(width: 400, height: 500)
        .onAppear {
            print("ContentView appeared")
            // Request accessibility permissions when the view appears
            connectionManager.requestAccessibilityPermission()
            // Start listening when the view appears
            connectionManager.startListening()
        }
        .onDisappear {
            print("ContentView disappeared")
            // Stop listening when the view disappears
            connectionManager.stopListening()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ConnectionManager())
    }
}