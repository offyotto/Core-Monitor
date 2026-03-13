import SwiftUI
import AppKit

struct LaunchpadGlassView: View {
    let onClose: () -> Void
    let prefersFullscreen: Bool

    @State private var searchText = ""
    @State private var items: [LaunchpadItem] = []
    @State private var selectedPage = 0
    @State private var dragOffset: CGFloat = 0
    @State private var reveal = false

    @State private var selectedIndex = 0
    @State private var selection = Set<String>()
    @State private var openFolder: LaunchpadFolder?

    @State private var keyMonitor: Any?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 22), count: 6)
    private let rows = 5

    init(onClose: @escaping () -> Void, prefersFullscreen: Bool = false) {
        self.onClose = onClose
        self.prefersFullscreen = prefersFullscreen
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                wallpaperBlur
                    .ignoresSafeArea()

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    topBar
                        .panelReveal(index: 0, active: reveal)

                    pageScroller(width: proxy.size.width - 56)
                        .panelReveal(index: 1, active: reveal)

                    pageDots
                        .panelReveal(index: 2, active: reveal)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)

                if let folder = openFolder {
                    folderOverlay(folder)
                }
            }
            .onAppear {
                if items.isEmpty {
                    loadApps()
                }
                selectedPage = 0
                selectedIndex = 0
                reveal = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }
                if prefersFullscreen {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        NSApp.keyWindow?.toggleFullScreen(nil)
                    }
                }
                installKeyMonitor()
            }
            .onDisappear {
                uninstallKeyMonitor()
            }
            .onChange(of: searchText) { _, _ in
                selectedPage = 0
                selectedIndex = 0
            }
        }
    }

    private var wallpaperBlur: some View {
        Group {
            if let image = desktopImage() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 16)
            } else {
                Color.clear
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            if selection.count >= 2 {
                Button("Create Folder") {
                    createFolderFromSelection()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .glassEffect(.regular.interactive(), in: .capsule)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.primary.opacity(0.65))

                TextField("Search apps", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 16)
            .frame(width: 460, height: 50)
            .glassEffect(.regular.interactive(), in: .capsule)

            Spacer(minLength: 0)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
        }
    }

    private func pageScroller(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(pagedItems.enumerated()), id: \.offset) { index, page in
                gridPage(page)
                    .frame(width: width)
                    .clipped()
                    .id(index)
            }
        }
        .frame(width: width, alignment: .leading)
        .offset(x: -CGFloat(selectedPage) * width + dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold = width * 0.18
                    var newPage = selectedPage

                    if value.translation.width < -threshold {
                        newPage = min(selectedPage + 1, max(0, pagedItems.count - 1))
                    } else if value.translation.width > threshold {
                        newPage = max(selectedPage - 1, 0)
                    }

                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedPage = newPage
                        dragOffset = 0
                        selectedIndex = 0
                    }
                }
        )
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: selectedPage)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<max(1, pagedItems.count), id: \.self) { index in
                Capsule()
                    .fill(index == selectedPage ? Color.primary : Color.primary.opacity(0.25))
                    .frame(width: index == selectedPage ? 26 : 8, height: 8)
            }
        }
    }

    private func gridPage(_ pageItems: [LaunchpadItem]) -> some View {
        VStack {
            Spacer(minLength: 8)

            GlassEffectContainer(spacing: 16) {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(Array(pageItems.enumerated()), id: \.offset) { idx, item in
                        launchpadTile(item: item, index: idx)
                    }
                }
            }

            Spacer(minLength: 28)
        }
    }

    private func launchpadTile(item: LaunchpadItem, index: Int) -> some View {
        let isSelected = selectedIndex == index

        return Button {
            if let folder = item.folder {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    openFolder = folder
                }
            } else if let app = item.app {
                NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
                onClose()
            }
        } label: {
            VStack(spacing: 8) {
                if let folder = item.folder {
                    folderIcon(folder)
                } else if let app = item.app {
                    Image(nsImage: app.icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Text(item.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32)
                    .frame(maxWidth: 112)
            }
            .frame(width: 118, height: 122)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let app = item.app {
                Button(selection.contains(app.id) ? "Unselect" : "Select") {
                    toggleSelection(app.id)
                }
            }
        }
        .panelReveal(index: (index % 20) + 2, active: reveal)
    }

    private func folderIcon(_ folder: LaunchpadFolder) -> some View {
        let previews = Array(folder.apps.prefix(4))
        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.16))
                .frame(width: 64, height: 64)

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(previews.indices.prefix(2), id: \.self) { idx in
                        Image(nsImage: previews[idx].icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
                HStack(spacing: 4) {
                    ForEach(previews.indices.dropFirst(2).prefix(2), id: \.self) { idx in
                        Image(nsImage: previews[idx].icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
            }
        }
    }

    private func folderOverlay(_ folder: LaunchpadFolder) -> some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                        openFolder = nil
                    }
                }

            VStack(spacing: 14) {
                Text(folder.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(84), spacing: 12), count: 4), spacing: 12) {
                    ForEach(folder.apps) { app in
                        Button {
                            NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
                            onClose()
                        } label: {
                            VStack(spacing: 6) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .frame(width: 48, height: 48)
                                Text(app.name)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button("Close") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                        openFolder = nil
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .frame(width: 460)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
            .transition(.asymmetric(insertion: .scale(scale: 0.88).combined(with: .opacity), removal: .scale(scale: 1.05).combined(with: .opacity)))
        }
    }

    private var filteredItems: [LaunchpadItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var pagedItems: [[LaunchpadItem]] {
        let pageSize = columns.count * rows
        guard pageSize > 0 else { return [filteredItems] }
        if filteredItems.isEmpty { return [[]] }

        return stride(from: 0, to: filteredItems.count, by: pageSize).map { start in
            let end = min(start + pageSize, filteredItems.count)
            return Array(filteredItems[start..<end])
        }
    }

    private func toggleSelection(_ id: String) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    private func createFolderFromSelection() {
        let selectedApps = baseApps.filter { selection.contains($0.id) }
        guard selectedApps.count >= 2 else { return }

        let folder = LaunchpadFolder(id: UUID().uuidString, name: "Folder", apps: selectedApps)

        var newItems: [LaunchpadItem] = []
        var inserted = false
        for item in items {
            if let app = item.app, selection.contains(app.id) {
                if !inserted {
                    newItems.append(.folder(folder))
                    inserted = true
                }
            } else {
                newItems.append(item)
            }
        }

        selection.removeAll()
        items = newItems
    }

    private var baseApps: [LaunchpadApp] {
        items.compactMap(\.app)
    }

    private func installKeyMonitor() {
        uninstallKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKey(event)
            return nil
        }
    }

    private func uninstallKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handleKey(_ event: NSEvent) {
        switch event.keyCode {
        case 53: // esc
            if openFolder != nil {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                    openFolder = nil
                }
            } else {
                onClose()
            }
        case 123: // left
            moveSelection(dx: -1, dy: 0)
        case 124: // right
            moveSelection(dx: 1, dy: 0)
        case 125: // down
            moveSelection(dx: 0, dy: 1)
        case 126: // up
            moveSelection(dx: 0, dy: -1)
        case 36: // return
            activateSelection()
        default:
            break
        }
    }

    private func moveSelection(dx: Int, dy: Int) {
        let page = pagedItems[safe: selectedPage] ?? []
        guard !page.isEmpty else { return }

        let cols = columns.count
        var row = selectedIndex / cols
        var col = selectedIndex % cols

        row = max(0, min(rows - 1, row + dy))
        col = max(0, min(cols - 1, col + dx))

        let idx = row * cols + col
        selectedIndex = min(page.count - 1, idx)
    }

    private func activateSelection() {
        let page = pagedItems[safe: selectedPage] ?? []
        guard selectedIndex >= 0, selectedIndex < page.count else { return }

        let item = page[selectedIndex]
        if let folder = item.folder {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                openFolder = folder
            }
        } else if let app = item.app {
            NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
            onClose()
        }
    }

    private func loadApps() {
        let appDirectories = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications")
        ]

        var collected: [LaunchpadApp] = []
        var seen = Set<String>()

        for directory in appDirectories {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents where url.pathExtension == "app" {
                let name = url.deletingPathExtension().lastPathComponent
                if seen.contains(name) { continue }
                seen.insert(name)

                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 72, height: 72)
                collected.append(LaunchpadApp(id: url.path, name: name, url: url, icon: icon))
            }
        }

        items = collected
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { .app($0) }
    }

    private func desktopImage() -> NSImage? {
        guard let screen = NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen) else {
            return nil
        }

        return NSImage(contentsOf: url)
    }
}

private struct LaunchpadApp: Identifiable {
    let id: String
    let name: String
    let url: URL
    let icon: NSImage
}

private struct LaunchpadFolder: Identifiable {
    let id: String
    let name: String
    let apps: [LaunchpadApp]
}

private enum LaunchpadItem: Identifiable {
    case app(LaunchpadApp)
    case folder(LaunchpadFolder)

    var id: String {
        switch self {
        case .app(let app): return app.id
        case .folder(let folder): return folder.id
        }
    }

    var name: String {
        switch self {
        case .app(let app): return app.name
        case .folder(let folder): return folder.name
        }
    }

    var app: LaunchpadApp? {
        if case .app(let app) = self { return app }
        return nil
    }

    var folder: LaunchpadFolder? {
        if case .folder(let folder) = self { return folder }
        return nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
