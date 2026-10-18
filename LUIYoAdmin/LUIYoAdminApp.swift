import SwiftUI

@main
struct LUIYoAdminApp: App {
    @StateObject private var api = AdminAPI.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(api)
        }
    }
}
