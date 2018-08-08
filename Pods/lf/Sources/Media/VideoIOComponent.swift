import CoreImage
import Foundation
import AVFoundation

final class VideoIOComponent: IOComponent {
    let lockQueue:DispatchQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.VideoIOComponent.lock")
    var drawable:NetStreamDrawable?
    var formatDescription:CMVideoFormatDescription? {
        didSet {
            decoder.formatDescription = formatDescription
        }
    }
    lazy var encoder:H264Encoder = H264Encoder()
    lazy var decoder:H264Decoder = H264Decoder()
    lazy var queue:ClockedQueue = {
        let queue:ClockedQueue = ClockedQueue()
        queue.delegate = self
        return queue
    }()
    fileprivate var effects:[VisualEffect] = []

    var fps:Float64 = AVMixer.defaultFPS {
        didSet {
            guard
                let device:AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                let data = DeviceUtil.getActualFPS(fps, device: device) else {
                return
            }

            fps = data.fps
            encoder.expectedFPS = data.fps
            logger.info("\(data)")

            do {
                try device.lockForConfiguration()
                device.activeVideoMinFrameDuration = data.duration
                device.activeVideoMaxFrameDuration = data.duration
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for fps: \(error)")
            }
        }
    }

    var position:AVCaptureDevicePosition = .back

    var videoSettings:[NSObject:AnyObject] = AVMixer.defaultVideoSettings {
        didSet {
            output.videoSettings = videoSettings
        }
    }

    var orientation:AVCaptureVideoOrientation = .portrait {
        didSet {
            guard orientation != oldValue else {
                return
            }
            for connection in output.connections {
                if let connection:AVCaptureConnection = connection as? AVCaptureConnection {
                    if (connection.isVideoOrientationSupported) {
                        connection.videoOrientation = orientation
                        if (torch) {
                            setTorchMode(.on)
                        }
                    }
                }
            }
            drawable?.orientation = orientation
        }
    }

    var torch:Bool = false {
        didSet {
            guard torch != oldValue else {
                return
            }
            setTorchMode(torch ? .on : .off)
        }
    }

    var continuousAutofocus:Bool = false {
        didSet {
            guard continuousAutofocus != oldValue else {
                return
            }
            let focusMode:AVCaptureFocusMode = continuousAutofocus ? .continuousAutoFocus : .autoFocus
            guard let device:AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                device.isFocusModeSupported(focusMode) else {
                logger.warning("focusMode(\(focusMode.rawValue)) is not supported")
                return
            }
            do {
                try device.lockForConfiguration()
                device.focusMode = focusMode
                device.unlockForConfiguration()
            }
            catch let error as NSError {
                logger.error("while locking device for autofocus: \(error)")
            }
        }
    }

    var focusPointOfInterest:CGPoint? {
        didSet {
            guard
                let device:AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                let point:CGPoint = focusPointOfInterest,
                device.isFocusPointOfInterestSupported else {
                return
            }
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for focusPointOfInterest: \(error)")
            }
        }
    }

    var exposurePointOfInterest:CGPoint? {
        didSet {
            guard
                let device:AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                let point:CGPoint = exposurePointOfInterest,
                device.isExposurePointOfInterestSupported else {
                return
            }
            do {
                try device.lockForConfiguration()
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for exposurePointOfInterest: \(error)")
            }
        }
    }

    var continuousExposure:Bool = false {
        didSet {
            guard continuousExposure != oldValue else {
                return
            }
            let exposureMode:AVCaptureExposureMode = continuousExposure ? .continuousAutoExposure : .autoExpose
            guard let device:AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                device.isExposureModeSupported(exposureMode) else {
                logger.warning("exposureMode(\(exposureMode.rawValue)) is not supported")
                return
            }
            do {
                try device.lockForConfiguration()
                device.exposureMode = exposureMode
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for autoexpose: \(error)")
            }
        }
    }

    fileprivate var _output:AVCaptureVideoDataOutput? = nil
    var output:AVCaptureVideoDataOutput! {
        get {
            if (_output == nil) {
                _output = AVCaptureVideoDataOutput()
                _output!.alwaysDiscardsLateVideoFrames = true
                _output!.videoSettings = videoSettings
            }
            return _output!
        }
        set {
            if (_output == newValue) {
                return
            }
            if let output:AVCaptureVideoDataOutput = _output {
                output.setSampleBufferDelegate(nil, queue: nil)
                mixer?.session.removeOutput(output)
            }
            _output = newValue
        }
    }

    fileprivate(set) var input:AVCaptureInput? = nil {
        didSet {
            guard let mixer:AVMixer = mixer, oldValue != input else {
                return
            }
            if let oldValue:AVCaptureInput = oldValue {
                mixer.session.removeInput(oldValue)
            }
            if let input:AVCaptureInput = input, mixer.session.canAddInput(input) {
                mixer.session.addInput(input)
            }
        }
    }

    #if !os(OSX)
    fileprivate(set) var screen:ScreenCaptureSession? = nil {
        didSet {
            guard oldValue != screen else {
                return
            }
            if let oldValue:ScreenCaptureSession = oldValue {
                oldValue.delegate = nil
            }
            if let screen:ScreenCaptureSession = screen {
                screen.delegate = self
            }
        }
    }
    #endif

    override init(mixer: AVMixer) {
        super.init(mixer: mixer)
        encoder.lockQueue = lockQueue
        decoder.delegate = self
        #if os(iOS)
            if let orientation:AVCaptureVideoOrientation = DeviceUtil.videoOrientation(by: UIDevice.current.orientation) {
                self.orientation = orientation
                }
        #endif
    }

    func attachCamera(_ camera:AVCaptureDevice?) throws {
        guard let mixer:AVMixer = mixer else {
            return
        }
        
        mixer.session.beginConfiguration()
        defer {
            mixer.session.commitConfiguration()
            if (torch) {
                setTorchMode(.on)
            }
        }

        output = nil
        guard let camera:AVCaptureDevice = camera else {
            input = nil
            return
        }
        #if os(iOS)
        screen = nil
        #endif

        input = try AVCaptureDeviceInput(device: camera)
        mixer.session.addOutput(output)
        for connection in output.connections {
            guard let connection:AVCaptureConnection = connection as? AVCaptureConnection else {
                continue
            }
            if (connection.isVideoOrientationSupported) {
                connection.videoOrientation = orientation
            }
        }
        output.setSampleBufferDelegate(self, queue: lockQueue)

        fps = fps * 1
        position = camera.position
        drawable?.position = camera.position
    }

    #if os(OSX)
    func attachScreen(_ screen:AVCaptureScreenInput?) {
        mixer?.session.beginConfiguration()
        output = nil
        guard let _:AVCaptureScreenInput = screen else {
            input = nil
            return
        }
        input = screen
        mixer?.session.addOutput(output)
        output.setSampleBufferDelegate(self, queue: lockQueue)
        mixer?.session.commitConfiguration()
        if (mixer?.session.isRunning ?? false) {
            mixer?.session.startRunning()
        }
    }
    #else
    func attachScreen(_ screen:ScreenCaptureSession?, useScreenSize:Bool = true) {
        guard let screen:ScreenCaptureSession = screen else {
            self.screen?.stopRunning()
            self.screen = nil
            return
        }
        input = nil
        output = nil
        if (useScreenSize) {
            encoder.setValuesForKeys([
                "width": screen.attributes["Width"]!,
                "height": screen.attributes["Height"]!,
            ])
        }
        self.screen = screen
    }
    #endif

    func effect(_ buffer:CVImageBuffer) -> CIImage {
        var image:CIImage = CIImage(cvPixelBuffer: buffer)
        for effect in effects {
            image = effect.execute(image)
        }
        return image
    }

    func registerEffect(_ effect:VisualEffect) -> Bool {
        objc_sync_enter(effects)
        defer {
            objc_sync_exit(effects)
        }
        if let _:Int = effects.index(of: effect) {
            return false
        }
        effects.append(effect)
        return true
    }

    func unregisterEffect(_ effect:VisualEffect) -> Bool {
        objc_sync_enter(effects)
        defer {
            objc_sync_exit(effects)
        }
        if let i:Int = effects.index(of: effect) {
            effects.remove(at: i)
            return true
        }
        return false
    }

    #if os(iOS)
    func ramp(toVideoZoomFactor:CGFloat, withRate:Float) {
        guard let device:AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
            1 <= toVideoZoomFactor && toVideoZoomFactor < device.activeFormat.videoMaxZoomFactor else {
            return
        }
        do {
            try device.lockForConfiguration()
            device.ramp(toVideoZoomFactor: toVideoZoomFactor, withRate: withRate)
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.error("while locking device for ramp: \(error)")
        }
    }
    #endif

    func setTorchMode(_ torchMode:AVCaptureTorchMode) {
        guard let device:AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device, device.isTorchModeSupported(torchMode) else {
            logger.warning("torchMode(\(torchMode)) is not supported")
            return
        }
        do {
            try device.lockForConfiguration()
            device.torchMode = torchMode
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.error("while setting torch: \(error)")
        }
    }

    func dispose() {
        drawable?.attachStream(nil)
        input = nil
        output = nil
    }
}

extension VideoIOComponent: AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ captureOutput:AVCaptureOutput!, didOutputSampleBuffer sampleBuffer:CMSampleBuffer!, from connection:AVCaptureConnection!) {
        guard var buffer:CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let image:CIImage = effect(buffer)
        if (!effects.isEmpty) {
            #if os(macOS)
            // green edge hack for OSX
            buffer = CVPixelBuffer.create(image)!
            #endif
            drawable?.render(image: image, to: buffer)
        }
        encoder.encodeImageBuffer(
            buffer,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            duration: sampleBuffer.duration
        )
        drawable?.draw(image: image)
        mixer?.recorder.appendSampleBuffer(sampleBuffer, mediaType: AVMediaTypeVideo)
    }
}

extension VideoIOComponent: VideoDecoderDelegate {
    // MARK: VideoDecoderDelegate
    func sampleOutput(video sampleBuffer:CMSampleBuffer) {
        queue.enqueue(sampleBuffer)
    }
}

extension VideoIOComponent: ClockedQueueDelegate {
    // MARK: ClockedQueueDelegate
    func queue(_ buffer: CMSampleBuffer) {
        drawable?.draw(image: CIImage(cvPixelBuffer: buffer.imageBuffer!))
    }
}

#if os(iOS)
extension VideoIOComponent: ScreenCaptureOutputPixelBufferDelegate {
    // MARK: ScreenCaptureOutputPixelBufferDelegate
    func didSet(size: CGSize) {
        lockQueue.async {
            self.encoder.width = Int32(size.width)
            self.encoder.height = Int32(size.height)
        }
    }
    func output(pixelBuffer:CVPixelBuffer, withPresentationTime:CMTime) {
        if (!effects.isEmpty) {
            drawable?.render(image: effect(pixelBuffer), to: pixelBuffer)
        }
        encoder.encodeImageBuffer(
            pixelBuffer,
            presentationTimeStamp: withPresentationTime,
            duration: kCMTimeInvalid
        )
        mixer?.recorder.appendPixelBuffer(pixelBuffer, withPresentationTime: withPresentationTime)
    }
}
#endif
