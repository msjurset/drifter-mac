import SwiftUI
import AppKit

@main
struct DrifterApp: App {
    @NSApplicationDelegateAdaptor(DrifterAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
