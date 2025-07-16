
import UIKit
import Foundation
import QuartzCore

@MainActor
class FilterViewController: UIViewController, UIAlertViewDelegate {
	var _addedObservers = false
//	var _allowedToUseGPU = false
	var _mainCameraUIAdapted = false
	var _presentingShareView = false
#if targetEnvironment(simulator)
	var _slideshowURLs: [URL]?
	var _slideshowIndex: Int = 0
#endif

	@IBOutlet var photoButton:  UIBarButtonItem!
	@IBOutlet var flashButton:  UIBarButtonItem!
	@IBOutlet var shareButton:  UIBarButtonItem!
	@IBOutlet var visionMenuButton:  UIBarButtonItem!
	@IBOutlet var colorToolsMenuButton:  UIBarButtonItem!
	@IBOutlet var framerateLabel:  UILabel!
	@IBOutlet var dimensionsLabel:  UILabel!
	@IBOutlet var contentView:  UIView!
	@IBOutlet var noCameraPermissionOverlayView:  UIView!
	var labelTimer: Timer?

	@IBOutlet var visionTypeLabel: UILabel?
	@IBOutlet var redStripeIndicator: UIView?
	@IBOutlet var greenStripeIndicator: UIView?
	@IBOutlet var blueStripeIndicator: UIView?
	@IBOutlet var hueShiftIndicator: UIView?
	@IBOutlet var invertLuminanceIndicator: UIView?
	@IBOutlet var colorBoostIndicator: UIView?

	private var renderer: CaptureStreamDelegate? = nil
	private var captureStream: AVCaptureStream?
	private var filterStore: FilterStore!

	var filteredView: FilteredMetalView!

	var videoDevice: AVCaptureDevice? { captureStream?.capturePipeline.videoDevice }

	deinit {
		if ( _addedObservers ) {
			DispatchQueue.main.async {
				UIDevice.current.endGeneratingDeviceOrientationNotifications()
			}
		}
	}

	// MARK: - View lifecycle

	@objc func applicationDidEnterBackground() {
		// Avoid using the GPU in the background
//		_allowedToUseGPU = false
//		self.captureStream?.stopSession()

		// We reset the OpenGLPixelBufferView to ensure all resources have been clear when going to the background.
//		self.previewView?.reset()
	}

	override func didReceiveMemoryWarning() {
//		self.previewView?.reset()
//		super.didReceiveMemoryWarning()
	}

	@objc func applicationWillEnterForeground() {
//		_allowedToUseGPU = true
//		if !_presentingShareView {
//			self.captureStream?.startSession(in: .zero, delegate: renderer!)
//		}
	}

	override func viewDidLoad() {
		self.captureStream = AVCaptureStream()
//		self.capturePipeline?.setDelegate(self, callbackQueue: .main)

		NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: UIApplication.shared)
		NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: UIApplication.shared)
		NotificationCenter.default.addObserver(self, selector: #selector(adjustOrientation), name: UIApplication.didChangeStatusBarOrientationNotification, object: UIApplication.shared)

		// Keep track of changes to the device orientation so we can update the capture pipeline
		UIDevice.current.beginGeneratingDeviceOrientationNotifications()

		_addedObservers = true

		// the willEnterForeground and didEnterBackground notifications are subsequently used to update _allowedToUseGPU
//		_allowedToUseGPU = UIApplication.shared.applicationState != .background

//		setupPreviewView()
//		captureStream?.startSession(in: .zero, delegate: renderer!)
//		self.capturePipeline?.renderingEnabled = _allowedToUseGPU && !_presentingShareView

		super.viewDidLoad()

		self.checkCameraPrivacySettings()

		// Adapt UI for default device (will be called again when capture session starts)
		self.setVideoDevice(videoDevice: .default(for: .video))
	}

	func setupMenus() {
		var keepsPresentedAttribute: UIMenu.Attributes = []
		if #available(iOS 16.0, *) {
			visionMenuButton.preferredMenuElementOrder = .fixed
			colorToolsMenuButton.preferredMenuElementOrder = .fixed
			keepsPresentedAttribute = .keepsMenuPresented
		}

		func action(for vision: VisionType) -> UIAction {
			if false, #available(iOS 17.0, *) {
				UIAction(title: vision.name, subtitle: vision.description, state: filterStore.configuration.vision == vision ? .on : .off) { [weak self] action in
					self?.filterStore.configuration.vision = vision
				}
			} else {
				UIAction(title: vision.name, state: filterStore.configuration.vision == vision ? .on : .off) { [weak self] action in
					self?.filterStore.configuration.vision = vision
				}
			}
		}

		visionMenuButton.menu = UIMenu(children: [
			UIMenu(options: .displayInline, children: [
				action(for: .normal),
			].iOSLessThan16_reversed()),
			UIMenu(title: NSLocalizedString("Red/green color blindness", comment: ""), options: .displayInline, children: [
				action(for: .deutan),
				action(for: .deuteranomaly),
				action(for: .protan),
				action(for: .protanomaly),
			].iOSLessThan16_reversed()),
			UIMenu(title: NSLocalizedString("Blue/yellow color blindness", comment: ""), options: .displayInline, children: [
				action(for: .tritan),
				action(for: .tritanomaly),
			].iOSLessThan16_reversed()),
			UIMenu(title: NSLocalizedString("Monochromacy", comment: ""), options: .displayInline, children: [
				action(for: .achromatopsia),
				action(for: .blueConeMonochromat),
			].iOSLessThan16_reversed()),
			UIMenu(title: NSLocalizedString("Other", comment: ""), options: .displayInline, children: [
				action(for: .monochromeAnalogTV),
			].iOSLessThan16_reversed()),
		].iOSLessThan16_reversed())
		colorToolsMenuButton.menu = UIMenu(children: [
			UIMenu(options: .displayInline, children: [
				UIAction(title: NSLocalizedString("Red Stripes", comment: ""), image: UIImage(named: "StripesLooseTemplate"), attributes: keepsPresentedAttribute, state: filterStore.configuration.stripeConfig.redStripes != 0 ? .on : .off) { [weak self] action in
					self?.filterStore.configuration.stripeConfig.redStripes = action.state == .on ? 0 : 1
				},
				UIAction(title: NSLocalizedString("Green Stripes", comment: ""), image: UIImage(named: "DashesLooseTemplate"), attributes: keepsPresentedAttribute, state: filterStore.configuration.stripeConfig.greenStripes != 0 ? .on : .off) { [weak self] action in
					self?.filterStore.configuration.stripeConfig.greenStripes = action.state == .on ? 0 : 1
				},
				UIAction(title: NSLocalizedString("Blue Stripes", comment: ""), image: UIImage(named: "HorizontalStripesLooseTemplate"), attributes: keepsPresentedAttribute, state: filterStore.configuration.stripeConfig.blueStripes != 0 ? .on : .off) { [weak self] action in
					self?.filterStore.configuration.stripeConfig.blueStripes = action.state == .on ? 0 : 1
				},
			].iOSLessThan16_reversed()),
			UIMenu(options: .displayInline, children: [
				UIAction(title: NSLocalizedString("Hue Shift", comment: ""), attributes: keepsPresentedAttribute, state: filterStore.configuration.hueShift ? .on : .off) { [weak self] action in
					self?.filterStore.configuration.hueShift.toggle()
				},
				UIAction(title: NSLocalizedString("Luminance Flip", comment: ""), attributes: keepsPresentedAttribute, state: filterStore.configuration.invertLuminance ? .on : .off) { [weak self] action in
					self?.filterStore.configuration.invertLuminance.toggle()
				},
				UIAction(title: NSLocalizedString("Vibrancy Boost", comment: ""), attributes: keepsPresentedAttribute, state: filterStore.configuration.colorBoost ? .on : .off) { [weak self] action in
					self?.filterStore.configuration.colorBoost.toggle()
				},
			].iOSLessThan16_reversed()),
		].iOSLessThan16_reversed())
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		self.filterStore = FilterStore.global
		filterStore.configuration.stripeConfig.patternScale = Float(UIScreen.main.scale)

		NotificationCenter.default.addObserver(self, selector: #selector(refreshFilterDescriptionLabels), name: FilterStore.didChangeNotification, object: filterStore)
		refreshFilterDescriptionLabels()

		setupPreviewView()

		do { try self.connectMetalViewAndFilterPipeline() }
		catch let error { presentError(error) }

		captureStream = AVCaptureStream()

		updateCapturePermissionVisibility()

		self.captureStream?.startSession(in: .zero, delegate: renderer!)
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		NotificationCenter.default.removeObserver(self, name: FilterStore.didChangeNotification, object: filterStore)
	}

	/// If supported, connect a renderer to the Metal view. Returns false if failed to setup Metal.
	func connectMetalViewAndFilterPipeline() throws {
		if let initialDevice = MTLCreateSystemDefaultDevice() {
			filteredView.device = initialDevice

			guard let renderer = MetalRenderer(mtkview: filteredView, filter: filterStore)
			else { throw MetalRendererError }

			self.renderer = renderer
			self.filteredView.delegate = renderer
		}
	}

	func setVideoDevice(videoDevice: AVCaptureDevice?) {
#if targetEnvironment(simulator)
		let hasTorch = UIDevice.current.userInterfaceIdiom == .phone
#else
		let hasTorch = videoDevice?.hasTorch ?? false
#endif
		if _mainCameraUIAdapted == false {
			if (!hasTorch) {
				// remove torch button if main camera does not have a torch
				// actually... keep the button there but make it invisible
				// so the other buttons stay centered.
				self.flashButton.isEnabled = false
				self.flashButton.tintColor = .clear
			}
			_mainCameraUIAdapted = true
		}

#if targetEnvironment(simulator)
		self.flashButton.isEnabled = true
#else
		self.flashButton.isEnabled = videoDevice?.isTorchAvailable == true
#endif
		self.reflectTorchActiveState(videoDevice?.isTorchActive == true)
	}

	func reflectTorchActiveState(_ torchActive: Bool) {
		let torchImageName = torchActive ? "flashlight.on.fill" : "flashlight.off.fill";
		let torchImage = if #available(iOS 13.0, *) {
			UIImage(named: torchImageName)
		} else {
			UIImage(named: torchImageName)
		}
		self.flashButton.image = torchImage
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

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
			let slideshowDir = URL(fileURLWithPath: #filePath, isDirectory: false).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("SimPictures", isDirectory: true)
			_slideshowURLs = try? FileManager.default.contentsOfDirectory(at: slideshowDir, includingPropertiesForKeys: nil, options: [.skipsPackageDescendants, .skipsHiddenFiles])
			print("Found \(_slideshowURLs?.count ?? 0) slides in SimPictures.")
			self.goNextSlide()

			NotificationCenter.default.addObserver(self, selector: #selector(refreshCurrentSlide), name: UserDefaults.didChangeNotification, object: nil)
		}
	}

	func goNextSlide() {
		_slideshowIndex += 1
		if _slideshowIndex >= (_slideshowURLs?.count ?? 0) {
			_slideshowIndex = 0
		}
		while _slideshowIndex >= 0 && _slideshowIndex < (_slideshowURLs?.count ?? 0) {
			if refreshCurrentSlide() {
				return
			}
			_slideshowIndex += 1
		}
	}

	func goPreviousSlide() {
		_slideshowIndex -= 1
		if _slideshowIndex < 0 {
			_slideshowIndex = (_slideshowURLs?.count ?? 0)-1
		}
		while _slideshowIndex >= 0 && _slideshowIndex < (_slideshowURLs?.count ?? 0) {
			if refreshCurrentSlide() {
				return
			}
			_slideshowIndex -= 1
		}
	}

	private var slideCache: [Int: CIImage?] = [:]
	func loadSlide(at index: Int) -> CIImage? {
		if let image = slideCache[index] {
			return image
		}
		guard let imageURL = _slideshowURLs?[index],
			  let cgImage = UIImage(contentsOfFile: imageURL.path)?.cgImage
		else {
			slideCache[index] = .some(nil)
			return nil
		}
		let image = CIImage(cgImage: cgImage, options: [.cacheImmediately: true])
		slideCache[index] = image
		return image
	}
	@objc func refreshCurrentSlide() -> Bool {
		if let image = loadSlide(at: _slideshowIndex) {
			self.renderer?.didCaptureFrame(image: image)
			return true
		} else {
			return false
		}
	}
#endif

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		self.labelTimer?.invalidate()
		self.labelTimer = nil

		self.captureStream?.stopSession()
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
		guard let videoDevice else { return }
		switch gestureRecognizer.state {
		case .began:
			_ = try? videoDevice.lockForConfiguration()
			gestureRecognizer.scale = videoDevice.videoZoomFactor
		case .ended, .cancelled, .failed:
			videoDevice.unlockForConfiguration()
		case .changed:
			let factor = gestureRecognizer.scale
			let minFactor = 1.0
			let maxFactor = min(videoDevice.activeFormat.videoZoomFactorUpscaleThreshold*2, videoDevice.activeFormat.videoMaxZoomFactor)
			videoDevice.videoZoomFactor = min(maxFactor, max(minFactor, factor))
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
		let changed = self.captureStream?.toggleInputDevice() ?? false
		if changed {
//			self.previewView?.reset()
			self.filteredView?.alpha = 0
			self.flashButton?.isEnabled = false
			self.reflectTorchActiveState(false)
			UIView.transition(from: self.contentView, to: self.contentView, duration:0.5, options: [.transitionFlipFromRight, .allowAnimatedContent, .showHideTransitionViews]) { success in
				UIView.animate(withDuration: 0.2) {
					self.filteredView?.alpha = 1
				} completion: { success in
					self.setVideoDevice(videoDevice: self.videoDevice)
				}
			}
		}
#endif
	}

	@IBAction func toggleTorch(_ sender: Any) {
#if targetEnvironment(simulator)
		self.goPreviousSlide()
#else
		guard let videoDevice else { return }
		do {
			try videoDevice.lockForConfiguration()
			let torchActive = !videoDevice.isTorchActive
			videoDevice.torchMode = torchActive ? .on : .off
			videoDevice.unlockForConfiguration()
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
		if self.filteredView != nil {
			return
		}

		// Set up GL view
		self.filteredView = FilteredMetalView(frame: .zero, device: nil)
		self.filteredView?.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		self.renderer = MetalRenderer(mtkview: filteredView!, filter: filterStore)

		self.adjustOrientation()

		self.contentView.insertSubview(self.filteredView!, at: 0)
		var bounds = CGRect.zero
		bounds.size = self.contentView.convert(self.contentView.bounds, to: self.filteredView).size
		self.filteredView?.bounds = bounds
		self.filteredView?.center = CGPoint(x: self.contentView.bounds.size.width/2.0, y: self.contentView.bounds.size.height/2.0);
	}

	@objc func updateLabels() {
		let capturePipeline = captureStream?.capturePipeline
		let fps = Int(roundf(capturePipeline?.videoFrameRate ?? -1))
		self.framerateLabel.text = "\(fps) FPS"
		let width = capturePipeline?.videoDimensions.width ?? 0
		let height = capturePipeline?.videoDimensions.height ?? 0
		self.dimensionsLabel.text = "\(width) × \(height)"
	}

	@objc func refreshFilterDescriptionLabels() {
		let config = filterStore.configuration
		if config.vision == .normal && !config.isUnalteredNormalVision {
			// avoid displaying "normal vision" when other effects are in place
			visionTypeLabel?.text = nil
		} else {
			visionTypeLabel?.text = config.vision.name
		}
		redStripeIndicator?.isHidden = config.stripeConfig.redStripes == 0
		greenStripeIndicator?.isHidden = config.stripeConfig.greenStripes == 0
		blueStripeIndicator?.isHidden = config.stripeConfig.blueStripes == 0
		hueShiftIndicator?.isHidden = !config.hueShift
		invertLuminanceIndicator?.isHidden = !config.invertLuminance
		colorBoostIndicator?.isHidden = !config.colorBoost

		setupMenus()
	}

	// MARK: - RosyWriterCapturePipelineDelegate

	func capturePipeline(_ capturePipeline: CapturePipeline, didStartRunningWithVideoDevice videoDevice: AVCaptureDevice) {
//		self._videoDevice = videoDevice
		self.adjustOrientation()
	}

	@objc func adjustOrientation() {
//		guard let capturePipeline, let previewView else { return }
//		let currentInterfaceOrientation: AVCaptureVideoOrientation = switch UIApplication.shared.statusBarOrientation {
//		case .unknown:            .portrait
//		case .portrait:           .portrait
//		case .portraitUpsideDown: .portraitUpsideDown
//		case .landscapeLeft:      .landscapeLeft
//		case .landscapeRight:     .landscapeRight
//		@unknown default:         .portrait
//		}
//		previewView.transform = capturePipeline.transformFromVideoBufferOrientation(to: currentInterfaceOrientation, withAutoMirroring: false) // Front camera preview should be mirrored
//		let mirrored = self._videoDevice?.position == .front
//		previewView.mirrorTransform = mirrored;
//		previewView.frame = previewView.superview?.bounds ?? previewView.frame
//
//		// capture orientation must compensate for the transform that was applied
//		switch currentInterfaceOrientation {
//		case .portrait:
//			previewView.captureOrientation = !mirrored ? .leftMirrored : .rightMirrored
//		case .portraitUpsideDown:
//			previewView.captureOrientation = !mirrored ? .rightMirrored : .leftMirrored
//		case .landscapeLeft:
//			previewView.captureOrientation = !mirrored ? .upMirrored : .downMirrored
//		case .landscapeRight:
//			previewView.captureOrientation = !mirrored ? .downMirrored : .upMirrored
//		@unknown default:
//			fatalError()
//		}
	}

	func capturePipeline(_ capturePipeline: CapturePipeline, didStopRunningWithError error: Error) {
//		self._videoDevice = nil

		self.presentError(error)

		self.photoButton.isEnabled = false
	}

	@IBAction func sharePicture(_ item: UIBarButtonItem) {
		let image = self.renderer?.currentRenderedImage()
		guard let image else { return }
		var torchActive = false
		if let videoDevice, videoDevice.hasTorch {
			do {
				try videoDevice.lockForConfiguration()
				torchActive = videoDevice.isTorchActive
				videoDevice.torchMode = .off
				videoDevice.unlockForConfiguration()
				self.reflectTorchActiveState(torchActive)
			} catch {
				print("videoDevice lockForConfiguration returned error", error)
			}
		}
		_presentingShareView = true
		self.captureStream?.stopSession() // freeze image
		let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
		if UIDevice.current.userInterfaceIdiom == .pad {
			activityViewController.modalPresentationStyle = .popover
			activityViewController.popoverPresentationController?.barButtonItem = item
		}
		self.present(activityViewController, animated: true)
		activityViewController.completionWithItemsHandler = { (activityType, completed, returnedItems, activityError) in
			self._presentingShareView = false
			self.captureStream?.startSession(in: .zero, delegate: self.renderer!); // unfreeze image
			if torchActive, let videoDevice = self.videoDevice, videoDevice.hasTorch {
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

extension FilterViewController {

	func checkCameraPrivacySettings() {
		AVCaptureDevice.requestAccess(for: .video) { granted in
			DispatchQueue.main.async {
				self.noCameraPermissionOverlayView.isHidden = granted
			}
		}
	}

	func updateCapturePermissionVisibility() {
		let hasCapturePermission = captureStream?.checkCapturePermission() ?? true

		noCameraPermissionOverlayView?.isHidden = hasCapturePermission
		filteredView.isHidden = !hasCapturePermission
	}

	@IBAction func showCameraPrivacySettings(_ sender: Any) {
		UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
	}

}

extension FilterViewController {

	func presentError(_ error: Error) {
		let alert = UIAlertController(
			title: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription,
			message: (error as? LocalizedError)?.failureReason,
			preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
		present(alert, animated: true)
	}

}

extension Array {

	// compensation for lack of .preferredMenuElementOrder
	func iOSLessThan16_reversed() -> Self {
		if #available(iOS 16, *) {
			return self
		} else {
			return self.reversed()
		}
	}

}
