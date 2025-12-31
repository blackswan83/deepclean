# DeepClean

A powerful macOS system cleanup and optimization tool with a terminal-inspired interface.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

### Deep System Cleanup (`mo clean`)
- Scan and remove user app caches
- Clear browser caches (Chrome, Safari, Firefox, Edge, Brave)
- Clean developer tool caches (Xcode, Node.js, npm, CocoaPods, Gradle)
- Remove system logs and temp files
- Clean app-specific caches (Spotify, Dropbox, Slack, etc.)
- Empty Trash programmatically
- **Dry-run mode** - preview what would be deleted without actually deleting
- **Whitelist management** - protect certain caches from deletion

### Smart App Uninstaller (`mo uninstall`)
- List installed applications with size and recency
- Multi-select interface for batch uninstall
- Deep residual file detection across 12+ locations:
  - Application Support
  - Caches
  - Preferences
  - Logs
  - WebKit storage
  - Cookies
  - Extensions
  - Plugins
  - Launch daemons/agents
- Calculate total space freed per app

### Disk Space Analyzer (`mo analyze`)
- Visual disk explorer with percentage bars
- Hierarchical folder navigation
- Age indicators (">6mo" for old files)
- Large file finder (100MB+)
- Direct actions: Open, Show in Finder, Delete

### System Optimization (`mo optimize`)
- Rebuild system databases (Launch Services, Spotlight)
- Clear system caches
- Reset network services (DNS cache)
- Refresh Finder and Dock
- Clean diagnostic and crash logs
- Memory purge

### Live System Status Dashboard (`mo status`)
- Health score (0-100) calculated from multiple metrics
- CPU: usage per core, load averages
- Memory: used/free/available, percentage
- Disk: usage, free space
- Battery/Power: level, charge status, health, cycle count
- Top processes by resource usage
- Real-time updating display (2-second refresh)

## Design

DeepClean features a terminal-inspired aesthetic with:
- **Typography**: SF Mono for code/data, SF Pro for UI labels
- **Colors**:
  - Light mode: Paper backgrounds, Terminal Green accents
  - Dark mode: Charcoal backgrounds, Phosphor Green accents
- **Components**: Custom cards, progress bars, checkboxes, and buttons

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0+ (for building)

## Building

```bash
# Clone the repository
git clone https://github.com/blackswan83/deepclean.git
cd deepclean

# Build with Swift Package Manager
swift build

# Or open in Xcode
open Package.swift
```

## Project Structure

```
DeepClean/
├── App/
│   └── DeepCleanApp.swift      # App entry point
├── Views/
│   ├── ContentView.swift       # Main navigation
│   ├── CleanView.swift         # Deep cleanup interface
│   ├── UninstallView.swift     # App uninstaller
│   ├── AnalyzeView.swift       # Disk analyzer
│   ├── OptimizeView.swift      # System optimization
│   ├── StatusView.swift        # System status dashboard
│   ├── SettingsView.swift      # Preferences
│   └── MenuBarView.swift       # Menu bar extra
├── Models/
│   └── AppState.swift          # Application state & models
├── Services/
│   ├── CleanService.swift      # Cleanup operations
│   ├── UninstallService.swift  # App removal
│   ├── AnalyzeService.swift    # Disk analysis
│   ├── OptimizeService.swift   # System optimization
│   └── StatusService.swift     # System monitoring
├── Utilities/
│   └── DesignSystem.swift      # Colors, fonts, components
└── Resources/
    └── Info.plist              # App configuration
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘R | Scan System |
| ⌘1 | Deep Clean |
| ⌘2 | Uninstall Apps |
| ⌘3 | Analyze Disk |
| ⌘4 | Optimize System |
| ⌘5 | System Status |
| ⇧⌘S | Toggle Sidebar |

## Safety Features

- **Dry-run mode**: Preview changes before executing
- **Whitelist**: Protect important paths from cleanup
- **Confirmation prompts**: For destructive operations
- **Trash-based deletion**: Files are moved to Trash, not permanently deleted
- **System protection**: Core system files are never touched

## Credits

- Inspired by [Mole](https://github.com/tw93/Mole) - Mac Optimization Toolkit
- Design language from [PDFHandler](https://github.com/blackswan83/pdfhandler)

## License

MIT License - see [LICENSE](LICENSE) for details.
