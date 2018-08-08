import CoreMedia

extension CMSampleBuffer {
    var dependsOnOthers:Bool {
        guard
            let attachments:CFArray = CMSampleBufferGetSampleAttachmentsArray(self, false) else {
                return false
        }
        let attachment:[NSObject: AnyObject] = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFDictionary.self) as [NSObject : AnyObject]
        return attachment["DependsOnOthers" as NSObject] as! Bool
    }
    var dataBuffer:CMBlockBuffer? {
        get {
            return CMSampleBufferGetDataBuffer(self)
        }
        set {
            guard let dataBuffer:CMBlockBuffer = newValue else {
                return
            }
            CMSampleBufferSetDataBuffer(self, dataBuffer)
        }
    }
    var imageBuffer:CVImageBuffer? {
        return CMSampleBufferGetImageBuffer(self)
    }
    var numSamples:CMItemCount {
        return CMSampleBufferGetNumSamples(self)
    }
    var duration:CMTime {
        return CMSampleBufferGetDuration(self)
    }
    var formatDescription:CMFormatDescription? {
        return CMSampleBufferGetFormatDescription(self)
    }
    var decodeTimeStamp:CMTime {
        return CMSampleBufferGetDecodeTimeStamp(self)
    }
    var presentationTimeStamp:CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self)
    }
}

extension CMSampleBuffer: BytesConvertible {
    // MARK: BytesConvertible
    var bytes:[UInt8] {
        get {
            guard let buffer:CMBlockBuffer = dataBuffer else {
                return []
            }
            var bytes:UnsafeMutablePointer<Int8>? = nil
            var length:Int = 0
            guard CMBlockBufferGetDataPointer(buffer, 0, nil, &length, &bytes) == noErr else {
                return []
            }
            return Array(Data(bytes: bytes!, count: length))
        }
        set {
        }
    }
}
