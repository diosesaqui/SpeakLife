//
//  CloudKitSyncBadge.swift
//  SpeakLife
//
//  CloudKit sync status badge component
//

import SwiftUI

struct CloudKitSyncBadge: View {
    @ObservedObject var syncMonitor: CloudKitSyncMonitor
    @State private var animateSync = false
    
    var body: some View {
        HStack(spacing: 6) {
            syncIcon
            
            if shouldShowText {
                Text(syncMonitor.statusDescription)
                    .font(.caption2)
                    .foregroundColor(textColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .cornerRadius(12)
        .opacity(shouldShow ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: shouldShow)
    }
    
    @ViewBuilder
    private var syncIcon: some View {
        switch syncMonitor.syncStatus {
        case .syncing:
            Image(systemName: "icloud.and.arrow.up.and.arrow.down")
                .font(.caption)
                .foregroundColor(.blue)
                .rotationEffect(.degrees(animateSync ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: animateSync)
                .onAppear { animateSync = true }
                .onDisappear { animateSync = false }
            
        case .synced:
            Image(systemName: "checkmark.icloud")
                .font(.caption)
                .foregroundColor(.green)
            
        case .error:
            Image(systemName: "exclamationmark.icloud")
                .font(.caption)
                .foregroundColor(.red)
            
        case .accountUnavailable:
            Image(systemName: "icloud.slash")
                .font(.caption)
                .foregroundColor(.orange)
            
        case .unknown:
            Image(systemName: "icloud")
                .font(.caption)
                .foregroundColor(.gray)
            
        case .importing:
            Image(systemName: "icloud.and.arrow.down")
                .font(.caption)
                .foregroundColor(.blue)
                .rotationEffect(.degrees(animateSync ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: animateSync)
                .onAppear { animateSync = true }
                .onDisappear { animateSync = false }
        }
    }
    
    private var backgroundColor: Color {
        switch syncMonitor.syncStatus {
        case .syncing:
            return .blue.opacity(0.1)
        case .synced:
            return .green.opacity(0.1)
        case .error:
            return .red.opacity(0.1)
        case .accountUnavailable:
            return .orange.opacity(0.1)
        case .unknown:
            return .gray.opacity(0.1)
        case .importing:
            return .blue.opacity(0.1)
        }
    }
    
    private var textColor: Color {
        switch syncMonitor.syncStatus {
        case .syncing:
            return .blue
        case .synced:
            return .green
        case .error:
            return .red
        case .accountUnavailable:
            return .orange
        case .unknown:
            return .gray
        case .importing:
            return .blue
        }
    }
    
    private var shouldShow: Bool {
        switch syncMonitor.syncStatus {
        case .unknown:
            return false
        case .synced:
            // Show briefly after sync completes, then fade out
            return syncMonitor.lastSyncDate?.timeIntervalSinceNow ?? -1000 > -5
        case .syncing, .error, .accountUnavailable, .importing:
            return true
        }
    }
    
    private var shouldShowText: Bool {
        switch syncMonitor.syncStatus {
        case .syncing, .error, .accountUnavailable, .importing:
            return true
        case .synced, .unknown:
            return false
        }
    }
}

// MARK: - Compact Version
struct CloudKitSyncBadgeCompact: View {
    @ObservedObject var syncMonitor: CloudKitSyncMonitor
    @State private var animateSync = false
    
    var body: some View {
        Button(action: {
            switch syncMonitor.syncStatus {
            case .error:
                syncMonitor.requestSync()
            default:
                break
            }
        }) {
            syncIcon
                .frame(width: 20, height: 20)
        }
        .disabled(!isErrorState)
        .opacity(shouldShow ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: shouldShow)
    }
    
    @ViewBuilder
    private var syncIcon: some View {
        switch syncMonitor.syncStatus {
        case .syncing:
            Image(systemName: "icloud.and.arrow.up.and.arrow.down")
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .rotationEffect(.degrees(animateSync ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: animateSync)
                .onAppear { animateSync = true }
                .onDisappear { animateSync = false }
            
        case .synced:
            Image(systemName: "checkmark.icloud")
                .font(.system(size: 14))
                .foregroundColor(.green)
            
        case .error:
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 14))
                .foregroundColor(.red)
            
        case .accountUnavailable:
            Image(systemName: "icloud.slash")
                .font(.system(size: 14))
                .foregroundColor(.orange)
            
        case .unknown:
            Image(systemName: "icloud")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
        case .importing:
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .rotationEffect(.degrees(animateSync ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: animateSync)
                .onAppear { animateSync = true }
                .onDisappear { animateSync = false }
        }
    }
    
    private var isErrorState: Bool {
        switch syncMonitor.syncStatus {
        case .error:
            return true
        default:
            return false
        }
    }
    
    private var shouldShow: Bool {
        switch syncMonitor.syncStatus {
        case .unknown:
            return false
        case .synced:
            // Show briefly after sync completes
            return syncMonitor.lastSyncDate?.timeIntervalSinceNow ?? -1000 > -3
        case .syncing, .error, .accountUnavailable, .importing:
            return true
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CloudKitSyncBadge(syncMonitor: CloudKitSyncMonitor())
        CloudKitSyncBadgeCompact(syncMonitor: CloudKitSyncMonitor())
    }
    .padding()
}