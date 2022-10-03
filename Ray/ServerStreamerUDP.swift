//
//  ServerStreamerUDP.swift
//  Ray
//
//  Created by Samuel Seng on 10/3/22.
//

import Foundation
import CocoaAsyncSocket

class ServerStreamerUDP: NSObject, GCDAsyncUdpSocketDelegate {
    fileprivate var serverSocket: GCDAsyncUdpSocket?
    
    let serverQueue = DispatchQueue(label: "ServerQueue", attributes: [])
    let clientQueue = DispatchQueue(label: "ClientQueue", attributes: .concurrent)
    let socketQueue = DispatchQueue(label: "SocketQueue", attributes: .concurrent)
    
    let port: UInt16 = 10001
    let ip: String = "192.168.1.242"//getIP()
    override init() {
        super.init()
        self.serverSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: self.serverQueue, socketQueue: self.socketQueue)
        
        do {
            //try self.serverSocket?.bind(toPort: self.port, interface: ip)
            //try self.serverSocket?.beginReceiving()
        }
        catch {
            print("===== Failed to listen on", ip, ":", port, "=====")
        }
        print("===== IP:", self.ip, "Port:", self.port)
    }
    
    func streamData(data: Data) {
        guard let serverSocket = self.serverSocket else { return }
        serverSocket.send(data, toHost: self.ip, port: self.port, withTimeout: -1, tag: 0)
    }
    
    func socket(_ sock: GCDAsyncUdpSocket, didAcceptNewSocket newSocket: GCDAsyncUdpSocket) {
        print("New client connected from:", newSocket.connectedHost)
    }
}
