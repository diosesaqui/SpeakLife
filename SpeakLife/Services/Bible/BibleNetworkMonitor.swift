//
//  BibleNetworkMonitor.swift
//  SpeakLife
//
//  Created by SpeakLife Team
//

import Foundation
import Network
import SwiftUI

class BibleNetworkMonitor: ObservableObject {
    static let shared = BibleNetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "BibleNetworkMonitor")
    
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
        case unavailable
        
        var displayName: String {
            switch self {
            case .wifi:
                return "Wi-Fi"
            case .cellular:
                return "Cellular"
            case .ethernet:
                return "Ethernet"
            case .unknown:
                return "Unknown"
            case .unavailable:
                return "No Connection"
            }
        }
        
        var icon: String {
            switch self {
            case .wifi:
                return "wifi"
            case .cellular:
                return "antenna.radiowaves.left.and.right"
            case .ethernet:
                return "cable.connector"
            case .unknown:
                return "questionmark.circle"
            case .unavailable:
                return "wifi.slash"
            }
        }
    }
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.updateConnectionType(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func updateConnectionType(_ path: NWPath) {
        if path.status == .satisfied {
            if path.usesInterfaceType(.wifi) {
                connectionType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                connectionType = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                connectionType = .ethernet
            } else {
                connectionType = .unknown
            }
        } else {
            connectionType = .unavailable
        }
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Network Status Banner
struct NetworkStatusBanner: View {
    @ObservedObject private var monitor = BibleNetworkMonitor.shared
    @State private var showBanner = false
    
    var body: some View {
        VStack {
            if !monitor.isConnected && showBanner {
                HStack {
                    Image(systemName: monitor.connectionType.icon)
                        .font(.system(size: 16))
                    
                    Text("No Internet Connection")
                        .font(.system(size: 14, weight: .medium))
                    
                    Spacer()
                    
                    Text("Bible content unavailable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.white)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: showBanner)
        .onChange(of: monitor.isConnected) { newValue in
            withAnimation {
                if !newValue {
                    showBanner = true
                } else {
                    // Delay hiding to show reconnection
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showBanner = false
                    }
                }
            }
        }
    }
}