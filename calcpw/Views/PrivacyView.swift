//
// PrivacyView.swift
// calc.pw
//
// Copyright (c) 2022, Yahe
// All rights reserved.
//

import SwiftUI

struct PrivacyView : View {

    // ===== PRIVATE FUNCTION =====

    // handle PrivacyView appear
    private func privacyViewAppeared() {
        UIApplication.shared.hideKeyboard()
    }

    // ===== MAIN INTERFACE TO APP =====

    public var body : some View {
        ZStack {
            Rectangle()
                .fill(Color("BackgroundColor"))
                .frame(maxWidth : .infinity, maxHeight : .infinity)

            Image("ApplicationImage")
        }.onAppear {
            privacyViewAppeared()
        }.statusBar(hidden : true)
        .zIndex(1) // ensure that we are on top
    }

}

struct PrivacyView_Previews : PreviewProvider {

    public static var previews :  some View {
        PrivacyView()
    }

}
