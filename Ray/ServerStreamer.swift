//
//  ServerStreamer.swift
//  Ray
//
//  Created by Samuel Seng on 10/1/22.
//  Adopted from https://github.com/twittemb/StreamIt

import Foundation
import CocoaAsyncSocket

func getIP() -> [String]  {
    var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
    var addresses: [String] = []
    if getifaddrs(&ifaddr) == 0 {
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            guard let interface = ptr?.pointee else { continue }
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                // wifi = ["en0"]
                let name: String = String(cString: interface.ifa_name)
                if (name.starts(with: "en")) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    let address = String(cString: hostname)
                    addresses.append(address)
                    print("Address:", address)
                }
            }
        }
        freeifaddrs(ifaddr)
    }
    return addresses
}


class ServerStreamer: NSObject, GCDAsyncSocketDelegate {
    fileprivate var serverSocket: GCDAsyncSocket?
    fileprivate var clients = [Int: StreamingSession]()
    
    let serverQueue = DispatchQueue(label: "ServerQueue", attributes: [])
    let clientQueue = DispatchQueue(label: "ClientQueue", attributes: .concurrent)
    let socketQueue = DispatchQueue(label: "SocketQueue", attributes: .concurrent)
    
    let ip: String
    let port: UInt16
    init(ip: String, port: UInt16 = 10001) {
        self.ip = ip
        self.port = port
        super.init()
        
        self.serverSocket = GCDAsyncSocket(delegate: self, delegateQueue: self.serverQueue, socketQueue: self.socketQueue)
        
        do {
            try self.serverSocket?.accept(onInterface: ip, port: self.port)
            print("===== Listening on", ip, ":", port, "=====")
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
    
    func stopStreaming() {
        for (key, client) in self.clients {
            client.close()
            self.clients.removeValue(forKey: key)
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
