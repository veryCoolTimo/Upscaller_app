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
                                Text("Нет изображения")
                                    .foregroundColor(.gray)
                            )
                    }
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
    
    private func processImage() async {
        guard let inputImage = inputImage else { return }
        
        isProcessing = true
        progressMessage = "Подготовка..."
        defer { isProcessing = false }
        
        do {
            let tempInputURL = FileManager.default.temporaryDirectory.appendingPathComponent("input.png")
            let tempOutputURL = FileManager.default.temporaryDirectory.appendingPathComponent("output.png")
            
            if let tiffData = inputImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try pngData.write(to: tempInputURL)
            }
            
            try await ImageUpscaler.shared.upscaleImage(
                at: tempInputURL.path,
                outputPath: tempOutputURL.path,
                scale: scale
            )
            
            if let processedImage = NSImage(contentsOf: tempOutputURL) {
                DispatchQueue.main.async {
                    self.outputImage = processedImage
                }
            }
            
            try? FileManager.default.removeItem(at: tempInputURL)
            try? FileManager.default.removeItem(at: tempOutputURL)
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
}

#Preview {
    ContentView()
}
