import RealityKit
import Foundation

@MainActor
protocol BookVisualDriving: AnyObject {
    func show(page: String, highlight: String)
    func showTranscript(_ text: String)
}

@MainActor
protocol HandVisualDriving: AnyObject {
    // Implementations use preloaded animations and pooled effect entities.
    func beginCharge(effect: String, attachedTo socket: Entity)
    func release(animation: String)
    func cancel()
    func idle()
}

@MainActor
final class PlayerRigController: RigPresenting {
    private enum State {
        case idle
        case awaitingAuthority(UUID, SpellDefinition)
        case charging(UUID, SpellDefinition, releaseAt: Tick)
        case recovering(until: Tick)
    }

    let root: Entity
    private let castSocket: Entity
    private let book: any BookVisualDriving
    private let hand: any HandVisualDriving
    private let recoveryTicks: Tick
    private var selected: SpellDefinition?
    private var state: State = .idle

    enum AssetError: Error { case missingNode(String) }

    // Camera is explicitly positioned by the game, using a non-AR ARView.
    // rigAsset must contain a local-only book and right hand, with no collision.
    init(camera: PerspectiveCamera, rigAsset: Entity,
         book: any BookVisualDriving, hand: any HandVisualDriving,
         recoveryTicks: Tick = 10) throws {
        guard rigAsset.findEntity(named: "LeftBook") != nil else {
            throw AssetError.missingNode("LeftBook")
        }
        guard let rightHand = rigAsset.findEntity(named: "RightHand") else {
            throw AssetError.missingNode("RightHand")
        }
        guard let socket = rightHand.findEntity(named: "CastSocket") else {
            throw AssetError.missingNode("CastSocket")
        }
        root = rigAsset
        castSocket = socket
        self.book = book
        self.hand = hand
        self.recoveryTicks = recoveryTicks
        camera.addChild(rigAsset)
    }

    func select(_ spell: SpellDefinition) {
        selected = spell
        if case .idle = state { book.show(page: spell.presentation.bookPage,
                                          highlight: spell.presentation.highlightedTextKey) }
    }

    func showTranscript(_ text: String) { book.showTranscript(text) }

    func beginVoiceCast(id: UUID, spell: SpellDefinition) {
        state = .awaitingAuthority(id, spell)
        book.show(page: spell.presentation.bookPage,
                  highlight: spell.presentation.highlightedTextKey)
        hand.cancel()
        hand.beginCharge(effect: spell.presentation.chargeEffect, attachedTo: castSocket)
    }

    func accept(_ cast: CastAccepted) {
        guard case .awaitingAuthority(let id, let spell) = state, id == cast.castID else { return }
        state = .charging(id, spell, releaseAt: cast.releaseAtTick)
    }

    // Feed an estimated authority tick from clock synchronization, never wall time.
    func update(authorityTick: Tick) {
        switch state {
        case .charging(_, let spell, let releaseAt) where authorityTick >= releaseAt:
            hand.release(animation: spell.presentation.releaseAnimation)
            state = .recovering(until: authorityTick + recoveryTicks)
        case .recovering(let end) where authorityTick >= end:
            reset()
        default: break
        }
    }

    func reject(id: UUID) {
        switch state {
        case .awaitingAuthority(let current, _), .charging(let current, _, _):
            if current == id { reset() }
        default: break
        }
    }

    func reset() {
        hand.cancel()
        hand.idle()
        book.showTranscript("")
        state = .idle
        if let selected { book.show(page: selected.presentation.bookPage,
                                    highlight: selected.presentation.highlightedTextKey) }
    }

    // Presentation only. Combat spawns from the authority's capsule/aim solution;
    // the animated socket must never provide the network projectile origin.
    var cosmeticMuzzleWorldPosition: SIMD3<Float> { castSocket.position(relativeTo: nil) }
}
