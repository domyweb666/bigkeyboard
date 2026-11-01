import SwiftUI

@main
struct BigKeyboardApp: App {
    init() {
        ReadingLookup.warmUp()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
