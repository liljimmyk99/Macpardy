//
//  LogRingBuffer.swift
//  Macpardy
//
//  Fixed-capacity buffer that keeps the newest elements. `LogCenter` keeps the
//  current run's last entries in one for the Logs window.
//

import Foundation

nonisolated struct LogRingBuffer<Element> {

    let capacity: Int
    private var storage: [Element] = []
    /// Index of the oldest element once the buffer is full.
    private var head = 0

    init(capacity: Int) {
        precondition(capacity > 0, "capacity must be positive")
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    var count: Int { storage.count }
    var isEmpty: Bool { storage.isEmpty }

    /// Adds `element`, dropping the oldest one when full.
    mutating func append(_ element: Element) {
        if storage.count < capacity {
            storage.append(element)
        } else {
            storage[head] = element
            head = (head + 1) % capacity
        }
    }

    mutating func append(contentsOf elements: some Sequence<Element>) {
        for element in elements { append(element) }
    }

    mutating func removeAll() {
        storage.removeAll(keepingCapacity: true)
        head = 0
    }

    /// Oldest first.
    var elements: [Element] {
        guard head > 0 else { return storage }
        return Array(storage[head...] + storage[..<head])
    }
}
