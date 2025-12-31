import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            detailView
        }
        .background(SumiColors.background(colorScheme))
        .onAppear {
            print("✅ ContentView appeared!")
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selectedItem {
        case .clean:
            CleanView()
        case .uninstall:
            UninstallView()
        case .analyze:
            AnalyzeView()
        case .optimize:
            OptimizeView()
        case .status:
            StatusView()
        }
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()
                .background(SumiColors.border(colorScheme))

            // Navigation Items
            List(NavigationItem.allCases, selection: $appState.selectedItem) { item in
                NavigationRow(item: item, isSelected: appState.selectedItem == item)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Spacer()

            // Footer
            footerView
                .padding(16)
        }
        .frame(minWidth: 220)
        .background(SumiColors.surface(colorScheme))
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundStyle(SumiColors.accent(colorScheme))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("deep")
                        .font(SumiTypography.monoTitle)
                        .foregroundStyle(SumiColors.primary(colorScheme))
                    Text("clean")
                        .font(SumiTypography.monoTitle)
                        .foregroundStyle(SumiColors.accent(colorScheme))
                }

                Text("v1.0.0")
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
            }

            Spacer()
        }
    }

    private var footerView: some View {
        VStack(spacing: 8) {
            if appState.totalSpaceFreed > 0 {
                HStack {
                    Text("Total freed:")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))

                    Spacer()

                    Text(appState.formatBytes(appState.totalSpaceFreed))
                        .font(SumiTypography.mono)
                        .foregroundStyle(SumiColors.accent(colorScheme))
                }
            }

            if let lastCleaned = appState.lastCleanedDate {
                HStack {
                    Text("Last cleaned:")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))

                    Spacer()

                    Text(lastCleaned, style: .relative)
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                }
            }
        }
    }
}

// MARK: - Navigation Row
struct NavigationRow: View {
    let item: NavigationItem
    let isSelected: Bool

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? SumiColors.accent(colorScheme) : SumiColors.secondary(colorScheme))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(SumiTypography.mono)
                    .foregroundStyle(isSelected ? SumiColors.primary(colorScheme) : SumiColors.secondary(colorScheme))

                Text(item.description)
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Text(">")
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.accent(colorScheme))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? SumiColors.accent(colorScheme).opacity(0.1) : .clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 1000, height: 700)
}
