// WeatherTouchBarItem.swift
// Core-Monitor

import AppKit
import Combine

// MARK: - Identifier

extension NSTouchBarItem.Identifier {
    static let weather = NSTouchBarItem.Identifier("com.coremon.touchbar.weather")
}

// MARK: - Notification

extension Notification.Name {
    static let weatherTouchBarTapped = Notification.Name("com.coremon.weatherTouchBarTapped")
}

// MARK: - Item

final class WeatherTouchBarItem: NSCustomTouchBarItem {

    private let weatherView = WeatherTouchBarView(frame: .zero)
    private var viewModel: WeatherViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: Init

    init(viewModel: WeatherViewModel) {
        self.viewModel = viewModel
        super.init(identifier: .weather)

        // Touch Bar height is always 30pt
        weatherView.frame = NSRect(x: 0, y: 0, width: 140, height: 30)
        view = weatherView

        bindViewModel()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: Binding

    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self else { return }
                self.weatherView.state = newState
                self.weatherView.invalidateIntrinsicContentSize()
            }
            .store(in: &cancellables)
    }

    // MARK: Tap handler

    @objc func handleTap() {
        NotificationCenter.default.post(name: .weatherTouchBarTapped, object: nil)
    }
}

