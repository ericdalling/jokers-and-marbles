import SwiftUI
import CoreImage.CIFilterBuiltins
import GameCore

struct HostModeView: View {
    @StateObject private var host = HostCoordinator()
    @State private var confirmClose = false
    let close: () -> Void
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Jokers & Marbles").font(.system(.largeTitle, design: .serif).italic())
                Text("Host Mode").font(.headline)
                if let state = host.state {
                    if state.activeSeat != nil {
                        PublicGameplayView(state: state, connected: host.connectedPlayers)

                    } else {
                        HStack(spacing: 30) {
                            if let image = qr(host.roomCode) {
                                Image(decorative: image, scale: 1).interpolation(.none).resizable()
                                    .frame(width: 180, height: 180).padding(12).background(.white)
                            }
                            VStack {
                                Text("Scan to join")
                                Text(host.roomCode).font(.system(size: 44, weight: .bold, design: .monospaced))
                                Text("Or enter the room code")
                            }
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                            ForEach(state.members) { member in
                                VStack {
                                    Circle().fill(colors[member.color]).frame(width: 32, height: 32)
                                    Text(member.name).font(.headline)
                                    Text(!host.connectedPlayers.contains(member.id) ? "Disconnected" : member.ready ? "Ready" : "Not ready")
                                    if let partner = state.members.first(where: { $0.id == member.partner }) {
                                        Text("With " + partner.name).font(.caption)
                                    }
                                }.padding().frame(maxWidth: .infinity)
                                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(colors[member.color].opacity(0.7), lineWidth: 2))
                            }
                            ForEach(0..<max(0, 3 - state.members.count), id: \.self) { _ in
                                VStack { Image(systemName: "cpu"); Text("Robot • auto-fill") }.padding()
                            }
                        }
                        Text("\(state.members.count) of 6 players joined")
                        if [4, 6].contains(state.members.count) { Button(state.individual ? "Switch to teams" : "Switch to individual") { host.configureTeams(state.individual) } }
                        Button("Start game") { host.start() }
                            .disabled(state.members.isEmpty || !state.members.allSatisfy { $0.ready && host.connectedPlayers.contains($0.id) })
                    }
                    Button("Close room") { confirmClose = true }
                } else {
                    Button("Open new room") { host.open() }
                    Button("Back", action: close)
                }
                if !host.error.isEmpty { Text(host.error).foregroundStyle(.red) }
            }.padding(30)
        }
        .foregroundStyle(Color(red: 0.98, green: 0.88, blue: 0.72))
        .background(LinearGradient(colors: [Color(red: 0.27, green: 0.14, blue: 0.07), Color(red: 0.09, green: 0.04, blue: 0.02)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        .confirmationDialog("End this room for everyone?", isPresented: $confirmClose) {
            Button("End room", role: .destructive) { host.close() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Allow nearby controller to connect?", isPresented: Binding(get: { host.pendingConnection }, set: { if !$0 && host.pendingConnection { host.approveConnection(false) } })) {
            Button("Allow") { host.approveConnection(true) }
            Button("Deny", role: .cancel) { host.approveConnection(false) }
        } message: { Text("Approve only when someone you know is joining your room.") }
        .onAppear { if host.state == nil { host.open() } }
        .onDisappear { host.close() }
    }

    private func qr(_ code: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("jokersmarbles://join?code=\(code)&secret=\(host.roomSecret)".utf8)
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }
}
