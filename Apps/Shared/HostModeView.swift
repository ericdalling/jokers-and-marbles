import SwiftUI
import CoreImage.CIFilterBuiltins
import GameCore

struct HostModeView: View {
    @StateObject private var host = HostCoordinator()
    @State private var confirmClose = false
    let close: () -> Void
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]

    var body: some View {
        GeometryReader { geometry in
        ScrollView {
            VStack(spacing: 14) {
                if host.state?.activeSeat == nil {
                    PremiumLogo().frame(maxWidth: 620)
                    Text("Host Mode").font(.headline)
                }
                if let state = host.state {
                    if state.activeSeat != nil {
                        PublicGameplayView(state: state, connected: host.connectedPlayers)
                            .frame(height: max(220, geometry.size.height - 100))

                    } else {
                        HStack(alignment: .top, spacing: 28) {
                            VStack(spacing: 12) {
                                Text("Join Game").font(.system(.title2, design: .serif))
                                roomQRCode(size: 180, padding: 12)
                                Text("Scan with your phone")
                                Text(host.roomCode).font(.system(.headline, design: .monospaced))
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Players (\(state.members.count) of 6)").font(.system(.title2, design: .serif))
                                ForEach(state.members) { member in
                                    HStack {
                                        JewelMarble(color: colors[member.color]).frame(width: 26, height: 26)
                                        VStack(alignment: .leading) {
                                            Text(member.name).lineLimit(1)
                                            if let partner = state.members.first(where: { $0.id == member.partner }) {
                                                Text("With " + partner.name).font(.caption)
                                            }
                                        }
                                        Spacer()
                                        Text(!host.connectedPlayers.contains(member.id) ? "Disconnected" : member.ready ? "Ready" : "Not ready")
                                            .foregroundStyle(member.ready && host.connectedPlayers.contains(member.id) ? Color.green : Color.secondary)
                                    }.padding(8).background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                                }
                                ForEach(state.members.count..<6, id: \.self) { slot in
                                    HStack {
                                        Image(systemName: slot < 3 && !state.members.isEmpty ? "cpu" : "circle.dashed")
                                        Text(slot < 3 && !state.members.isEmpty ? "Robot • auto-fill if needed" : "Open slot")
                                        Spacer()
                                    }.padding(8).foregroundStyle(.secondary)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Game rules").font(.headline)
                                Picker("Game rules", selection: Binding(get: { state.ruleset }, set: { host.configureRuleset($0) })) {
                                    ForEach(Ruleset.allCases, id: \.self) { rules in
                                        Text(rules.title).tag(rules)
                                    }
                                }.pickerStyle(.menu)
                            }.frame(maxWidth: 320)
                        }.padding(20).modifier(PremiumPanel())
                        Text(state.members.isEmpty ? "Waiting for players to join" : state.members.allSatisfy { $0.ready && host.connectedPlayers.contains($0.id) } ? "Ready to start" : "Waiting for players to be ready")
                        if [4, 6].contains(state.members.count) { Button(state.individual ? "Switch to teams" : "Switch to individual") { host.configureTeams(state.individual) } }
                        Button("Start game") { host.start() }
                            .disabled(state.members.isEmpty || !state.members.allSatisfy { $0.ready && host.connectedPlayers.contains($0.id) })
                    }
                    Button("Close room") { confirmClose = true }
                        .buttonStyle(.bordered).tint(.white)
                } else {
                    Button("Open new room") { host.open() }
                    #if !os(tvOS)
                    Button("Back", action: close)
                    #endif
                }
                if !host.error.isEmpty { Text(host.error).foregroundStyle(.red) }
            }.padding(20).frame(maxWidth: .infinity)
        }.defaultScrollAnchor(.top)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if host.state?.activeSeat != nil {
                HStack(spacing: 16) {
                    #if os(tvOS)
                    roomQRCode(size: 116, padding: 8)
                    #else
                    roomQRCode(size: 96, padding: 8)
                    #endif
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Room code").font(.subheadline)
                        Text(host.roomCode).font(.system(.title2, design: .monospaced).bold())
                            .accessibilityLabel(host.roomCode.map(String.init).joined(separator: " "))
                        Text("Scan to reconnect").font(.caption)
                    }
                }
                .modifier(PremiumPanel())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Color(red: 0.98, green: 0.88, blue: 0.72))
        .background(GameBackdrop().ignoresSafeArea())
        .confirmationDialog("End this room for everyone?", isPresented: $confirmClose) {
            Button("End room", role: .destructive) {
                host.close()
                #if os(tvOS)
                host.open()
                #endif
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Allow nearby controller to connect?", isPresented: Binding(get: { host.pendingConnection }, set: { if !$0 && host.pendingConnection { host.approveConnection(false) } })) {
            Button("Allow") { host.approveConnection(true) }
            Button("Deny", role: .cancel) { host.approveConnection(false) }
        } message: { Text("Approve only when someone you know is joining your room.") }
        .onAppear { if host.state == nil { host.open() } }
        .onDisappear { host.close() }
    }

    @ViewBuilder
    private func roomQRCode(size: CGFloat, padding: CGFloat) -> some View {
        if let image = qr(host.roomCode) {
            Image(decorative: image, scale: 1)
                .interpolation(.none)
                .resizable()
                .frame(width: size, height: size)
                .padding(padding)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func qr(_ code: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("jokersmarbles://join?code=\(code)&secret=\(host.roomSecret)".utf8)
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }
}
