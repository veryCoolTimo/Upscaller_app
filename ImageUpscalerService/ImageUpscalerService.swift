//
//  ImageUpscalerService.swift
//  ImageUpscalerService
//
//  Created by Тимофей Булаев on 10.02.2025.
//

import Foundation
import UpscalerShared
import os.log

/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
class ImageUpscalerService: NSObject, ImageUpscalerServiceProtocol {
    
    /// This implements the example protocol. Replace the body of this class with the implementation of this service's protocol.
    @objc func performCalculation(firstNumber: Int, secondNumber: Int, with reply: @escaping (Int) -> Void) {
        let response = firstNumber + secondNumber
        reply(response)
    }

    private var observers: [NSObject: (String) -> Void] = [:]
    private let logger = Logger(subsystem: "Timob.ImageUpscalerService", category: "Service")
    
    func addProgressObserver(_ observer: NSObject, callback: @escaping (String) -> Void) {
        let logMessage: String = "Добавление наблюдателя прогресса: \(ObjectIdentifier(observer))"
        logger.debug("\(logMessage)")
        
        // Настраиваем разрешенные классы для XPC
        let interface = NSXPCInterface(with: ImageUpscalerServiceProtocol.self)
        let classes = NSSet(array: [NSObject.self, ImageUpscaler.self]) as! Set<AnyHashable>
        interface.setClasses(classes, for: #selector(ImageUpscalerServiceProtocol.addProgressObserver(_:callback:)), argumentIndex: 0, ofReply: false)
        
        observers[observer] = callback
        logger.debug("Текущее количество наблюдателей: \(self.observers.count)")
    }
    
    func removeProgressObserver(_ observer: NSObject) {
        let logMessage: String = "Удаление наблюдателя прогресса: \(ObjectIdentifier(observer))"
        logger.debug("\(logMessage)")
        observers.removeValue(forKey: observer)
        logger.debug("Текущее количество наблюдателей: \(self.observers.count)")
    }
    
    private func notifyProgress(_ message: String) {
        let observersCount: Int = self.observers.count
        let logMessage: String = String(format: "Отправка сообщения о прогрессе: %@ для %d наблюдателей", message, observersCount)
        logger.debug("\(logMessage)")
        self.observers.forEach { observer, callback in
            let observerId: ObjectIdentifier = ObjectIdentifier(observer)
            let observerMessage: String = String(format: "Отправка наблюдателю: %@", String(describing: observerId))
            logger.debug("\(observerMessage)")
            callback(message)
        }
    }

    func upscaleImage(inputPath: String, outputPath: String, scale: Int, withReply reply: @escaping (Error?) -> Void) {
        logger.debug("Начало обработки изображения: \(inputPath)")
        logger.debug("Выходной путь: \(outputPath)")
        logger.debug("Масштаб: \(scale)")
        
        // Находим путь к waifu2x-ncnn-vulkan
        let bundle = Bundle(for: type(of: self))
        let resourcesPath = bundle.bundlePath + "/Contents/Resources"
        let waifu2xPath = resourcesPath + "/waifu2x-ncnn-vulkan"
        let modelsPath = resourcesPath
        
        logger.debug("Путь к ресурсам: \(resourcesPath)")
        logger.debug("Путь к waifu2x: \(waifu2xPath)")
        logger.debug("Путь к моделям: \(modelsPath)")
        
        // Проверяем наличие директорий и файлов
        let fileManager = FileManager.default
        
        // Проверяем существование директории ресурсов
        guard fileManager.fileExists(atPath: resourcesPath) else {
            logger.error("Директория ресурсов не найдена: \(resourcesPath)")
            reply(NSError(domain: "ImageUpscalerService",
                         code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Resources directory not found"]))
            return
        }
        
        // Выводим содержимое директории ресурсов
        logger.debug("Содержимое директории ресурсов:")
        if let contents = try? fileManager.contentsOfDirectory(atPath: resourcesPath) {
            contents.forEach { logger.debug(" - \($0)") }
        }
        
        // Проверяем наличие бинарного файла
        guard fileManager.fileExists(atPath: waifu2xPath) else {
            logger.error("Не найден бинарный файл waifu2x-ncnn-vulkan")
            reply(NSError(domain: "ImageUpscalerService",
                         code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "waifu2x-ncnn-vulkan not found"]))
            return
        }
        
        // Проверяем наличие файлов моделей
        let requiredModelFiles = [
            "noise2_scale2.0x_model.param",
            "noise2_scale2.0x_model.bin"
        ]
        
        for modelFile in requiredModelFiles {
            let modelPath = (modelsPath as NSString).appendingPathComponent(modelFile)
            guard fileManager.fileExists(atPath: modelPath) else {
                logger.error("Файл модели не найден: \(modelPath)")
                reply(NSError(domain: "ImageUpscalerService",
                             code: 4,
                             userInfo: [NSLocalizedDescriptionKey: "Model file not found: \(modelFile)"]))
                return
            }
        }
        
        // Создаем рабочую директорию во временной папке
        let workDirPath = NSTemporaryDirectory() + "/waifu2x-work"
        try? fileManager.createDirectory(atPath: workDirPath, withIntermediateDirectories: true, attributes: nil)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: waifu2xPath)
        process.currentDirectoryURL = URL(fileURLWithPath: workDirPath)
        
        // Настраиваем параметры
        var arguments = [
            "-i", inputPath,      // входной файл
            "-o", outputPath,     // выходной файл
            "-n", "2",           // уровень шумоподавления (0-3)
            "-s", String(scale),  // масштаб (2/3/4)
            "-m", "models-cunet", // путь к моделям (относительно текущей директории)
            "-v"                  // подробный вывод
        ]
        
        // Если у нас есть GPU с поддержкой Metal, используем его
        if #available(macOS 10.15, *) {
            arguments.append(contentsOf: ["-g", "0"])  // использовать GPU 0
        }
        
        process.arguments = arguments
        process.currentDirectoryPath = resourcesPath  // Устанавливаем текущую директорию в Resources
        logger.debug("Аргументы команды: \(arguments.joined(separator: " "))")
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        logger.debug("Настройка обработчика вывода")
        let outputHandle = pipe.fileHandleForReading
        outputHandle.readabilityHandler = { [weak self] handle in
            guard let self = self else {
                self?.logger.error("self is nil в обработчике вывода")
                return
            }
            
            let data = handle.availableData
            if data.count > 0 {
                if let output = String(data: data, encoding: .utf8) {
                    output.split(separator: "\n").forEach { line in
                        let lineStr = String(line)
                        if lineStr.contains("%") {
                            // Извлекаем процент выполнения
                            if let progress = lineStr.split(separator: " ").first(where: { $0.contains("%") }) {
                                self.notifyProgress("Обработка: \(progress)")
                            }
                        }
                        self.logger.debug("Вывод процесса: \(lineStr)")
                    }
                } else {
                    self.logger.error("Не удалось декодировать вывод процесса")
                }
            } else {
                self.logger.debug("Получен пустой вывод, закрытие обработчика")
                outputHandle.readabilityHandler = nil
            }
        }
        
        do {
            logger.debug("Запуск процесса waifu2x")
            try process.run()
            
            logger.debug("Ожидание завершения процесса")
            process.waitUntilExit()
            
            logger.debug("Процесс завершился с кодом: \(process.terminationStatus)")
            outputHandle.readabilityHandler = nil
            
            if process.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Процесс завершился с ошибкой: \(output)")
                reply(NSError(domain: "ImageUpscalerService", 
                            code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: output]))
            } else {
                logger.debug("Процесс успешно завершен")
                reply(nil)
            }
        } catch {
            logger.error("Ошибка при запуске процесса: \(error.localizedDescription)")
            outputHandle.readabilityHandler = nil
            reply(error)
        }
    }
}
