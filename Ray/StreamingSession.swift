//
//  StreamingSession.swift
//  Ray
//
//  Created by Samuel Seng on 10/1/22.
//

import Foundation
import CocoaAsyncSocket

private class QueueItem<T> {

    fileprivate let value: T!
    fileprivate var next: QueueItem?

    init(_ newvalue: T?) {
        self.value = newvalue
    }
}

open class Queue<T> {

    fileprivate var _front: QueueItem<T>
    fileprivate var _back: QueueItem<T>
    fileprivate var maxCapacity: Int
    fileprivate var currentSize = 0

    public init(maxCapacity: Int) {
        // Insert dummy item. Will disappear when the first item is added.
        _back = QueueItem(nil)
        _front = _back
        self.maxCapacity = maxCapacity
    }

    /// Add a new item to the back of the queue.
    open func enqueue(_ value: T) {
        if self.currentSize >= maxCapacity {
            _back = QueueItem(value)
        } else {
            _back.next = QueueItem(value)
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

class StreamingSession {
    fileprivate var client: GCDAsyncSocket
    fileprivate var headersSent = false
    fileprivate var dataStack = Queue<Data>(maxCapacity: 1)
    fileprivate var queue: DispatchQueue
    fileprivate let footersData = StreamingData.getJpegFrameFooters()
    
    private let frameHeaderSize: Int = 100

    var id: Int
    var connected = true
    var dataToSend: Data? {
        didSet {
            guard let dataToSend = self.dataToSend else { return }
            self.dataStack.enqueue(dataToSend)
        }
    }
    init (id: Int, client: GCDAsyncSocket, queue: DispatchQueue) {
        print("Creating client [#\(id)]")

        self.id = id
        self.client = client
        self.queue = queue
    }

    func close() {
        print("Closing client [#\(self.id)]")

        self.connected = false
    }

    func startStreaming() {
        self.queue.async(execute: { [unowned self] in
            while self.connected {

                if !self.headersSent {
                    print("Sending headers [#\(self.id)]")

                    let headersData = StreamingData.getJpegHeaders()

                    self.headersSent = true
                    self.client.write(headersData, withTimeout: -1, tag: 0)
                } else {
                    if (self.client.connectedPort.hashValue == 0 || !self.client.isConnected) {
                        self.close()
                        print("Dropping client [#\(self.id)]")
                    }

                    // Send latest data
                    var data: Data? = nil
                    var numTimes = 0
                    while let newData = self.dataStack.dequeue() {
                        data = newData
                        numTimes += 1
                    }
                    if numTimes > 1 {
                        print("Dropped frames:", numTimes)
                    }
                    if let data = data {
                        let frameHeadersData = StreamingData.getJpegFrameHeaders(dataCount: data.count, size: self.frameHeaderSize)
                        if frameHeadersData.count != self.frameHeaderSize {
                            print("==== Invalid Frame Header Size. Acutal=\(frameHeadersData.count) Desired=\(self.frameHeaderSize)")
                        }
                        self.client.write(frameHeadersData, withTimeout: -1, tag: 0)
                        self.client.write(data, withTimeout: -1, tag: 0)
                        self.client.write(self.footersData, withTimeout: -1, tag: self.id)
                    }
                }
            }
        })
    }
}
