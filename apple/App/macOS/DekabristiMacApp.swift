import SwiftUI

@main
struct DekabristiMacApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller = AppController()

    var body: some Scene {
        WindowGroup {
            RootView(controller: controller)
                .frame(minWidth: 900, minHeight: 640)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await controller.handleAppBecameActive()
            }
        }
    }
}
