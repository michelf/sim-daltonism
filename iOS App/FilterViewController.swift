
import UIKit
import Foundation
import QuartzCore

class FilterViewController: UIViewController, CapturePipelineDelegate, UIAlertViewDelegate {
	
	var _addedObservers = false
	var _allowedToUseGPU = false
	var _mainCameraUIAdapted = false
	var _presentingShareView = false
#if targetEnvironment(simulator)
	var _slideshowURLs: [URL] = []
	var slideshowIndex: Int = 0
#endif

	@IBOutlet var photoButton:  UIBarButtonItem!
	@IBOutlet var flashButton:  UIBarButtonItem!
	@IBOutlet var shareButton:  UIBarButtonItem!
	@IBOutlet var toolbar:  UIToolbar!
	@IBOutlet var framerateLabel:  UILabel!
	@IBOutlet var dimensionsLabel:  UILabel!
	@IBOutlet var contentView:  UIView!
	@IBOutlet var noCameraPermissionOverlayView:  UIView!
	var labelTimer: Timer?
	var previewView: OpenGLPixelBufferView?
	var capturePipeline: CapturePipeline?

	var _videoDevice: AVCaptureDevice?

	deinit {
		if ( _addedObservers ) {
			NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: UIApplication.shared)
			NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: UIApplication.shared)
			NotificationCenter.default.removeObserver(self, name: UIApplication.didChangeStatusBarOrientationNotification, object: UIApplication.shared)
			UIDevice.current.endGeneratingDeviceOrientationNotifications()
		}
	}

	// MARK: - View lifecycle

	@objc func applicationDidEnterBackground() {
		// Avoid using the GPU in the background
		_allowedToUseGPU = false
		self.capturePipeline?.renderingEnabled = false

		// We reset the OpenGLPixelBufferView to ensure all resources have been clear when going to the background.
		self.previewView?.reset()
	}

	override func didReceiveMemoryWarning() {
		self.previewView?.reset()
		super.didReceiveMemoryWarning()
	}

	@objc func applicationWillEnterForeground() {
		_allowedToUseGPU = true
		self.capturePipeline?.renderingEnabled = !_presentingShareView
	}

	override func viewDidLoad() {
		self.capturePipeline = CapturePipeline()
		self.capturePipeline?.setDelegate(self, callbackQueue: .main)

		NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: UIApplication.shared)
		NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: UIApplication.shared)
		NotificationCenter.default.addObserver(self, selector: #selector(adjustOrientation), name: UIApplication.didChangeStatusBarOrientationNotification, object: UIApplication.shared)

		// Keep track of changes to the device orientation so we can update the capture pipeline
		UIDevice.current.beginGeneratingDeviceOrientationNotifications()

		_addedObservers = true

		// the willEnterForeground and didEnterBackground notifications are subsequently used to update _allowedToUseGPU
		_allowedToUseGPU = UIApplication.shared.applicationState != .background
		self.capturePipeline?.renderingEnabled = _allowedToUseGPU && !_presentingShareView

		super.viewDidLoad()

		self.checkCameraPrivacySettings()

		// Adapt UI for default device (will be called again when capture session starts)
		self.setVideoDevice(videoDevice: .default(for: .video))
	}

	func setVideoDevice(videoDevice: AVCaptureDevice?) {
		_videoDevice = videoDevice;

#if targetEnvironment(simulator)
		let hasTorch = UIDevice.current.userInterfaceIdiom == .phone
#else
		let hasTorch = videoDevice?.hasTorch ?? false
#endif
		if _mainCameraUIAdapted == false {
			if (!hasTorch) {
				// remove torch button and spacer if main camera does not have a torch
				var items = self.toolbar.items ?? []
				items.removeFirst(min(items.count, 2))
				self.toolbar.items = items
			}
			_mainCameraUIAdapted = true
		}

		self.flashButton.isEnabled = videoDevice?.isTorchAvailable == true
#if targetEnvironment(simulator)
		self.flashButton.isEnabled = true
#endif
		self.reflectTorchActiveState(videoDevice?.isTorchActive == true)
	}

	func reflectTorchActiveState(_ torchActive: Bool) {
		let torchImageName = torchActive ? "FlashLight" : "FlashDark";
		let torchImage = UIImage(named: torchImageName)
		self.flashButton.image = torchImage
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		self.capturePipeline?.startRunning()

		self.labelTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(updateLabels), userInfo: nil, repeats: true)

#if targetEnvironment(simulator)
		// wait after autolayout did its work
		self.setupPreviewView()
		// display some test image
		self.prepareSlideshow()
#endif
	}

#if targetEnvironment(simulator)
	func prepareSlideshow() {
		if _slideshowURLs == nil {
			_slideshowIndex = -1
			let slideshowDir = URL(fileURLWithPath: "Pictures", isDirectory: true)
			_slideshowURLs = FileManager.default.contentsOfDirectoryAt(slideshowDir, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationSkipsPackageDescendants|NSDirectoryEnumerationSkipsHiddenFiles)
			self.goNextSlide()

			NotificationCenter.default.addObserver(self, selector: #selector(refreshCurrentSlide), name: NSUserDefaultsDidChangeNotification, object: nil)
		}
	}

	func goNextSlide() {
		_slideshowIndex += 1
		if _slideshowIndex >= _slideshowURLs.count {
			_slideshowIndex = 0
		}
		while _slideshowIndex >= 0 && _slideshowIndex < _slideshowURLs.count {
			if self.refreshCurrentSlide() {
				return
			}
			_slideshowIndex += 1
		}
	}

	func goPreviousSlide() {
		_slideshowIndex -= 1
		if _slideshowIndex < 0 {
			_slideshowIndex = _slideshowURLs.count-1
		}
		while _slideshowIndex >= 0 && _slideshowIndex < _slideshowURLs.count {
			if self.refreshCurrentSlide() {
				return
			}
			_slideshowIndex -= 1
		}
	}

	func refreshCurrentSlide() {
		if let image = UIImage(contentsOfFile: _slideshowURLs[_slideshowIndex].path) {
			self.previewView.displayImage(image)
		}
		return image != nil
	}
#endif

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		self.labelTimer?.invalidate()
		self.labelTimer = nil

		self.capturePipeline?.stopRunning()
		UIApplication.shared.isIdleTimerDisabled = false
	}

	override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		return .all
	}

	override var prefersStatusBarHidden: Bool {
		return true
	}

	// MARK: - UI

	@IBAction func toggleShowFramerate(_ gestureRecognizer: UIGestureRecognizer) {
		switch gestureRecognizer.state {
		case .began:
			self.framerateLabel.isHidden = !self.framerateLabel.isHidden
			self.dimensionsLabel.isHidden = !self.dimensionsLabel.isHidden
		default:
			break
		}
	}

	@IBAction func zoom(_ gestureRecognizer: UIPinchGestureRecognizer) {
		guard let _videoDevice else { return }
		switch gestureRecognizer.state {
		case .began:
			_ = try? _videoDevice.lockForConfiguration()
			gestureRecognizer.scale = _videoDevice.videoZoomFactor
		case .ended, .cancelled, .failed:
			_videoDevice.unlockForConfiguration()
		case .changed:
			let factor = gestureRecognizer.scale
			let minFactor = 1.0
			let maxFactor = min(_videoDevice.activeFormat.videoZoomFactorUpscaleThreshold*2, _videoDevice.activeFormat.videoMaxZoomFactor)
			_videoDevice.videoZoomFactor = min(maxFactor, max(minFactor, factor))
		case .possible:
			break
		@unknown default:
			break
		}
	}

	@IBAction func toggleInputDevice(_ sender: Any) {
		if _presentingShareView {
			return
		}
#if targetEnvironment(simulator)
		self.goNextSlide()
#else
		let changed = self.capturePipeline?.toggleInputDevice() ?? false
		if changed {
			self.previewView?.reset()
			self.previewView?.alpha = 0
			self.flashButton?.isEnabled = false
			self.reflectTorchActiveState(false)
			UIView.transition(from: self.contentView, to: self.contentView, duration:0.5, options: [.transitionFlipFromRight, .allowAnimatedContent, .showHideTransitionViews]) { success in
				UIView.animate(withDuration: 0.2) {
					self.previewView?.alpha = 1
				}
			}
		}
#endif
	}

	@IBAction func toggleTorch(_ sender: Any) {
#if targetEnvironment(simulator)
		self.goPreviousSlide()
#else
		guard let _videoDevice else { return }
		do {
			try _videoDevice.lockForConfiguration()
			let torchActive = !_videoDevice.isTorchActive
			_videoDevice.torchMode = torchActive ? .on : .off
			_videoDevice.unlockForConfiguration()
			self.reflectTorchActiveState(torchActive)
		} catch {
			print("videoDevice lockForConfiguration returned error", error)
		}
#endif
	}

	@IBAction func showSettings(_ sender: Any) {
		if let vc = UIStoryboard(name: "Options", bundle: nil).instantiateInitialViewController() {
			vc.view.tintColor = self.view.tintColor
			self.present(vc, animated: true)
		}
	}

	func setupPreviewView() {
		if (self.previewView != nil) {
			return;
		}

		// Set up GL view
		self.previewView = OpenGLPixelBufferView()
		self.previewView?.autoresizingMask = [.flexibleHeight, .flexibleWidth]

		self.adjustOrientation()

		self.contentView.insertSubview(self.previewView!, at: 0)
		var bounds = CGRect.zero
		bounds.size = self.contentView.convert(self.contentView.bounds, to: self.previewView).size
		self.previewView?.bounds = bounds
		self.previewView?.center = CGPoint(x: self.contentView.bounds.size.width/2.0, y: self.contentView.bounds.size.height/2.0);
	}

	func checkCameraPrivacySettings() {
		AVCaptureDevice.requestAccess(for: .video) { granted in
			DispatchQueue.main.async {
				self.noCameraPermissionOverlayView.isHidden = granted
			}
		}
	}

	@objc func updateLabels() {
		let fps = Int(roundf(self.capturePipeline?.videoFrameRate ?? -1))
		self.framerateLabel.text = "\(fps) FPS"
		let width = self.capturePipeline?.videoDimensions.width ?? 0
		let height = self.capturePipeline?.videoDimensions.height ?? 0
		self.dimensionsLabel.text = "\(width) × \(height)"
	}

	func showError(_ error: Error) {
		let alert = UIAlertController(title: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription,
									  message: (error as? LocalizedError)?.failureReason,
									  preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
		self.present(alert, animated: true)
	}

	@IBAction func showCameraPrivacySettings(_ sender: Any) {
		UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
	}

	// MARK: - RosyWriterCapturePipelineDelegate

	func capturePipeline(_ capturePipeline: CapturePipeline, didStartRunningWithVideoDevice videoDevice: AVCaptureDevice) {
		self._videoDevice = videoDevice
		self.adjustOrientation()
	}

	@objc func adjustOrientation() {
		guard let capturePipeline, let previewView else { return }
		let currentInterfaceOrientation: AVCaptureVideoOrientation = switch UIApplication.shared.statusBarOrientation {
		case .unknown:            .portrait
		case .portrait:           .portrait
		case .portraitUpsideDown: .portraitUpsideDown
		case .landscapeLeft:      .landscapeLeft
		case .landscapeRight:     .landscapeRight
		@unknown default:         .portrait
		}
		previewView.transform = capturePipeline.transformFromVideoBufferOrientation(to: currentInterfaceOrientation, withAutoMirroring: false) // Front camera preview should be mirrored
		let mirrored = self._videoDevice?.position == .front
		previewView.mirrorTransform = mirrored;
		previewView.frame = previewView.superview?.bounds ?? previewView.frame

		// capture orientation must compensate for the transform that was applied
		switch currentInterfaceOrientation {
		case .portrait:
			previewView.captureOrientation = !mirrored ? .leftMirrored : .rightMirrored
		case .portraitUpsideDown:
			previewView.captureOrientation = !mirrored ? .rightMirrored : .leftMirrored
		case .landscapeLeft:
			previewView.captureOrientation = !mirrored ? .upMirrored : .downMirrored
		case .landscapeRight:
			previewView.captureOrientation = !mirrored ? .downMirrored : .upMirrored
		@unknown default:
			fatalError()
		}
	}

	func capturePipeline(_ capturePipeline: CapturePipeline, didStopRunningWithError error: Error) {
		self._videoDevice = nil

		self.showError(error)

		self.photoButton.isEnabled = false
	}

	// Preview
	func capturePipeline(_ capturePipeline: CapturePipeline, previewPixelBufferReadyForDisplay previewPixelBuffer: CVPixelBuffer) {
		if !_allowedToUseGPU {
			return
		}

		if self.previewView == nil {
			self.setupPreviewView()
		}

		self.noCameraPermissionOverlayView.isHidden = true

		self.previewView?.display(previewPixelBuffer)

		let app = UIApplication.shared
		let shouldDisableIdleTimer = self.presentedViewController == nil
		if app.isIdleTimerDisabled != shouldDisableIdleTimer {
			app.isIdleTimerDisabled = shouldDisableIdleTimer
		}
	}

	func capturePipelineDidRunOutOfPreviewBuffers(_ capturePipeline: CapturePipeline) {
		if _allowedToUseGPU {
			self.previewView?.flushPixelBufferCache()
		}
	}

	func sharePicture(_ item: UIBarButtonItem) {
		let image = self.previewView?.captureCurrentImage()
		guard let image else { return }
		var torchActive = false
		if let _videoDevice, _videoDevice.hasTorch {
			do {
				try _videoDevice.lockForConfiguration()
				torchActive = _videoDevice.isTorchActive
				_videoDevice.torchMode = .off
				_videoDevice.unlockForConfiguration()
				self.reflectTorchActiveState(torchActive)
			} catch {
				print("videoDevice lockForConfiguration returned error", error)
			}
		}
		_presentingShareView = true
		self.capturePipeline?.renderingEnabled = !_presentingShareView // freeze image
		let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
		if UIDevice.current.userInterfaceIdiom == .pad {
			activityViewController.modalPresentationStyle = .popover
			activityViewController.popoverPresentationController?.barButtonItem = item
		}
		self.present(activityViewController, animated: true)
		activityViewController.completionWithItemsHandler = { (activityType, completed, returnedItems, activityError) in
			self._presentingShareView = false
			self.capturePipeline?.renderingEnabled = !self._presentingShareView; // unfreeze image
			if torchActive, let videoDevice = self._videoDevice, videoDevice.hasTorch {
				do {
					try videoDevice.lockForConfiguration()
					videoDevice.torchMode = torchActive ? .on : .off
					videoDevice.unlockForConfiguration()
					self.reflectTorchActiveState(torchActive)
				} catch {
					print("videoDevice lockForConfiguration returned error", error)
				}
			}
		};
	}

}
