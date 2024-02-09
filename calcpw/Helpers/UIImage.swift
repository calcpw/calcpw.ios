//
// UIImage.swift
// calc.pw
//
// Copyright (c) 2022-2024, Yahe
// All rights reserved.
//

import CoreImage.CIFilterBuiltins
import SwiftUI

extension UIImage {

    // this function generates the QR code
    static func generateQRCode(
        _ message         : String,
        _ correctionLevel : String
    ) -> UIImage {
        var result : UIImage = UIImage(systemName : "xmark.octagon.fill") ?? UIImage()

        if let qrCodeGenerator : CIFilter = CIFilter(name : "CIQRCodeGenerator") {
            qrCodeGenerator.setValue(correctionLevel,    forKey : "inputCorrectionLevel")
            qrCodeGenerator.setValue(Data(message.utf8), forKey : "inputMessage")

            if let outputImage : CIImage = qrCodeGenerator.outputImage {
                if let cgImage : CGImage = CIContext().createCGImage(outputImage, from : outputImage.extent) {
                    result = UIImage(cgImage : cgImage)
                }
            }
        }

        return result
    }
}
