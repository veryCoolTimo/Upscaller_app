//
//  main.swift
//  ImageUpscalerService
//
//  Created by Тимофей Булаев on 10.02.2025.
//

import Foundation
import os.log

let logger = Logger(subsystem: "Timob.ImageUpscalerService", category: "XPCService")

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    
    /// This method is where the NSXPCListener configures, accepts, and resumes a new incoming NSXPCConnection.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        logger.debug("Получен новый запрос на соединение")
        
        // Configure the connection.
        // First, set the interface that the exported object implements.
        newConnection.exportedInterface = NSXPCInterface(with: ImageUpscalerServiceProtocol.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: NSObjectProtocol.self)
        
        // Next, set the object that the connection exports. All messages sent on the connection to this service will be sent to the exported object to handle. The connection retains the exported object.
        let exportedObject = ImageUpscalerService()
        newConnection.exportedObject = exportedObject
        
        // Добавляем обработчики ошибок
        newConnection.invalidationHandler = {
            logger.error("Соединение стало недействительным")
        }
        
        newConnection.interruptionHandler = {
            logger.error("Соединение прервано")
        }
        
        // Resuming the connection allows the system to deliver more incoming messages.
        newConnection.resume()
        logger.debug("Новое соединение настроено и запущено")
        
        // Returning true from this method tells the system that you have accepted this connection. If you want to reject the connection for some reason, call invalidate() on the connection and return false.
        return true
    }
}

// Create the delegate for the service.
logger.debug("Запуск XPC сервиса")
let delegate = ServiceDelegate()

// Set up the one NSXPCListener for this service. It will handle all incoming connections.
let listener = NSXPCListener.service()
listener.delegate = delegate

// Resuming the serviceListener starts this service. This method does not return.
logger.debug("Запуск XPC слушателя")
listener.resume()
