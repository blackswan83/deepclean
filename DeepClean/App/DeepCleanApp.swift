import SwiftUI

@main
struct DeepCleanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Scan System") {
                    NotificationCenter.default.post(name: .scanSystem, object: nil)
                }
                .keyboardShortcut("R", modifiers: [.command])

                Divider()

                Button("Deep Clean") {
                    appState.selectedItem = .clean
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Uninstall Apps") {
                    appState.selectedItem = .uninstall
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("Analyze Disk") {
                    appState.selectedItem = .analyze
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button("Optimize System") {
                    appState.selectedItem = .optimize
                }
                .keyboardShortcut("4", modifiers: [.command])

                Button("System Status") {
                    appState.selectedItem = .status
                }
                .keyboardShortcut("5", modifiers: [.command])
            }

            CommandGroup(replacing: .sidebar) {
                Button("Toggle Sidebar") {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(
                        #selector(NSSplitViewController.toggleSidebar(_:)),
                        with: nil
                    )
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .help) {
                Button("DeepClean Help") {
                    if let url = URL(string: "https://github.com/blackswan83/deepclean") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }

        MenuBarExtra("DeepClean", systemImage: "sparkles") {
            MenuBarView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure app appearance
        NSApp.appearance = NSAppearance(named: .darkAqua)

        // Ensure app is active and window is visible
        NSApp.activate(ignoringOtherApps: true)

        // Make sure the main window is visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.center()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running for menu bar
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let scanSystem = Notification.Name("scanSystem")
}
