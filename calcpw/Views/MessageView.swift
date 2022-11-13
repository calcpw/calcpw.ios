//
// MessageView.swift
// calc.pw
//
// Copyright (c) 2022, Yahe
// All rights reserved.
//

import SwiftUI

struct MessageView : View {

    // ===== PRIVATE VARIABLES =====

    @State private var stateDispatchItem : DispatchWorkItem?
    @State private var stateImage        : String
    @State private var stateShowMessage  : Binding<Bool>
    @State private var stateText         : String

    init(
        _ text        : String,
        _ image       : String,
        _ showMessage : Binding<Bool>
    ) {
        _stateDispatchItem = State(initialValue : nil)
        _stateImage        = State(initialValue : image)
        _stateShowMessage  = State(initialValue : showMessage)
        _stateText         = State(initialValue : text)
    }

    // ===== PRIVATE FUNCTIONS =====

    // handle MessageView appear
    private func messageViewAppeared() {
        // allows us to hide the message
        stateDispatchItem = DispatchWorkItem {
            withAnimation(.linear) {
                // hide the info with an animation
                stateShowMessage.wrappedValue = false
            }
        }

        // start hiding the info right after showing it
        DispatchQueue.main.asyncAfter(deadline : .now() + 1, execute : stateDispatchItem!)
    }

    // handle MessageView click
    private func messageViewClicked() {
        // hide the info right away
        stateShowMessage.wrappedValue = false
    }

    // handle MessageView disappear
    private func messageViewDisappeared() {
        // cancel the hiding animation
        stateDispatchItem?.cancel()
    }

    // ===== MAIN INTERFACE TO APP =====

    public var body : some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.5))
                .frame(maxWidth : .infinity, maxHeight : .infinity)

            ZStack {
                RoundedRectangle(cornerRadius : 20)
                    .fill(.gray)
                    .frame(width : 300, height : 300)

                VStack {
                    Image(systemName : stateImage)
                        .foregroundColor(.white)
                        .font(.system(size : 50, weight : .semibold))
                        .padding(.bottom)

                    Text(LocalizedStringKey(stateText))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth : 250, maxHeight : .infinity, alignment : .center)
                        .minimumScaleFactor(0.1)
                        .scaledToFit()
                }
            }
        }.onAppear {
            messageViewAppeared()
        }.onDisappear {
            messageViewDisappeared()
        }.onTapGesture {
            messageViewClicked()
        }.zIndex(1) // ensure that we are on top
    }

}

struct MessageView_Previews : PreviewProvider {

    @State private static var stateShowMessage : Bool = true

    public static var previews : some View {
        MessageView("Example Text", "questionmark", $stateShowMessage)
    }

}
