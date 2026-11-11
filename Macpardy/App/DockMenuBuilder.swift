//
//  DockMenuBuilder.swift
//  Macpardy
//

import Foundation

/// Decides which windows the Dock menu lists. Pure logic, so it is tested without AppKit windows.
nonisolated enum DockMenuBuilder {

    /// What the builder needs to know about one window.
    struct WindowInfo: Equatable {
        var title: String
        var isVisible: Bool
        var isMiniaturized: Bool
        var isKey: Bool
        var isPanel: Bool
    }

    struct Entry: Equatable {
        /// Index into the input array, so the caller can find the window again.
        var index: Int
        var title: String
        var isKey: Bool
        var isMiniaturized: Bool
    }

    /// Titled, non-panel windows that are on screen or minimized, in input order.
    static func entries(for windows: [WindowInfo]) -> [Entry] {
        windows.enumerated().compactMap { index, window in
            guard !window.isPanel,
                  !window.title.isEmpty,
                  window.isVisible || window.isMiniaturized else { return nil }
            return Entry(index: index, title: window.title, isKey: window.isKey, isMiniaturized: window.isMiniaturized)
        }
    }
}
