import SwiftUI

@main
struct KestrelApp: App {
    @State private var store = RadarStore()

    var body: some Scene {
        WindowGroup {
            RadarView(store: store)
        }
    }
}
