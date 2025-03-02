import Foundation
import os.log

@objcMembers
@objc public class ImageUpscaler: NSObject, NSSecureCoding {
    public static let shared = ImageUpscaler()
    private var connection: NSXPCConnection?
    private var progressCallback: ((String) -> Void)?
    private let logger = Logger(subsystem: "Timob.upscallerapp", category: "ImageUpscaler")
    private var isReconnecting = false
    
    // Реализация NSSecureCoding
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    public func encode(with coder: NSCoder) {
        // В данном случае нам не нужно кодировать никакие свойства
    }
    
    required public init?(coder: NSCoder) {
        super.init()
        setupXPCConnection()
    }
    
    private override init() {
        super.init()
        setupXPCConnection()
    }
    
    private func setupXPCConnection() {
        guard !isReconnecting else {
            logger.debug("Пропуск повторного подключения - уже в процессе")
            return
        }
        
        logger.debug("Настройка XPC соединения...")
        isReconnecting = true
        
        // Инвалидируем старое соединение, если оно существует
        if let oldConnection = connection {
            logger.debug("Закрытие старого соединения")
            oldConnection.invalidate()
            connection = nil
        }
        
        logger.debug("Создание нового XPC соединения")
        let newConnection = NSXPCConnection(serviceName: "Timob.ImageUpscalerService")
        
        // Настраиваем интерфейсы
        logger.debug("Настройка интерфейсов XPC")
        newConnection.remoteObjectInterface = NSXPCInterface(with: ImageUpscalerProtocol.self)
        newConnection.exportedInterface = NSXPCInterface(with: NSObjectProtocol.self)
        newConnection.exportedObject = self
        
        // Добавляем обработчик ошибок
        newConnection.interruptionHandler = { [weak self] in
            self?.logger.error("XPC соединение прервано, причина: прерывание")
            self?.isReconnecting = false
            self?.reconnectXPC()
        }
        
        newConnection.invalidationHandler = { [weak self] in
            self?.logger.error("XPC соединение недействительно, причина: инвалидация")
            self?.isReconnecting = false
            self?.reconnectXPC()
        }
        
        // Устанавливаем соединение
        logger.debug("Установка нового соединения")
        connection = newConnection
        
        // Проверяем соединение перед resume
        guard connection != nil else {
            logger.error("Не удалось создать XPC соединение")
            isReconnecting = false
            return
        }
        
        logger.debug("Запуск XPC соединения")
        connection?.resume()
        
        // Проверяем, что соединение активно
        if connection?.remoteObjectProxy as? ImageUpscalerProtocol != nil {
            logger.debug("XPC соединение успешно установлено и получен прокси сервиса")
        } else {
            logger.error("Не удалось получить remoteObjectProxy после установки соединения")
        }
        
        isReconnecting = false
        logger.debug("XPC соединение настроено")
    }
    
    private func reconnectXPC() {
        guard !isReconnecting else {
            logger.debug("Пропуск переподключения - уже в процессе")
            return
        }
        
        logger.debug("Планирование переподключения XPC через 1 секунду")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, !self.isReconnecting else {
                self?.logger.debug("Отмена переподключения - состояние изменилось")
                return
            }
            self.logger.debug("Попытка переподключения XPC...")
            self.setupXPCConnection()
        }
    }
    
    public func setProgressCallback(_ callback: @escaping (String) -> Void) {
        logger.debug("Установка callback для прогресса")
        self.progressCallback = callback
        if let service = connection?.remoteObjectProxy as? ImageUpscalerProtocol {
            let observerId = String(describing: ObjectIdentifier(self))
            service.addProgressObserver(observerId) { [weak self] message in
                self?.logger.debug("Получено сообщение о прогрессе: \(message)")
                self?.progressCallback?(message)
            }
        } else {
            logger.error("Не удалось получить remoteObjectProxy для установки callback")
        }
    }
    
    public func upscaleImage(at inputPath: String, outputPath: String, scale: Int = 2) async throws {
        logger.debug("Начало обработки изображения. Путь входного файла: \(inputPath)")
        logger.debug("Выходной путь: \(outputPath)")
        logger.debug("Масштаб: \(scale)")
        
        // Проверяем существование входного файла
        if !FileManager.default.fileExists(atPath: inputPath) {
            logger.error("Входной файл не существует: \(inputPath)")
            throw NSError(domain: "ImageUpscaler",
                         code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Input file does not exist: \(inputPath)"])
        }
        
        guard let connection = connection else {
            logger.error("XPC соединение отсутствует")
            throw NSError(domain: "ImageUpscaler",
                         code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "XPC connection not available"])
        }
        
        guard let service = connection.remoteObjectProxy as? ImageUpscalerProtocol else {
            logger.error("Не удалось получить remoteObjectProxy")
            throw NSError(domain: "ImageUpscaler",
                         code: 3,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to get remote object proxy"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            logger.debug("Вызов upscaleImage на сервисе...")
            
            // Создаем DispatchWorkItem для таймаута
            let timeoutWork = DispatchWorkItem { [weak self] in
                self?.logger.error("Таймаут операции upscaleImage после 180 секунд ожидания")
                continuation.resume(throwing: NSError(domain: "ImageUpscaler",
                                                   code: 4,
                                                   userInfo: [NSLocalizedDescriptionKey: "Operation timeout after 180 seconds"]))
            }
            
            // Устанавливаем таймаут в 180 секунд вместо 120
            logger.debug("Установка таймаута 180 секунд")
            DispatchQueue.main.asyncAfter(deadline: .now() + 180, execute: timeoutWork)
            
            // Добавляем периодическое логирование для отслеживания прогресса
            for i in 1...17 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i * 10)) { [weak self] in
                    if !timeoutWork.isCancelled {
                        self?.logger.debug("Операция выполняется уже \(i * 10) секунд...")
                        
                        // Проверяем существование выходного файла каждые 10 секунд
                        if FileManager.default.fileExists(atPath: outputPath) {
                            if let attributes = try? FileManager.default.attributesOfItem(atPath: outputPath),
                               let fileSize = attributes[.size] as? UInt64, fileSize > 0 {
                                self?.logger.debug("Выходной файл существует, размер: \(fileSize) байт")
                                
                                // Если файл существует и имеет ненулевой размер, но callback еще не вызван,
                                // возможно, XPC сервис завис после создания файла
                                if i >= 6 && !timeoutWork.isCancelled { // Проверяем после 60 секунд
                                    self?.logger.debug("Выходной файл существует, но callback не вызван. Возможно, XPC сервис завис.")
                                }
                            }
                        }
                    }
                }
            }
            
            service.upscaleImage(inputPath: inputPath, outputPath: outputPath, scale: scale) { [weak self] error in
                guard let self = self else { return }
                
                // Отменяем таймаут
                self.logger.debug("Отмена таймаута - получен ответ")
                timeoutWork.cancel()
                
                if let error = error {
                    self.logger.error("Ошибка при обработке изображения: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    // Проверяем существование выходного файла
                    if FileManager.default.fileExists(atPath: outputPath) {
                        if let attributes = try? FileManager.default.attributesOfItem(atPath: outputPath),
                           let fileSize = attributes[.size] as? UInt64, fileSize > 0 {
                            self.logger.debug("Выходной файл существует, размер: \(fileSize) байт")
                            self.logger.debug("Обработка изображения завершена успешно")
                            continuation.resume(returning: ())
                        } else {
                            self.logger.error("Выходной файл существует, но имеет нулевой размер")
                            continuation.resume(throwing: NSError(domain: "ImageUpscaler",
                                                               code: 5,
                                                               userInfo: [NSLocalizedDescriptionKey: "Output file exists but has zero size"]))
                        }
                    } else {
                        self.logger.error("Выходной файл не существует, хотя сервис сообщил об успешном завершении")
                        continuation.resume(throwing: NSError(domain: "ImageUpscaler",
                                                           code: 6,
                                                           userInfo: [NSLocalizedDescriptionKey: "Output file does not exist after successful completion"]))
                    }
                }
            }
        }
    }
    
    deinit {
        logger.debug("Деинициализация ImageUpscaler")
        if let service = connection?.remoteObjectProxy as? ImageUpscalerProtocol {
            let observerId = String(describing: ObjectIdentifier(self))
            service.removeProgressObserver(observerId)
        }
        connection?.invalidate()
    }
} 