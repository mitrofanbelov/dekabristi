import SwiftUI

@main
struct DekabristiIOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller = AppController()

    var body: some Scene {
        WindowGroup {
            RootView(controller: controller)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await controller.handleAppBecameActive()
            }
        }
    }
}
