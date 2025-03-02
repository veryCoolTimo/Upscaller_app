import Foundation

/// Protocol defining the interface for the image upscaling service.
/// This protocol is used for XPC communication between the main app and the service.
@objc public protocol ImageUpscalerProtocol: NSObjectProtocol {
    /// Upscales an image at the given input path and saves the result to the output path.
    /// - Parameters:
    ///   - inputPath: Path to the input image file
    ///   - outputPath: Path where the upscaled image should be saved
    ///   - scale: The scale factor for upscaling (2x, 3x, or 4x)
    ///   - reply: Completion handler called with an optional error
    func upscaleImage(inputPath: String, outputPath: String, scale: Int, withReply reply: @escaping (Error?) -> Void)
    
    /// Adds an observer for progress updates during image processing.
    /// - Parameters:
    ///   - observerId: Unique string identifier for the observer
    ///   - callback: Closure called with progress messages
    func addProgressObserver(_ observerId: String, callback: @escaping (String) -> Void)
    
    /// Removes a previously registered progress observer.
    /// - Parameter observerId: The identifier of the observer to be removed
    func removeProgressObserver(_ observerId: String)
    
    /// This implements the example protocol. Replace the body of this class with the implementation of this service's protocol.
    func performCalculation(firstNumber: Int, secondNumber: Int, with reply: @escaping (Int) -> Void)
} 