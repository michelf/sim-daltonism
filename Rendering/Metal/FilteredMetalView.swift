
//  Copyright 2005-2025 Michel Fortin
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import MetalKit

@MainActor
public class FilteredMetalView: MTKView {

	public override init(frame: CGRect, device: MTLDevice?) {
		super.init(frame: frame, device: device)
		postInit()
	}
    public required init(coder: NSCoder) {
        super.init(coder: coder)
		postInit()
    }
	private func postInit() {
		if device == nil {
			self.device = MTLCreateSystemDefaultDevice()
		}
		self.isPaused = true
		self.enableSetNeedsDisplay = true
		self.framebufferOnly = false
		self.autoResizeDrawable = true
#if os(macOS)
		self.autoresizingMask = [.height, .width]
#else
		self.autoresizingMask = [.flexibleHeight, .flexibleWidth]
#endif
	}

	#if os(macOS)
    public override var isOpaque: Bool { get { true } }
    public override var wantsDefaultClipping: Bool { get { false } }
	
    public weak var viewUpdatesSubscriber: ViewUpdatesSubscriber? = nil

    public override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        viewUpdatesSubscriber?.viewWillStartLiveResize()
    }

    public override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        viewUpdatesSubscriber?.viewDidEndLiveResize()
    }
    #endif
}

#if os(macOS)
@MainActor
public protocol ViewUpdatesSubscriber: AnyObject {
    func viewDidEndLiveResize()
    func viewWillStartLiveResize()
}
#endif
