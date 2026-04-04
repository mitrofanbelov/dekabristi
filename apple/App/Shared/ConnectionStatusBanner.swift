import SaveCore
import SwiftUI

struct ConnectionStatusBanner: View {
    let status: ConnectionStatus

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.caption)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.12))
    }

    private var title: String {
        switch status {
        case .offline:
            "Offline"
        case .localNetworkAvailable:
            "Network available, checking server"
        case .backendReachable:
            "Server reachable"
        case .backendUnreachable:
            "Internet is up, but the Dekabristi server is unreachable"
        }
    }

    private var color: Color {
        switch status {
        case .backendReachable:
            .green
        case .localNetworkAvailable:
            .orange
        case .backendUnreachable:
            .yellow
        case .offline:
            .red
        }
    }
}
