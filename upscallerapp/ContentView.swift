//
//  ContentView.swift
//  upscallerapp
//
//  Created by Тимофей Булаев on 10.02.2025.
//

import SwiftUI
import UniformTypeIdentifiers
import UpscalerShared

struct ContentView: View {
    @State private var inputImage: NSImage?
    @State private var outputImage: NSImage?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var scale = 2
    @State private var progressMessage = "Ожидание..."
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                VStack {
                    Text("Оригинал")
                        .font(.headline)
                    if let inputImage = inputImage {
                        Image(nsImage: inputImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 400, maxHeight: 400)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 400, height: 400)
                            .cornerRadius(10)
                            .overlay(
                                VStack {
                                    Image(systemName: "arrow.down.doc")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                    Text("Перетащите изображение сюда")
                                        .foregroundColor(.gray)
                                }
                            )
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers, location in
                    guard let provider = providers.first else { return false }
                    
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { urlData, error in
                        DispatchQueue.main.async {
                            if let urlData = urlData as? Data,
                               let path = String(data: urlData, encoding: .utf8),
                               let url = URL(string: path),
                               let image = NSImage(contentsOf: url) {
                                self.inputImage = image
                                self.outputImage = nil
                            }
                        }
                    }
                    return true
                }
                
                VStack {
                    Text("Результат")
                        .font(.headline)
                    if let outputImage = outputImage {
                        Image(nsImage: outputImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 400, maxHeight: 400)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 400, height: 400)
                            .cornerRadius(10)
                            .overlay(
        VStack {
                                    if isProcessing {
                                        ProgressView()
                                            .scaleEffect(1.5)
                                            .padding(.bottom)
                                        Text(progressMessage)
                                            .foregroundColor(.gray)
                                    } else {
                                        Text("Результат обработки")
                                            .foregroundColor(.gray)
                                    }
                                }
                            )
                    }
                }
            }
            .padding()
            
            HStack(spacing: 20) {
                Picker("Масштаб:", selection: $scale) {
                    Text("2x").tag(2)
                    Text("3x").tag(3)
                    Text("4x").tag(4)
                }
                .frame(width: 100)
                
                Button("Выбрать изображение") {
                    selectImage()
                }
                
                Button("Обработать") {
                    Task {
                        await processImage()
                    }
                }
                .disabled(inputImage == nil || isProcessing)
                
                if outputImage != nil {
                    Button("Сохранить результат") {
                        saveResult()
                    }
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .alert("Ошибка", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Неизвестная ошибка")
        }
        .onAppear {
            setupProgressCallback()
        }
    }
    
    private func setupProgressCallback() {
        ImageUpscaler.shared.setProgressCallback { message in
            DispatchQueue.main.async {
                self.progressMessage = message
            }
        }
    }
    
    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let image = NSImage(contentsOf: url) {
                    DispatchQueue.main.async {
                        self.inputImage = image
                        self.outputImage = nil
                    }
                }
            }
        }
    }
    
    private func saveResult() {
        guard let outputImage = outputImage else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.jpeg, .png]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Сохранить увеличенное изображение"
        savePanel.message = "Выберите место для сохранения изображения"
        savePanel.nameFieldLabel = "Имя файла:"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                print("Сохранение изображения в: \(url.path)")
                
                // Попробуем несколько способов сохранения изображения
                var success = false
                
                // Определяем формат сохранения на основе расширения файла
                let isJpeg = url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg"
                let format = isJpeg ? NSBitmapImageRep.FileType.jpeg : NSBitmapImageRep.FileType.png
                
                // Способ 1: Через TIFFRepresentation
                if let tiffData = outputImage.tiffRepresentation,
                   let imageRep = NSBitmapImageRep(data: tiffData) {
                    let properties: [NSBitmapImageRep.PropertyKey: Any] = isJpeg ? [.compressionFactor: 0.9] : [:]
                    if let imageData = imageRep.representation(using: format, properties: properties) {
                        do {
                            try imageData.write(to: url)
                            print("Изображение успешно сохранено через TIFFRepresentation")
                            success = true
                        } catch {
                            print("Ошибка при сохранении через TIFFRepresentation: \(error.localizedDescription)")
                        }
                    }
                }
                
                // Способ 2: Через CGImage, если первый способ не сработал
                if !success, let cgImage = outputImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                    let properties: [NSBitmapImageRep.PropertyKey: Any] = isJpeg ? [.compressionFactor: 0.9] : [:]
                    if let imageData = bitmapRep.representation(using: format, properties: properties) {
                        do {
                            try imageData.write(to: url)
                            print("Изображение успешно сохранено через CGImage")
                            success = true
                        } catch {
                            print("Ошибка при сохранении через CGImage: \(error.localizedDescription)")
                            self.errorMessage = "Ошибка при сохранении: \(error.localizedDescription)"
                            self.showError = true
                        }
                    }
                }
                
                // Способ 3: Прямое сохранение через NSImage, если предыдущие способы не сработали
                if !success {
                    do {
                        // Создаем новый контекст для рисования
                        let size = outputImage.size
                        let imageRect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
                        
                        if let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                                 bitsPerComponent: 8, bytesPerRow: 0,
                                                 space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) {
                            
                            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                            NSGraphicsContext.saveGraphicsState()
                            NSGraphicsContext.current = nsContext
                            
                            outputImage.draw(in: imageRect)
                            
                            NSGraphicsContext.restoreGraphicsState()
                            
                            if let cgImage = context.makeImage() {
                                let newImage = NSImage(cgImage: cgImage, size: size)
                                if let tiffData = newImage.tiffRepresentation,
                                   let imageRep = NSBitmapImageRep(data: tiffData) {
                                    let properties: [NSBitmapImageRep.PropertyKey: Any] = isJpeg ? [.compressionFactor: 0.9] : [:]
                                    if let imageData = imageRep.representation(using: format, properties: properties) {
                                        try imageData.write(to: url)
                                        print("Изображение успешно сохранено через контекст рисования")
                                        success = true
                                    }
                                }
                            }
                        }
                    } catch {
                        print("Ошибка при сохранении через контекст рисования: \(error.localizedDescription)")
                        self.errorMessage = "Ошибка при сохранении: \(error.localizedDescription)"
                        self.showError = true
                    }
                }
                
                if !success {
                    self.errorMessage = "Не удалось сохранить изображение. Попробуйте другой формат."
                    self.showError = true
                }
            }
        }
    }
    
    private func processImage() async {
        guard let inputImage = inputImage else { return }
        
        isProcessing = true
        progressMessage = "Подготовка..."
        defer { isProcessing = false }
        
        let tempInputURL = FileManager.default.temporaryDirectory.appendingPathComponent("input.png")
        let tempOutputURL = FileManager.default.temporaryDirectory.appendingPathComponent("output.png")
        
        // Удаляем старые файлы, если они существуют
        try? FileManager.default.removeItem(at: tempInputURL)
        try? FileManager.default.removeItem(at: tempOutputURL)
        
        do {
            print("Сохранение входного изображения: \(tempInputURL.path)")
            
            // Проверяем входное изображение
            print("Размер входного изображения: \(inputImage.size)")
            print("Количество представлений: \(inputImage.representations.count)")
            for (index, rep) in inputImage.representations.enumerated() {
                print("Представление \(index): размер=\(rep.size), bitsPerSample=\(rep.bitsPerSample), pixelsWide=\(rep.pixelsWide), pixelsHigh=\(rep.pixelsHigh)")
            }
            
            // Сохраняем входное изображение
            if let cgImage = inputImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                print("Входной CGImage: width=\(cgImage.width), height=\(cgImage.height), bitsPerComponent=\(cgImage.bitsPerComponent)")
                
                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                print("Созданное представление: размер=\(bitmapRep.size), bitsPerSample=\(bitmapRep.bitsPerSample), pixelsWide=\(bitmapRep.pixelsWide), pixelsHigh=\(bitmapRep.pixelsHigh)")
                
                if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                    try pngData.write(to: tempInputURL)
                    print("Размер входного файла: \(pngData.count) байт")
                    print("Первые 16 байт входного файла: \(Array(pngData.prefix(16)).map { String(format: "%02x", $0) }.joined())")
                }
            }
            
            // Проверяем, что входной файл существует и не пустой
            if let inputFileAttributes = try? FileManager.default.attributesOfItem(atPath: tempInputURL.path),
               let inputFileSize = inputFileAttributes[.size] as? Int64 {
                print("Размер входного файла на диске: \(inputFileSize) байт")
            }
            
            try await ImageUpscaler.shared.upscaleImage(
                at: tempInputURL.path,
                outputPath: tempOutputURL.path,
                scale: scale
            )
            
            // Проверяем, что выходной файл существует и не пустой
            guard FileManager.default.fileExists(atPath: tempOutputURL.path) else {
                print("Выходной файл не существует")
                throw NSError(domain: "ImageProcessing", code: 2, userInfo: [NSLocalizedDescriptionKey: "Выходной файл не найден"])
            }
            
            // Сохраняем копию файла в Documents для отладки
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let debugFileURL = documentsURL.appendingPathComponent("debug_result.png")
            try? FileManager.default.removeItem(at: debugFileURL)
            try? FileManager.default.copyItem(at: tempOutputURL, to: debugFileURL)
            print("Сохранена копия для проверки: \(debugFileURL.path)")
            
            // Анализируем пиксельные данные изображения
            if let outputData = try? Data(contentsOf: tempOutputURL),
               let imageSource = CGImageSourceCreateWithData(outputData as CFData, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                
                let width = cgImage.width
                let height = cgImage.height
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let bytesPerPixel = 4
                let bytesPerRow = bytesPerPixel * width
                let bitsPerComponent = 8
                
                var pixelData = [UInt8](repeating: 0, count: width * height * 4)
                let context = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
                
                if let context = context {
                    let rect = CGRect(x: 0, y: 0, width: width, height: height)
                    context.draw(cgImage, in: rect)
                    
                    // Проверим первые 20 пикселей
                    print("Анализ первых 20 пикселей:")
                    var allBlack = true
                    for i in 0..<min(20, width * height) {
                        let pixelIndex = i * 4
                        let alpha = pixelData[pixelIndex]
                        let red = pixelData[pixelIndex + 1]
                        let green = pixelData[pixelIndex + 2]
                        let blue = pixelData[pixelIndex + 3]
                        print("Пиксель \(i): alpha=\(alpha), R=\(red), G=\(green), B=\(blue)")
                        
                        if red > 10 || green > 10 || blue > 10 {
                            allBlack = false
                        }
                    }
                    
                    if allBlack {
                        print("ВНИМАНИЕ: Все проверенные пиксели близки к черному!")
                    }
                }
            }
            
            if let outputFileAttributes = try? FileManager.default.attributesOfItem(atPath: tempOutputURL.path),
               let outputFileSize = outputFileAttributes[.size] as? Int64 {
                print("Размер выходного файла: \(outputFileSize) байт")
                
                // Сохраняем копию для отладки
                let debugOutputURL = FileManager.default.temporaryDirectory.appendingPathComponent("debug_output.jpg")
                try? FileManager.default.removeItem(at: debugOutputURL)
                try? FileManager.default.copyItem(at: tempOutputURL, to: debugOutputURL)
                print("Сохранена копия для отладки: \(debugOutputURL.path)")
                
                // Загружаем выходное изображение через данные
                if let outputData = try? Data(contentsOf: tempOutputURL) {
                    print("Размер выходных данных: \(outputData.count) байт")
                    print("Первые 16 байт выходного файла: \(Array(outputData.prefix(16)).map { String(format: "%02x", $0) }.joined())")
                    
                    // НОВЫЙ ПОДХОД: Используем CGImageSource для создания изображения
                    if let imageSource = CGImageSourceCreateWithData(outputData as CFData, nil) {
                        let imageType = CGImageSourceGetType(imageSource)
                        print("Тип изображения: \(imageType as Any)")
                        
                        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
                            print("Свойства изображения: \(properties)")
                        }
                        
                        if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                            print("CGImage создан успешно: width=\(cgImage.width), height=\(cgImage.height)")
                            
                            // Попробуем несколько методов создания NSImage
                            
                            // Метод 1: Создание нового изображения с прямым указанием формата
                            let options: [NSString: Any] = [
                                kCGImageSourceCreateThumbnailFromImageAlways: true,
                                kCGImageSourceCreateThumbnailWithTransform: true,
                                kCGImageSourceThumbnailMaxPixelSize: max(cgImage.width, cgImage.height)
                            ]
                            
                            if let thumbnailCGImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                                let finalImage = NSImage(cgImage: thumbnailCGImage, size: NSSize(width: thumbnailCGImage.width, height: thumbnailCGImage.height))
                                print("Создан NSImage через thumbnail: \(finalImage.size)")
                                
                                DispatchQueue.main.async {
                                    self.outputImage = finalImage
                                    print("Изображение установлено через thumbnail")
                                }
                            } else {
                                // Метод 2: Создание через CIImage
                                let ciImage = CIImage(cgImage: cgImage)
                                let rep = NSCIImageRep(ciImage: ciImage)
                                let finalImage = NSImage(size: NSSize(width: cgImage.width, height: cgImage.height))
                                finalImage.addRepresentation(rep)
                                
                                print("Создан NSImage через CIImage: \(finalImage.size)")
                                
                                DispatchQueue.main.async {
                                    self.outputImage = finalImage
                                    print("Изображение установлено через CIImage")
                                }
                            }
                        } else {
                            print("Не удалось создать CGImage")
                            
                            // Альтернативный подход - попробуем создать NSImage напрямую
                            if let processedImage = NSImage(data: outputData) {
                                print("Успешно создан NSImage из данных")
                                print("Размер выходного изображения: \(processedImage.size)")
                                
                                DispatchQueue.main.async {
                                    self.outputImage = processedImage
                                    print("Изображение установлено в UI напрямую из данных")
                                }
                            } else {
                                throw NSError(domain: "ImageProcessing", code: 3, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать изображение из данных"])
                            }
                        }
                    } else {
                        print("Не удалось создать CGImageSource")
                        
                        // Последняя попытка - создать изображение напрямую из файла
                        if let finalImage = NSImage(contentsOf: tempOutputURL) {
                            print("Успешно создан NSImage из файла")
                            print("Размер изображения: \(finalImage.size)")
                            
                            DispatchQueue.main.async {
                                self.outputImage = finalImage
                                print("Изображение установлено в UI из файла")
                            }
                        } else {
                            throw NSError(domain: "ImageProcessing", code: 3, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать изображение из файла"])
                        }
                    }
                } else {
                    print("Не удалось прочитать выходной файл")
                    throw NSError(domain: "ImageProcessing", code: 3, userInfo: [NSLocalizedDescriptionKey: "Не удалось прочитать выходной файл"])
                }
            } else {
                print("Выходной файл пустой или недоступен")
                throw NSError(domain: "ImageProcessing", code: 2, userInfo: [NSLocalizedDescriptionKey: "Выходной файл недоступен"])
            }
            
            // Удаляем временные файлы только после успешной загрузки изображения
            try? FileManager.default.removeItem(at: tempInputURL)
            try? FileManager.default.removeItem(at: tempOutputURL)
            
        } catch {
            print("Ошибка при обработке: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "\(error.localizedDescription)"
                self.showError = true
            }
        }
    }
}

#Preview {
    ContentView()
}
