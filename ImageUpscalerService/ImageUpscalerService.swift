//
//  ImageUpscalerService.swift
//  ImageUpscalerService
//
//  Created by Тимофей Булаев on 10.02.2025.
//

import Foundation
import UpscalerShared
import os.log
import AppKit

// Расширение для CFString, чтобы можно было преобразовать тип изображения в строку
extension CFString {
    func toString() -> String {
        return self as String
    }
}

/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
class ImageUpscalerService: NSObject, ImageUpscalerProtocol {
    
    /// This implements the example protocol. Replace the body of this class with the implementation of this service's protocol.
    @objc func performCalculation(firstNumber: Int, secondNumber: Int, with reply: @escaping (Int) -> Void) {
        let response = firstNumber + secondNumber
        reply(response)
    }

    private var observers: [String: (String) -> Void] = [:]
    private let logger = Logger(subsystem: "Timob.ImageUpscalerService", category: "Service")
    
    func addProgressObserver(_ observerId: String, callback: @escaping (String) -> Void) {
        let logMessage: String = "Добавление наблюдателя прогресса: \(observerId)"
        logger.debug("\(logMessage, privacy: .public)")
        
        observers[observerId] = callback
        logger.debug("Текущее количество наблюдателей: \(self.observers.count, privacy: .public)")
    }
    
    func removeProgressObserver(_ observerId: String) {
        let logMessage: String = "Удаление наблюдателя прогресса: \(observerId)"
        logger.debug("\(logMessage, privacy: .public)")
        observers.removeValue(forKey: observerId)
        logger.debug("Текущее количество наблюдателей: \(self.observers.count, privacy: .public)")
    }
    
    private func notifyProgress(_ message: String) {
        let observersCount: Int = self.observers.count
        let logMessage: String = String(format: "Отправка сообщения о прогрессе: %@ для %d наблюдателей", message, observersCount)
        logger.debug("\(logMessage, privacy: .public)")
        self.observers.forEach { observerId, callback in
            let observerMessage: String = String(format: "Отправка наблюдателю: %@", observerId)
            logger.debug("\(observerMessage, privacy: .public)")
            callback(message)
        }
    }

    func upscaleImage(inputPath: String, outputPath: String, scale: Int, withReply reply: @escaping (Error?) -> Void) {
        logger.debug("Запрос на обработку изображения. Входной путь: \(inputPath), выходной путь: \(outputPath), масштаб: \(scale)")
        
        // Проверяем существование входного файла
        if !FileManager.default.fileExists(atPath: inputPath) {
            logger.error("Входной файл не существует: \(inputPath)")
            reply(NSError(domain: "ImageUpscalerService",
                         code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Input file does not exist: \(inputPath)"]))
            return
        }
        
        // Проверяем доступность директории для выходного файла
        let outputDirectory = (outputPath as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: outputDirectory) {
            do {
                try FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
                logger.debug("Создана директория для выходного файла: \(outputDirectory)")
            } catch {
                logger.error("Не удалось создать директорию для выходного файла: \(error.localizedDescription)")
                reply(error)
                return
            }
        }
        
        // Удаляем выходной файл, если он уже существует
        if FileManager.default.fileExists(atPath: outputPath) {
            do {
                try FileManager.default.removeItem(atPath: outputPath)
                logger.debug("Удален существующий выходной файл: \(outputPath)")
            } catch {
                logger.error("Не удалось удалить существующий выходной файл: \(error.localizedDescription)")
                // Продолжаем выполнение, так как это не критическая ошибка
            }
        }
        
        // Получаем путь к исполняемому файлу
        guard let executableURL = Bundle.main.url(forResource: "waifu2x-ncnn-vulkan", withExtension: nil) else {
            logger.error("Не удалось найти исполняемый файл waifu2x-ncnn-vulkan")
            reply(NSError(domain: "ImageUpscalerService",
                         code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Executable file not found"]))
            return
        }
        
        // Проверяем права на исполнение
        let attributes = [FileAttributeKey.posixPermissions: 0o755]
        do {
            try FileManager.default.setAttributes(attributes, ofItemAtPath: executableURL.path)
            logger.debug("Установлены права на исполнение для \(executableURL.path)")
        } catch {
            logger.error("Не удалось установить права на исполнение: \(error.localizedDescription)")
            // Продолжаем выполнение, так как файл может уже иметь нужные права
        }
        
        // Проверяем наличие директории с моделями
        let modelsDirectory = Bundle.main.resourceURL?.appendingPathComponent("models-cunet").path ?? ""
        if !FileManager.default.fileExists(atPath: modelsDirectory) {
            logger.error("Директория с моделями не найдена: \(modelsDirectory)")
            reply(NSError(domain: "ImageUpscalerService",
                         code: 3,
                         userInfo: [NSLocalizedDescriptionKey: "Models directory not found: \(modelsDirectory)"]))
            return
        }
        
        // Проверяем содержимое директории с моделями
        do {
            let modelFiles = try FileManager.default.contentsOfDirectory(atPath: modelsDirectory)
            logger.debug("Содержимое директории с моделями (\(modelFiles.count) файлов): \(modelFiles.joined(separator: ", "))")
            
            if modelFiles.isEmpty {
                logger.error("Директория с моделями пуста: \(modelsDirectory)")
                reply(NSError(domain: "ImageUpscalerService",
                             code: 4,
                             userInfo: [NSLocalizedDescriptionKey: "Models directory is empty: \(modelsDirectory)"]))
                return
            }
        } catch {
            logger.error("Не удалось получить содержимое директории с моделями: \(error.localizedDescription)")
            // Продолжаем выполнение, так как это может быть проблема с правами доступа
        }
        
        // Формируем команду
        let process = Process()
        process.executableURL = executableURL
        
        // Устанавливаем рабочую директорию в директорию с ресурсами
        process.currentDirectoryURL = Bundle.main.resourceURL
        
        // Аргументы команды
        let arguments = [
            "-i", inputPath,
            "-o", outputPath,
            "-s", String(scale),
            "-m", "models-cunet",
            "-n", "0",  // noise level
            "-t", "4",  // thread count
            "-g", "0",  // GPU ID
            "-j", "0:0:0:0", // preprocess:gpu:postprocess:tta
            "-f", "jpg" // output format
        ]
        process.arguments = arguments
        
        logger.debug("Команда: \(executableURL.path) \(arguments.joined(separator: " "))")
        
        // Настраиваем перенаправление вывода
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Обработчики для вывода
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        
        var outputData = Data()
        var errorData = Data()
        
        // Создаем группу для отслеживания завершения всех задач
        let dispatchGroup = DispatchGroup()
        
        // Обработка стандартного вывода
        dispatchGroup.enter()
        outputHandle.readabilityHandler = { [self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                if let output = String(data: data, encoding: .utf8) {
                    self.logger.debug("Вывод процесса: \(output)")
                    outputData.append(data)
                }
            } else {
                self.logger.debug("Получен пустой вывод, закрытие обработчика")
                handle.readabilityHandler = nil
                dispatchGroup.leave()
            }
        }
        
        // Обработка вывода ошибок
        dispatchGroup.enter()
        errorHandle.readabilityHandler = { [self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                if let error = String(data: data, encoding: .utf8) {
                    self.logger.debug("Вывод ошибок процесса: \(error)")
                    errorData.append(data)
                }
            } else {
                self.logger.debug("Получен пустой вывод ошибок, закрытие обработчика")
                handle.readabilityHandler = nil
                dispatchGroup.leave()
            }
        }
        
        // Устанавливаем обработчик завершения процесса
        process.terminationHandler = { [weak self] process in
            guard let self = self else { return }
            
            // Закрываем файловые дескрипторы
            outputHandle.closeFile()
            errorHandle.closeFile()
            
            // Проверяем статус завершения процесса
            self.logger.debug("Process terminated with status \(process.terminationStatus)")
            
            // Проверяем существование выходного файла
            if FileManager.default.fileExists(atPath: outputPath) {
                self.logger.debug("Output file exists at \(outputPath)")
                reply(nil)
            } else {
                self.logger.debug("Output file does not exist at \(outputPath)")
                let error = NSError(domain: "ImageUpscalerService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to upscale image. Output file not found."])
                reply(error)
            }
            
            dispatchGroup.leave()
        }
        
        // Запускаем процесс
        do {
            try process.run()
            logger.debug("Процесс запущен")
        } catch {
            logger.error("Не удалось запустить процесс: \(error.localizedDescription)")
            reply(error)
        }
    }
}
