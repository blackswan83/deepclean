import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var whitelistManager = WhitelistManager()
    @State private var newWhitelistPath = ""

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            whitelistTab
                .tabItem {
                    Label("Whitelist", systemImage: "shield")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }

    // MARK: - General Tab
    private var generalTab: some View {
        Form {
            Section {
                Toggle("Enable dry run by default", isOn: $appState.isDryRun)

                Toggle("Show confirmation before cleaning", isOn: .constant(true))

                Toggle("Empty Trash after cleaning", isOn: .constant(false))
            } header: {
                Text("Cleaning")
            }

            Section {
                Toggle("Auto-refresh system status", isOn: .constant(true))

                Picker("Refresh interval", selection: .constant(2)) {
                    Text("1 second").tag(1)
                    Text("2 seconds").tag(2)
                    Text("5 seconds").tag(5)
                }
            } header: {
                Text("Status Dashboard")
            }

            Section {
                Toggle("Launch at login", isOn: .constant(false))

                Toggle("Show in menu bar", isOn: .constant(true))
            } header: {
                Text("App Behavior")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Whitelist Tab
    private var whitelistTab: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protected Paths")
                        .font(SumiTypography.monoTitle)
                        .foregroundStyle(SumiColors.primary(colorScheme))

                    Text("Paths in this list will be skipped during cleaning")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                }

                Spacer()
            }
            .padding(.horizontal)

            // Add Path
            HStack {
                TextField("Add path...", text: $newWhitelistPath)
                    .textFieldStyle(.plain)
                    .font(SumiTypography.mono)
                    .padding(8)
                    .background(SumiColors.surface(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Button("Add") {
                    addToWhitelist()
                }
                .buttonStyle(SumiPrimaryButtonStyle())
                .disabled(newWhitelistPath.isEmpty)

                Button(action: selectPath) {
                    Image(systemName: "folder")
                }
                .buttonStyle(SumiSecondaryButtonStyle())
            }
            .padding(.horizontal)

            // List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(whitelistManager.items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.path)
                                    .font(SumiTypography.mono)
                                    .foregroundStyle(SumiColors.primary(colorScheme))

                                if let reason = item.reason {
                                    Text(reason)
                                        .font(SumiTypography.monoSmall)
                                        .foregroundStyle(SumiColors.secondary(colorScheme))
                                }

                                Text("Added \(item.addedDate, style: .relative) ago")
                                    .font(SumiTypography.monoSmall)
                                    .foregroundStyle(SumiColors.secondary(colorScheme))
                            }

                            Spacer()

                            Button(action: { whitelistManager.remove(item) }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(Color.errorRed)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(SumiColors.surface(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
    }

    // MARK: - About Tab
    private var aboutTab: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(SumiColors.accent(colorScheme))

            // App Name
            HStack(spacing: 4) {
                Text("deep")
                    .font(SumiTypography.commandLarge)
                    .foregroundStyle(SumiColors.primary(colorScheme))
                Text("clean")
                    .font(SumiTypography.commandLarge)
                    .foregroundStyle(SumiColors.accent(colorScheme))
            }

            // Version
            Text("Version 1.0.0")
                .font(SumiTypography.mono)
                .foregroundStyle(SumiColors.secondary(colorScheme))

            // Description
            Text("A powerful macOS system cleanup and optimization tool")
                .font(SumiTypography.mono)
                .foregroundStyle(SumiColors.secondary(colorScheme))
                .multilineTextAlignment(.center)

            Spacer()

            // Links
            HStack(spacing: 24) {
                Link(destination: URL(string: "https://github.com/blackswan83/deepclean")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                        Text("GitHub")
                    }
                    .font(SumiTypography.mono)
                }

                Link(destination: URL(string: "https://github.com/blackswan83/deepclean/issues")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.bubble")
                        Text("Report Issue")
                    }
                    .font(SumiTypography.mono)
                }
            }
            .foregroundStyle(SumiColors.accent(colorScheme))

            // Copyright
            Text("MIT License")
                .font(SumiTypography.monoSmall)
                .foregroundStyle(SumiColors.secondary(colorScheme))

            Spacer()
        }
        .padding()
    }

    // MARK: - Actions
    private func addToWhitelist() {
        guard !newWhitelistPath.isEmpty else { return }
        whitelistManager.add(newWhitelistPath)
        newWhitelistPath = ""
    }

    private func selectPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            newWhitelistPath = url.path
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
