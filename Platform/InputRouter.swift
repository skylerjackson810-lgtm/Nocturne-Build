import Foundation
import GameController
import Combine

@MainActor
final class InputRouter: ObservableObject {
    @Published private(set) var hardwareConnected = false
    var touchMovement = SIMD2<Float>.zero
    private var touchLook = SIMD2<Float>.zero
    var onPause: (() -> Void)?
    var onPageTurn: ((Int) -> Void)?
    private var controller: GCController?
    private var observers: [NSObjectProtocol] = []
    private var previousMenu = false
    private var previousLeft = false
    private var previousRight = false

    init() {
        for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in Task { @MainActor in self?.refreshController() }
            })
        }
        refreshController()
    }

    private func refreshController() {
        controller = GCController.controllers().first { $0.extendedGamepad != nil }
        hardwareConnected = controller != nil
        reset()
    }

    func addLook(_ delta: SIMD2<Float>) { touchLook += delta }

    func sample(deltaTime: Float, sensitivity: Float, invertedY: Bool)
        -> (move: SIMD2<Float>, look: SIMD2<Float>) {
        var movement = touchMovement
        var look = touchLook * (0.003 * sensitivity)
        touchLook = .zero
        if let pad = controller?.extendedGamepad {
            movement = deadZone(SIMD2(pad.leftThumbstick.xAxis.value, pad.leftThumbstick.yAxis.value))
            let stick = deadZone(SIMD2(pad.rightThumbstick.xAxis.value, pad.rightThumbstick.yAxis.value))
            look = SIMD2(stick.x, -stick.y) * (deltaTime * sensitivity * 2.2)
            let pressed = pad.buttonMenu.isPressed
            if pressed && !previousMenu { onPause?() }
            previousMenu = pressed
            let left = pad.leftShoulder.isPressed, right = pad.rightShoulder.isPressed
            if left && !previousLeft { onPageTurn?(-1) }
            if right && !previousRight { onPageTurn?(1) }
            previousLeft = left; previousRight = right
        }
        if invertedY { look.y *= -1 }
        return (movement, look)
    }

    func reset() {
        touchMovement = .zero; touchLook = .zero; previousMenu = false
        previousLeft = false; previousRight = false
    }

    private func deadZone(_ v: SIMD2<Float>) -> SIMD2<Float> {
        let length = sqrt(v.x * v.x + v.y * v.y)
        guard length > 0.16 else { return .zero }
        return v / length * min(1, (length - 0.16) / 0.84)
    }

    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
}
