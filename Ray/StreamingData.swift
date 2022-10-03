//
//  StreamingData.swift
//  Ray
//
//  Created by Samuel Seng on 10/3/22.
//

import Foundation


class StreamingData {
    static func getJpegHeaders() -> Data {
        let headers = [
            "HTTP/1.0 200 OK",
            "Connection: keep-alive",
            "Ma-age: 0",
            "Expires: 0",
            "Cache-Control: no-store,must-revalidate",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Headers: accept,content-type",
            "Access-Control-Allow-Methods: GET",
            "Access-Control-expose-headers: Cache-Control,Content-Encoding",
            "Pragma: no-cache",
            "Content-type: multipart/x-mixed-replace; boundary=0123456789876543210",
            ""
        ]

        let headersData = headers.joined(separator: "\r\n").data(using: String.Encoding.utf8)
        if headersData == nil {
            print("Could not make headers data")
        }
        return headersData!
    }
    
    static func getJpegFrameHeaders(dataCount: Int, size: Int) -> Data {
        let frameHeaders = [
            "",
            "--0123456789876543210",
            "Content-Type: application/json",
            "Content-Length: \(dataCount)",
            "",
            ""
        ]

        let text = frameHeaders.joined(separator: "\r\n")
        let paddedText = text.padding(toLength: size, withPad: " ", startingAt: 0)
        let frameHeadersData = paddedText.data(using: String.Encoding.utf8)
        if frameHeadersData == nil {
            print("Could not make frame headers data")
        }
        return frameHeadersData!
    }
    
    static func getJpegFrameFooters() -> Data {
        let footers = ["", ""].joined(separator: "\r\n").data(using: String.Encoding.utf8)
        if footers == nil {
            print("Count not make frame footers data")
        }
        return footers!
    }
}
