import AppKit

class PKPillWidget: PKWidget {
    let kind: TouchBarWidgetKind
    let contentView: NSView
    private let themableContent: any TouchBarThemable
    private let containerView: NSView
    private let pillView = PillView()

    var theme: TouchBarTheme = .dark {
        didSet { applyTheme() }
    }

    init(kind: TouchBarWidgetKind, contentView: NSView & TouchBarThemable) {
        self.kind = kind
        self.contentView = contentView
        self.themableContent = contentView
        self.containerView = NSView(frame: NSRect(x: 0, y: 0, width: kind.estimatedWidth, height: TB.stripH))
        super.init()
        customizationLabel = kind.title
        setup()
    }

    required init() {
        fatalError("PKPillWidget subclasses must override init().")
    }

    override var view: NSView { containerView }

    private func setup() {
        containerView.translatesAutoresizingMaskIntoConstraints = false

        pillView.fixedWidth = kind.estimatedWidth
        pillView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(pillView)

        NSLayoutConstraint.activate([
            pillView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pillView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pillView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: TB.pillVInset),
            pillView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -TB.pillVInset)
        ])

        contentView.translatesAutoresizingMaskIntoConstraints = false
        pillView.contentView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: pillView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: pillView.contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: pillView.contentView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: pillView.contentView.bottomAnchor)
        ])

        applyTheme()
    }

    private func applyTheme() {
        pillView.theme = theme
        themableContent.theme = theme
    }
}

final class PKWorldClockWidget: PKPillWidget {
    let statusView: StatusWidget

    required init() {
        let statusView = StatusWidget()
        self.statusView = statusView
        super.init(kind: .worldClocks, contentView: statusView)
    }
}

final class PKWeatherWidget: PKPillWidget {
    let weatherView: WeatherWidget

    required init() {
        let weatherView = WeatherWidget()
        self.weatherView = weatherView
        super.init(kind: .weather, contentView: weatherView)
    }
}

final class PKStatsWidget: PKPillWidget {
    let groupView: SystemStatsGroupView

    required init() {
        let groupView = SystemStatsGroupView(style: .compact)
        self.groupView = groupView
        super.init(kind: .stats, contentView: groupView)
    }
}

final class PKDetailedStatsWidget: PKPillWidget {
    let groupView: SystemStatsGroupView

    required init() {
        let groupView = SystemStatsGroupView(style: .detailed)
        self.groupView = groupView
        super.init(kind: .detailedStats, contentView: groupView)
    }
}

final class PKCombinedWidget: PKPillWidget {
    let groupView: CombinedGroupView

    required init() {
        let groupView = CombinedGroupView()
        self.groupView = groupView
        super.init(kind: .combined, contentView: groupView)
    }
}

final class PKHardwareWidget: PKPillWidget {
    let groupView: HardwareIconsGroupView

    required init() {
        let groupView = HardwareIconsGroupView()
        self.groupView = groupView
        super.init(kind: .hardware, contentView: groupView)
    }
}

final class PKNetworkWidget: PKPillWidget {
    let groupView: NetworkGroupView

    required init() {
        let groupView = NetworkGroupView()
        self.groupView = groupView
        super.init(kind: .network, contentView: groupView)
    }
}

extension TouchBarWidgetKind {
    var widgetInfo: PKWidgetInfo {
        switch self {
        case .worldClocks:
            return PKWidgetInfo(bundleIdentifier: identifier.rawValue, principalClass: PKWorldClockWidget.self, name: title)
        case .weather:
            return PKWidgetInfo(bundleIdentifier: identifier.rawValue, principalClass: PKWeatherWidget.self, name: title)
        case .stats:
            return PKWidgetInfo(bundleIdentifier: identifier.rawValue, principalClass: PKStatsWidget.self, name: title)
        case .detailedStats:
            return PKWidgetInfo(bundleIdentifier: identifier.rawValue, principalClass: PKDetailedStatsWidget.self, name: title)
        case .combined:
            return PKWidgetInfo(bundleIdentifier: identifier.rawValue, principalClass: PKCombinedWidget.self, name: title)
        case .hardware:
            return PKWidgetInfo(bundleIdentifier: identifier.rawValue, principalClass: PKHardwareWidget.self, name: title)
        case .network:
            return PKWidgetInfo(bundleIdentifier: identifier.rawValue, principalClass: PKNetworkWidget.self, name: title)
        }
    }
}

enum PKCoreMonWidgetCatalog {
    static func allWidgets() -> [NSTouchBarItem.Identifier: PKWidgetInfo] {
        Dictionary(uniqueKeysWithValues: TouchBarWidgetKind.allCases.map { ($0.identifier, $0.widgetInfo) })
    }
}

enum PKCoreMonWidgetState {
    static func apply(
        theme: TouchBarTheme,
        weatherState: WeatherState,
        snapshot: TouchBarSystemSnapshot,
        clockTitle: String,
        clockSubtitle: String,
        to widget: PKWidget
    ) {
        if let pillWidget = widget as? PKPillWidget {
            pillWidget.theme = theme
        }

        switch widget {
        case let widget as PKWeatherWidget:
            widget.weatherView.apply(state: weatherState)
        case let widget as PKStatsWidget:
            widget.groupView.update(snap: snapshot)
        case let widget as PKDetailedStatsWidget:
            widget.groupView.update(snap: snapshot)
        case let widget as PKCombinedWidget:
            widget.groupView.update(snap: snapshot)
        case let widget as PKHardwareWidget:
            widget.groupView.update(snapshot: snapshot)
        case let widget as PKNetworkWidget:
            widget.groupView.update(upKBs: snapshot.netUpKBs, downMBs: snapshot.netDownMBs)
        case let widget as PKWorldClockWidget:
            widget.statusView.reload()
        default:
            break
        }
    }
}
