import SwiftUI
import Cocoa
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var originalImage: NSImage?
    @State private var processedImage: NSImage?
    @State private var selectedScale: Int = 2
    @State private var isProcessing: Bool = false
    @State private var processingProgress: Double = 0.0
    @State private var errorMessage: String?
    @State private var showError: Bool = false
 
    private func processImage() async throws {
        guard let inputImage = originalImage else {
            throw NSError(domain: "AppError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Нет входного изображения"])
        }
        
        isProcessing = true
        processingProgress = 0.0
        processedImage = nil
        errorMessage = nil
        showError = false
        
        defer {
            isProcessing = false
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let inputPath = tempDir.appendingPathComponent("input.png")
        let outputPath = tempDir.appendingPathComponent("output.png")
        
        print("Временная директория: \(tempDir.path)")
        print("Путь входного файла: \(inputPath.path)")
        print("Путь выходного файла: \(outputPath.path)")
        
        // Удаляем существующие файлы, если они есть
        if FileManager.default.fileExists(atPath: inputPath.path) {
            try? FileManager.default.removeItem(at: inputPath)
            print("Удален существующий входной файл")
        }
        
        if FileManager.default.fileExists(atPath: outputPath.path) {
            try? FileManager.default.removeItem(at: outputPath)
            print("Удален существующий выходной файл")
        }
        
        // Сохраняем входное изображение как PNG
        if let imageData = inputImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: imageData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            
            try pngData.write(to: inputPath)
            print("Исходное изображение сохранено: \(inputPath.path)")
            print("Размер: \(pngData.count) байт")
            
            // Выводим первые байты PNG для диагностики
            if pngData.count > 20 {
                let header = pngData.prefix(20)
                print("Начало PNG файла: \(header.map { String(format: "%02X", $0) }.joined(separator: " "))")
            }
        } else {
            throw NSError(domain: "AppError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Не удалось сохранить входное изображение"])
        }
        
        // Проверяем, что входной файл существует и не пустой
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: inputPath.path, isDirectory: &isDir) || isDir.boolValue {
            throw NSError(domain: "AppError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Входной файл не существует"])
        }
        
        let attrs = try FileManager.default.attributesOfItem(atPath: inputPath.path)
        let fileSize = attrs[.size] as? UInt64 ?? 0
        if fileSize == 0 {
            throw NSError(domain: "AppError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Входной файл пуст"])
        }
        
        print("Начинаем апскейлинг изображения с масштабом \(selectedScale)x")
        
        // Создаем обработчик прогресса
        ImageUpscaler.shared.setProgressCallback { message in
            print("Прогресс: \(message)")
            if let percentStr = message.split(separator: " ").first,
               let percentValue = percentStr.replacingOccurrences(of: "%", with: ""),
               let percent = Double(percentValue) {
                DispatchQueue.main.async {
                    self.processingProgress = percent / 100.0
                }
            }
        }
        
        // Обрабатываем изображение через upscaler
        do {
            try await ImageUpscaler.shared.upscaleImage(
                at: inputPath.path,
                outputPath: outputPath.path,
                scale: selectedScale
            )
            
            print("Обработка изображения завершена успешно")
        } catch {
            print("Ошибка при обработке изображения: \(error.localizedDescription)")
            throw error
        }
        
        // Проверяем, что выходной файл существует и не пустой
        if !FileManager.default.fileExists(atPath: outputPath.path, isDirectory: &isDir) || isDir.boolValue {
            throw NSError(domain: "AppError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Выходной файл не существует"])
        }
        
        let outputAttrs = try FileManager.default.attributesOfItem(atPath: outputPath.path)
        let outputFileSize = outputAttrs[.size] as? UInt64 ?? 0
        if outputFileSize == 0 {
            throw NSError(domain: "AppError", code: 6, userInfo: [NSLocalizedDescriptionKey: "Выходной файл пуст"])
        }
        
        print("Выходной файл создан: \(outputPath.path)")
        print("Размер выходного файла: \(outputFileSize) байт")
        
        // Сохраняем копию в Documents для отладки
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let debugOutputPath = documentsURL.appendingPathComponent("output_debug.png")
        try? FileManager.default.copyItem(at: outputPath, to: debugOutputPath)
        print("Копия выходного файла сохранена для отладки: \(debugOutputPath.path)")
        
        // Используем наш специальный метод для создания изображения
        if let newImage = createImageFromFile(at: outputPath) {
            DispatchQueue.main.async {
                self.processedImage = newImage
                print("Изображение успешно создано и отображено: \(newImage.size.width) x \(newImage.size.height)")
            }
            
            // Очищаем временные файлы, но сохраняем копию для отладки
            try? FileManager.default.removeItem(at: inputPath)
            // Не удаляем outputPath, сохраняем для возможной отладки
            
            return
        }
        
        // Если метод не сработал, пробуем альтернативные подходы
        do {
            let outputData = try Data(contentsOf: outputPath)
            print("Данные загружены напрямую, размер: \(outputData.count) байт")
            
            // Выводим первые байты для диагностики
            if outputData.count > 20 {
                let header = outputData.prefix(20)
                print("Начало файла: \(header.map { String(format: "%02X", $0) }.joined(separator: " "))")
            }
            
            if let newImage = NSImage(data: outputData) {
                DispatchQueue.main.async {
                    self.processedImage = newImage
                    print("Изображение создано напрямую из данных: \(newImage.size.width) x \(newImage.size.height)")
                }
                return
            }
        } catch {
            print("Ошибка при чтении данных: \(error.localizedDescription)")
        }
        
        throw NSError(domain: "AppError", code: 7, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать изображение из выходного файла"])
    }
    
    // Открытие диалога выбора файла
    private func openFileDialog() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image]
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            loadImageFromURL(url)
        }
    }
    
    // Загрузка изображения из указанного URL
    private func loadImageFromURL(_ url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        originalImage = image
        processedImage = nil
        errorMessage = nil
        showError = false
    }
    
    // Обработка перетаскиваемого изображения
    private func loadDroppedImage(providers: [NSItemProvider]) -> Bool {
        if let item = providers.first {
            item.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                if let urlData = urlData as? Data,
                   let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                    DispatchQueue.main.async {
                        self.loadImageFromURL(url)
                    }
                }
            }
            return true
        }
        return false
    }
    
    // Сохранение обработанного изображения
    private func saveProcessedImage() {
        guard let image = processedImage else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.nameFieldStringValue = "upscaled_image.png"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
            }
        }
    }
    
    // Метод для создания NSImage напрямую из файла с принудительной обработкой цветов
    func createImageFromFile(at url: URL) -> NSImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            print("Не удалось создать источник изображения")
            return nil
        }
        
        let options: [String: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways as String: true,
            kCGImageSourceCreateThumbnailWithTransform as String: true,
            kCGImageSourceShouldCacheImmediately as String: true,
            kCGImageSourceShouldAllowFloat as String: true
        ]
        
        // Пытаемся получить свойства изображения для диагностики
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            print("Свойства изображения: \(properties)")
        }
        
        // Попытка 1: Создание превью из источника
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
            print("Создан thumbnail с размерами: \(cgImage.width) x \(cgImage.height)")
            
            // Получаем информацию о цветовом пространстве
            if let colorSpace = cgImage.colorSpace {
                print("Цветовое пространство превью: \(colorSpace.name ?? "неизвестно")")
                print("Модель цветового пространства: \(colorSpace.model.rawValue)")
            }
            
            // Создаем новое изображение с явным указанием цветового пространства sRGB
            if let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) {
                let context = CGContext(
                    data: nil,
                    width: cgImage.width,
                    height: cgImage.height,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
                
                if let context = context {
                    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
                    if let newCGImage = context.makeImage() {
                        let nsImage = NSImage(size: NSSize(width: newCGImage.width, height: newCGImage.height))
                        nsImage.addRepresentation(NSBitmapImageRep(cgImage: newCGImage))
                        print("Создан NSImage через sRGB контекст: \(nsImage.size.width) x \(nsImage.size.height)")
                        return nsImage
                    }
                }
            }
            
            // Запасной вариант: создание NSImage напрямую из CGImage
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            print("Создан NSImage напрямую: \(nsImage.size.width) x \(nsImage.size.height)")
            return nsImage
        }
        
        // Попытка 2: Чтение данных и создание CIImage
        do {
            let data = try Data(contentsOf: url)
            if let ciImage = CIImage(data: data), let cgImage = convertCIImageToCGImage(ciImage) {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                print("Создан NSImage через CIImage: \(nsImage.size.width) x \(nsImage.size.height)")
                return nsImage
            }
        } catch {
            print("Ошибка при чтении данных: \(error.localizedDescription)")
        }
        
        // Попытка 3: Стандартное создание NSImage из URL
        if let nsImage = NSImage(contentsOf: url) {
            print("Создан NSImage напрямую из URL: \(nsImage.size.width) x \(nsImage.size.height)")
            return nsImage
        }
        
        print("Все методы создания изображения не удались")
        return nil
    }
    
    // Вспомогательный метод для конвертации CIImage в CGImage
    func convertCIImageToCGImage(_ ciImage: CIImage) -> CGImage? {
        if let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) {
            let context = CIContext(options: [.workingColorSpace: colorSpace])
            return context.createCGImage(ciImage, from: ciImage.extent)
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                // Блок для оригинального изображения
                VStack {
                    Text("Оригинальное изображение")
                        .font(.headline)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary, style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .frame(width: 300, height: 300)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        if let image = originalImage {
                            ImageView(image: image)
                                .frame(width: 300, height: 300)
                                .background(Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    Text("Размер: \(Int(image.size.width)) x \(Int(image.size.height))")
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.black.opacity(0.6))
                                        .foregroundColor(.white)
                                        .cornerRadius(4),
                                    alignment: .bottom
                                )
                        } else {
                            Text("Перетащите изображение сюда\nили нажмите для выбора")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onTapGesture {
                        openFileDialog()
                    }
                    .onDrop(of: ["public.file-url"], isTargeted: nil) { providers -> Bool
                        return loadDroppedImage(providers: providers)
                    }
                }
                
                Divider()
                    .frame(height: 300)
                
                // Блок для обработанного изображения
                VStack {
                    Text("Обработанное изображение")
                        .font(.headline)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary, style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .frame(width: 300, height: 300)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        if isProcessing {
                            VStack {
                                ProgressView(value: processingProgress, total: 1.0)
                                    .frame(width: 200)
                                Text("\(Int(processingProgress * 100))%")
                                    .font(.caption)
                                    .padding(.top, 5)
                            }
                        } else if let image = processedImage {
                            ImageView(image: image)
                                .frame(width: 300, height: 300)
                                .background(Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    Text("Размер: \(Int(image.size.width)) x \(Int(image.size.height))")
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.black.opacity(0.6))
                                        .foregroundColor(.white)
                                        .cornerRadius(4),
                                    alignment: .bottom
                                )
                        } else {
                            Text("Обработанное изображение\nпоявится здесь")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            
            // Элементы управления
            HStack(spacing: 20) {
                Text("Масштаб:")
                Picker("", selection: $selectedScale) {
                    Text("2x").tag(2)
                    Text("3x").tag(3)
                    Text("4x").tag(4)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
                
                Button(action: {
                    Task {
                        do {
                            try await processImage()
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }) {
                    Text("Обработать")
                        .frame(width: 100)
                }
                .disabled(originalImage == nil || isProcessing)
                
                if processedImage != nil && !isProcessing {
                    Button(action: saveProcessedImage) {
                        Text("Сохранить")
                            .frame(width: 100)
                    }
                }
            }
            .padding()
            
            if let errorMessage = errorMessage, showError {
                Text("Ошибка: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

struct ImageView: NSViewRepresentable {
    var image: NSImage
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.contentTintColor = nil  // Гарантирует, что цвета не изменяются
        return imageView
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = image
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
 