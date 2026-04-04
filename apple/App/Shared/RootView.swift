import SwiftUI

struct RootView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        Group {
            if controller.currentUser == nil {
                LoginScreen(controller: controller)
            } else {
                LibraryScreen(controller: controller)
            }
        }
        .task {
            await controller.startIfNeeded()
        }
    }
}
