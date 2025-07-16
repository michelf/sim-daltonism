import CoreGraphics
import CoreImage
import AVFoundation
#if os(macOS)
import AppKit
#endif

@MainActor
public class AVCaptureStream: NSObject, CaptureStream, CapturePipelineDelegate {
	private struct WeakDelegate {
		weak var object: CaptureStreamDelegate?
	}
	private let _delegate = Mutex(WeakDelegate())
	nonisolated public weak var delegate: CaptureStreamDelegate? {
		get { _delegate.withLock { $0.object } }
		set { _delegate.withLock { $0.object = newValue } }
	}

	nonisolated let capturePipeline = CapturePipeline()

	/// - Note: `frame` is ignored in `AVCaptureStream`.
	public func startSession(in frame: CGRect, delegate: CaptureStreamDelegate) {
		self.delegate = delegate
		setupPipeline()
	}

	public func stopSession() {
		teardownPipeline()
	}

	deinit {
		teardownPipeline()
	}

	public func checkCapturePermission() -> Bool {
return true
	}

	public enum DeviceType: UnicodeScalar, CaseIterable {
		case frontCamera = "F"
		case backCamera = "B"
		case external = "X"
	}
	public struct Params: Equatable {
		var deviceType: DeviceType?
		var	deviceID: String?
	}
	public var params: Params = AVCaptureStream.initialDeviceParams() {
		didSet {
			changeDeviceIfNeeded()
		}
	}

	public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		#if !os(tvOS)
		if #available(macOS 10.15, *),
		   object as AnyObject === Self.captureDeviceDiscoverySession
		{
			changeDeviceIfNeeded()
		}
		#endif
	}

	private func setupPipeline() {
		if capturePipeline.isRunning {
			teardownPipeline()
		}
		if #available(macOS 10.15, *) {
			Self.captureDeviceDiscoverySession.addObserver(self, forKeyPath: #keyPath(AVCaptureDevice.DiscoverySession.devices), context: nil)
		} else {
			NotificationCenter.default.addObserver(self, selector: #selector(changeDeviceIfNeeded), name: .AVCaptureDeviceWasConnected, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(changeDeviceIfNeeded), name: .AVCaptureDeviceWasDisconnected, object: nil)
		}

		capturePipeline.setDelegate(self, callbackQueue: .main)
		changeDeviceIfNeeded()
		capturePipeline.renderingEnabled = true
		capturePipeline.startRunning()
	}
	nonisolated private func teardownPipeline() {
		guard capturePipeline.isRunning else {
			return
		}
		if #available(macOS 10.15, *) {
			Self.captureDeviceDiscoverySession.removeObserver(self, forKeyPath: #keyPath(AVCaptureDevice.DiscoverySession.devices), context: nil)
		} else {
			NotificationCenter.default.removeObserver(self, name: .AVCaptureDeviceWasConnected, object: nil)
			NotificationCenter.default.removeObserver(self, name: .AVCaptureDeviceWasDisconnected, object: nil)
		}
		capturePipeline.stopRunning()
	}

	@objc func changeDeviceIfNeeded() {
		let device = Self.bestDevice(for: params)
		capturePipeline.select(device)
	}

	static func initialDeviceParams() -> Params {
		var params = Params()
		#if os(macOS)
		params.deviceType = .frontCamera
		#else
		params.deviceType = .backCamera
		#endif
		return bestDevice(for: params)?.captureStreamParams ?? params
	}

	static func bestDevice(for params: Params) -> AVCaptureDevice? {
		let devices = Self.currentDevices
		var typeMatch: AVCaptureDevice?
		for device in devices {
			if let id = params.deviceID, device.uniqueID == id  {
				return device // exact match!
			}
			if device.captureStreamDeviceType == params.deviceType {
				typeMatch = device
			}
		}
		return typeMatch ?? devices.first
	}

	func toggleInputDevice() -> Bool {
		let devices = Self.currentDevices
		let currentIndex = devices.firstIndex {
			params == $0.captureStreamParams
		} ?? devices.firstIndex {
			params.deviceType == $0.captureStreamDeviceType
		}
		let nextDevice = if let currentIndex {
			devices[(currentIndex + 1) % devices.count]
		} else {
			devices.first
		}
		if let nextDevice {
			params = nextDevice.captureStreamParams
			return true
		} else {
			return false
		}
	}

#if os(macOS)
	public func handleMouseEvent(_ event: NSEvent) {}
#endif

	nonisolated public func capturePipeline(_ capturePipeline: CapturePipeline!, didStartRunningWithVideoDevice videoDevice: AVCaptureDevice!) {
	}
	
	nonisolated public func capturePipeline(_ capturePipeline: CapturePipeline!, didStopRunningWithError error: (any Error)!) {
		self.delegate?.didCaptureFrame(image: CIImage(color: .gray))
	}

	nonisolated private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
	nonisolated private let colorSpace = AVCaptureStream.colorSpace
	nonisolated private let ciImageOptions: [CIImageOption: Any] = [
		.colorSpace: AVCaptureStream.colorSpace
	]

	nonisolated public func capturePipeline(_ capturePipeline: CapturePipeline!, previewPixelBufferReadyForDisplay pixelBuffer: CVPixelBuffer!) {
		guard let delegate = self.delegate else { return }
		var ciImage = CIImage(cvPixelBuffer: pixelBuffer, options: ciImageOptions)
		if capturePipeline.videoDevice.captureStreamDeviceType == .frontCamera {
			ciImage = ciImage.oriented(.upMirrored)
		}
		delegate.didCaptureFrame(image: ciImage)
	}
	
	nonisolated public func capturePipelineDidRunOutOfPreviewBuffers(_ capturePipeline: CapturePipeline!) {

	}
	

}

extension AVCaptureStream {

	@available(macOS 10.15, *)
	nonisolated static var deviceTypes: [AVCaptureDevice.DeviceType] {
		var types: [AVCaptureDevice.DeviceType] = [
			.builtInWideAngleCamera
		]
		#if os(macOS)
		types.append(.externalUnknown)
		#endif
		return types
	}
	@available(macOS 10.15, *)
	nonisolated static let captureDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .unspecified)

	static var currentDevices: [AVCaptureDevice] {
		if #available(macOS 10.15, *) {
			return Self.captureDeviceDiscoverySession.devices
		} else {
			return AVCaptureDevice.devices(for: .video)
		}
	}

}

extension AVCaptureDevice {

#if os(macOS)
	static let defaultFrontCamera: AVCaptureDevice? = {
		if #available(macOS 10.15, *) {
			return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
		} else {
			return nil
		}
	}()
#endif

	var captureStreamDeviceType: AVCaptureStream.DeviceType {
		switch position {
		case .front: return .frontCamera
		case .back: return .backCamera
		case .unspecified:
			fallthrough
		@unknown default:
#if os(macOS)
			if self === AVCaptureDevice.defaultFrontCamera {
				return .frontCamera
			}
#endif
			return .external
		}
	}

	var captureStreamParams: AVCaptureStream.Params {
		var params = AVCaptureStream.Params()
		params.deviceType = captureStreamDeviceType
		switch params.deviceType {
		case .frontCamera, .backCamera:
			break
		case .external, nil:
			params.deviceID = uniqueID
		}
		return params
	}

}
