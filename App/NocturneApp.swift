import SwiftUI

@main
struct NocturneApp: App {
    @StateObject private var session = GameSession()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { session.suspend() }
                    else if phase == .inactive && !session.requestingVoice { session.pause() }
                }
        }
    }
}
