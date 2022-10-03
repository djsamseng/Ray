//
//  ServerStreamer.swift
//  Ray
//
//  Created by Samuel Seng on 10/1/22.
//  Adopted from https://github.com/twittemb/StreamIt

import Foundation
import CocoaAsyncSocket

func getIP() -> String  {
    var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
    var address = ""
    if getifaddrs(&ifaddr) == 0 {
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            guard let interface = ptr?.pointee else { return "" }
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                // wifi = ["en0"]
                let name: String = String(cString: interface.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
    }
    return address
}


class ServerStreamer: NSObject, GCDAsyncSocketDelegate {
    fileprivate var serverSocket: GCDAsyncSocket?
    fileprivate var clients = [Int: StreamingSession]()
    
    let serverQueue = DispatchQueue(label: "ServerQueue", attributes: [])
    let clientQueue = DispatchQueue(label: "ClientQueue", attributes: .concurrent)
    let socketQueue = DispatchQueue(label: "SocketQueue", attributes: .concurrent)
    
    let port: UInt16 = 10001
    override init() {
        super.init()
        let ip = getIP()
        print("IP:", ip)
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
        let newClient = StreamingSession(id: clientId, client: newSocket, queue: self.clientQueue)
        self.clients[clientId] = newClient
        newClient.startStreaming()
    }
}
