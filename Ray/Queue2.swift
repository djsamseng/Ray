//
//  Queue.swift
//  StreamIt
//
//  Created by Thibault Wittemberg on 14/04/2016.
//  Copyright © 2016 Thibault Wittemberg. All rights reserved.
//

private class QueueItem2<T> {

    fileprivate let value: T!
    fileprivate var next: QueueItem2?

    init(_ newvalue: T?) {
        self.value = newvalue
    }
}

open class Queue2<T> {

    fileprivate var _front: QueueItem2<T>
    fileprivate var _back: QueueItem2<T>
    fileprivate var maxCapacity: Int
    fileprivate var currentSize = 0

    public init(maxCapacity: Int) {
        // Insert dummy item. Will disappear when the first item is added.
        _back = QueueItem2(nil)
        _front = _back
        self.maxCapacity = maxCapacity
    }

    /// Add a new item to the back of the queue.
    open func enqueue(_ value: T) {
        if self.currentSize >= maxCapacity {
            _back = QueueItem2(value)
        } else {
            _back.next = QueueItem2(value)
            _back = _back.next!
            self.currentSize += 1
        }
    }

    /// Return and remove the item at the front of the queue.
    open func dequeue() -> T? {
        if let newhead = _front.next {
            _front = newhead
            self.currentSize -= 1
            return newhead.value
        } else {
            self.currentSize = 0
            return nil
        }
    }

    open func isEmpty() -> Bool {
        return _front === _back
    }
}
