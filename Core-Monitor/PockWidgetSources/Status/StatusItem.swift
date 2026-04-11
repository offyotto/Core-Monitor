//
//  StatusItem.swift
//  Status
//
//  Status widget source for Core Monitor.
//

import AppKit
import Foundation

protocol StatusItem: AnyObject {
    var view: NSView { get }
    func reload()
    func didLoad()
    func didUnload()
    func apply(theme: TouchBarTheme)
}

extension Timer {
    private class TempWrapper {
        var timerAction: () -> Void
        weak var target: AnyObject?

        init(timerAction: @escaping () -> Void, target: AnyObject) {
            self.timerAction = timerAction
            self.target = target
        }
    }

    static func scheduledTimer(
        timeInterval: TimeInterval,
        target: AnyObject,
        repeats: Bool = false,
        action: @escaping () -> Void
    ) -> Timer {
        scheduledTimer(
            timeInterval: timeInterval,
            target: self,
            selector: #selector(_timeAction(timer:)),
            userInfo: TempWrapper(timerAction: action, target: target),
            repeats: repeats
        )
    }

    @objc private static func _timeAction(timer: Timer) {
        guard let tempWrapper = timer.userInfo as? TempWrapper else {
            return
        }

        if tempWrapper.target != nil {
            tempWrapper.timerAction()
        } else {
            timer.invalidate()
        }
    }
}
