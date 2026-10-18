import SwiftUI

@main
struct LUIYoAdminApp: App {
    @StateObject private var api = AdminAPI.shared
    @StateObject private var display = AppDisplaySettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(api)
                .environmentObject(display)
        }
    }
}
