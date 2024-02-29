//
//  ServerStreamer.swift
//  Ray
//
//  Created by Samuel Seng on 10/1/22.
//  Adopted from https://github.com/twittemb/StreamIt

import Foundation
import CocoaAsyncSocket


class ServerStreamer2: NSObject, GCDAsyncSocketDelegate {
    fileprivate var serverSocket: GCDAsyncSocket?
    fileprivate var clients = [Int: StreamingSession2]()
    
    let serverQueue = DispatchQueue(label: "ServerQueue", attributes: [])
    let clientQueue = DispatchQueue(label: "ClientQueue", attributes: .concurrent)
    let socketQueue = DispatchQueue(label: "SocketQueue", attributes: .concurrent)
    
    let port: UInt16
    init(port: UInt16 = 10001) {
        self.port = port
        super.init()
        let ip = getIP()
        print("IP:", ip, port)
        self.serverSocket = GCDAsyncSocket(delegate: self, delegateQueue: self.serverQueue, socketQueue: self.socketQueue)
        
        do {
            try self.serverSocket?.accept(onInterface: ip, port: self.port)
        }
        catch {
            print("===== Failed to listen on", ip, ":", port, "=====")
        }
    }
    
    func streamData(data: Data) {
        for (key, client) in self.clients {
            if client.connected {
                client.dataToSend = data
            }
            else {
                self.clients.removeValue(forKey: key)
            }
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("New client connected from:", newSocket.connectedHost ?? "unknown")
        guard let clientId = newSocket.connectedAddress?.hashValue else { return }
        let newClient = StreamingSession2(id: clientId, client: newSocket, queue: self.clientQueue)
        self.clients[clientId] = newClient
        newClient.startStreaming()
    }
}
