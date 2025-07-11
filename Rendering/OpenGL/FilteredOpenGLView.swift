import Cocoa
import OpenGL.GL
import OpenGL.GL.GLU
import OpenGL.GL.Macro
import OpenGL.GL.Ext
import OpenGL.GL3

#if os(macOS)
@MainActor
@available(macOS, deprecated: 10.14)
class FilteredOpenGLView: NSOpenGLView {

	weak var delegate: OpenGLRenderer?
	private var _needsReshape = true

	required init(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	static let _defaultPixelFormat = NSOpenGLPixelFormat(attributes: [
		UInt32(NSOpenGLPFAAccelerated),
		UInt32(NSOpenGLPFANoRecovery),
		UInt32(NSOpenGLPFAColorSize), 32,
		UInt32(NSOpenGLPFAAllowOfflineRenderers),
		0,
	])!
	override class func defaultPixelFormat() -> NSOpenGLPixelFormat {
		_defaultPixelFormat
	}

	override init?(frame frameRect: NSRect, pixelFormat format: NSOpenGLPixelFormat?) {
		super.init(frame: frameRect, pixelFormat: format)
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		initialize()
	}

	func initialize() {
		var parm: GLint = 1
		//  Set the swap interval to 1 to ensure that buffers swaps occur only during the vertical retrace of the monitor.
		openGLContext!.setValues(&parm, for: .swapInterval)

		// To ensure best performance, disbale everything you don't need.
		glDisable(GLenum(GL_ALPHA_TEST))
		glDisable(GLenum(GL_DEPTH_TEST))
		glDisable(GLenum(GL_SCISSOR_TEST))
		glDisable(GLenum(GL_BLEND))
		glDisable(GLenum(GL_DITHER))
		glDisable(GLenum(GL_CULL_FACE))
		glColorMask(GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE))
		glDepthMask(GLboolean(GL_FALSE))
		glStencilMask(0)
		glClearColor(0.0, 0.0, 0.0, 0.0)
		glHint(GLenum(GL_TRANSFORM_HINT_APPLE), GLenum(GL_FASTEST))
		_needsReshape = true

		wantsBestResolutionOpenGLSurface = true
	}

	override func draw(_ dirtyRect: NSRect) {
		if _needsReshape {
			updateMatrices()
			glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
			delegate?.didResize(to: drawableSize)
		}
		delegate?.draw()
	}

	override func reshape() {
		_needsReshape = true
	}

	private(set) lazy var drawableSize: CGSize = convertToBacking(bounds.size)

	func updateMatrices() {
		let rect = convertToBacking(bounds)
		drawableSize = rect.size

		openGLContext!.update()

		// Install an orthographic projection matrix (no perspective)
		// with the origin in the bottom left and one unit equal to one device pixel.

		glViewport(0, 0, Int32(rect.size.width), Int32(rect.size.height))

		glMatrixMode(GLenum(GL_PROJECTION))
		glLoadIdentity();
		glOrtho(rect.origin.x,
				rect.origin.x + rect.size.width,
				rect.origin.y,
				rect.origin.y + rect.size.height,
				-1, 1);

		glMatrixMode(GLenum(GL_MODELVIEW))
		glLoadIdentity()
		_needsReshape = false
	}

}
#endif
