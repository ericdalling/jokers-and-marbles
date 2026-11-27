import Foundation
import MultipeerConnectivity
import GameCore

enum SessionCommand: Codable {
    case join(name: String, color: Int)
    case resume(UUID)
    case invite(UUID)
    case respond(sender: UUID, accept: Bool)
    case unpair
    case ready(Bool)
    case play(revision: Int, move: GamePlay)
}

enum SessionReply: Codable {
    case identity(UUID)
    case state(PublicSession, PrivateSession?)
    case error(String)
}

final class SessionTransport: NSObject, ObservableObject {
    @Published private(set) var peers: [MCPeerID] = []
    @Published private(set) var connected: [MCPeerID] = []
    @Published private(set) var status = ""
    private let peer = MCPeerID(displayName: UUID().uuidString)
    private lazy var session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var codes: [MCPeerID: String] = [:]
    private var roomCode = ""
    var onData: ((Data, MCPeerID) -> Void)?
    var onConnection: ((MCPeerID, Bool) -> Void)?

    override init() {
        super.init()
        session.delegate = self
    }

    func host(code: String) {
        stop()
        roomCode = code
        let advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: ["room": code], serviceType: "jokers-marble")
        advertiser.delegate = self
        self.advertiser = advertiser
        advertiser.startAdvertisingPeer()
    }

    func browse(code: String) {
        stop()
        roomCode = code
        let browser = MCNearbyServiceBrowser(peer: peer, serviceType: "jokers-marble")
        browser.delegate = self
        self.browser = browser
        browser.startBrowsingForPeers()
    }

    func connect(_ target: MCPeerID) {
        guard codes[target] == roomCode else { return }
        browser?.invitePeer(target, to: session, withContext: Data(roomCode.utf8), timeout: 20)
    }

    func send<T: Encodable>(_ value: T, to target: MCPeerID) {
        do { try session.send(JSONEncoder().encode(value), toPeers: [target], with: .reliable) }
        catch { status = error.localizedDescription }
    }

    func stop() {
        advertiser?.stopAdvertisingPeer(); advertiser = nil
        browser?.stopBrowsingForPeers(); browser = nil
        session.disconnect()
        peers = []; connected = []; codes = [:]
    }
}

extension SessionTransport: MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            let accepted = context == Data(self.roomCode.utf8) && self.session.connectedPeers.count < 6
            invitationHandler(accepted, accepted ? self.session : nil)
        }
    }
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { self.status = error.localizedDescription }
    }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            guard info?["room"] == self.roomCode else { return }
            self.codes[peerID] = self.roomCode
            if !self.peers.contains(peerID) { self.peers.append(peerID) }
        }
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { self.peers.removeAll { $0 == peerID }; self.codes.removeValue(forKey: peerID) }
    }
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { self.status = error.localizedDescription }
    }
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connected = session.connectedPeers
            if state != .connecting { self.onConnection?(peerID, state == .connected) }
        }
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard data.count <= 1_000_000 else { return }
        DispatchQueue.main.async { self.onData?(data, peerID) }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
