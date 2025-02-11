//
//  ImageUpscalerServiceProtocol.swift
//  ImageUpscalerService
//
//  Created by Тимофей Булаев on 10.02.2025.
//

import Foundation

/// The protocol that this service will vend as its API. This protocol will also need to be visible to the process hosting the service.
@objc protocol ImageUpscalerServiceProtocol: NSObjectProtocol {
    func upscaleImage(inputPath: String, outputPath: String, scale: Int, withReply reply: @escaping (Error?) -> Void)
    func addProgressObserver(_ observer: NSObject, callback: @escaping (String) -> Void)
    func removeProgressObserver(_ observer: NSObject)
}

/*
 To use the service from an application or other process, use NSXPCConnection to establish a connection to the service by doing something like this:

     connectionToService = NSXPCConnection(serviceName: "Timob.ImageUpscalerService")
     connectionToService.remoteObjectInterface = NSXPCInterface(with: ImageUpscalerServiceProtocol.self)
     connectionToService.resume()

 Once you have a connection to the service, you can use it like this:

     if let proxy = connectionToService.remoteObjectProxy as? ImageUpscalerServiceProtocol {
         proxy.performCalculation(firstNumber: 23, secondNumber: 19) { result in
             NSLog("Result of calculation is: \(result)")
         }
     }

 And, when you are finished with the service, clean up the connection like this:

     connectionToService.invalidate()
*/
