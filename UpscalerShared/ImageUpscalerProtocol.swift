import Foundation

/// Protocol defining the interface for the image upscaling service.
/// This protocol is used for XPC communication between the main app and the service.
@objc public protocol ImageUpscalerServiceProtocol: NSObjectProtocol {
    /// Upscales an image at the given input path and saves the result to the output path.
    /// - Parameters:
    ///   - inputPath: Path to the input image file
    ///   - outputPath: Path where the upscaled image should be saved
    ///   - scale: The scale factor for upscaling (2x, 3x, or 4x)
    ///   - reply: Completion handler called with an optional error
    func upscaleImage(inputPath: String, outputPath: String, scale: Int, withReply reply: @escaping (Error?) -> Void)
    
    /// Adds an observer for progress updates during image processing.
    /// - Parameters:
    ///   - observer: The object to be registered as an observer
    ///   - callback: Closure called with progress messages
    func addProgressObserver(_ observer: NSObject, callback: @escaping (String) -> Void)
    
    /// Removes a previously registered progress observer.
    /// - Parameter observer: The observer to be removed
    func removeProgressObserver(_ observer: NSObject)
} 