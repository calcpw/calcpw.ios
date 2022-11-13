//
// QRCodeView.swift
// calc.pw
//
// Copyright (c) 2022, Yahe
// All rights reserved.
//

import SwiftUI

struct QRCodeView : View {

    // ===== PRIVATE VARIABLES =====

    // let us dismiss the view
    @Environment(\.dismiss) private var environmentDismiss : DismissAction

    @State private var stateImage : UIImage

    init(
        _ image : UIImage
    ) {
        _stateImage = State(initialValue : image)
    }

    // ===== MAIN INTERFACE TO APP =====

    public var body : some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.5))
                .frame(maxWidth : .infinity, maxHeight : .infinity)

            VStack {
                HStack {
                    Spacer()

                    Image(systemName : "xmark")
                        .foregroundColor(.white)
                        .padding(20)
                }

                Spacer()

                Image(uiImage : stateImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()

                Spacer()
            }
        }.onTapGesture {
            environmentDismiss()
        }
    }

}

struct QRCodeView_Previews : PreviewProvider {

    public static var previews : some View {
        QRCodeView(UIImage.generateQRCode("Example", "L"))
    }

}
