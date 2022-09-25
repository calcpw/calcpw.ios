//
// PrivacyView.swift
// calc.pw
//
// Copyright (c) 2022, Yahe
// All rights reserved.
//

import LocalAuthentication
import SwiftUI

struct PrivacyView : View {

    // ===== PRIVATE VARIABLES =====

    @State private var stateUnlocked     : Binding<Bool>
    @State private var stateUnlockedOnce : Binding<Bool>

    init(
        _ unlocked     : Binding<Bool>,
        _ unlockedOnce : Binding<Bool>
    ) {
        stateUnlocked     = unlocked
        stateUnlockedOnce = unlockedOnce
    }

    // ===== PRIVATE FUNCTION =====

    // handle PrivacyView appear
    private func privacyViewAppeared() {
        UIApplication.shared.hideKeyboard()

        // do not trigger then authentication when we are not asked to
        if (!stateUnlocked.wrappedValue) {
            // prevent the authentication from being called in a loop
            if (!stateUnlockedOnce.wrappedValue) {
                stateUnlockedOnce.wrappedValue = true

                // execute the actual authentication
                privacyViewAuthenticate()
            }
        }
    }

    // handle PrivacyView authentication
    private func privacyViewAuthenticate() {
        let context : LAContext = LAContext()

        // check whether authentication is possible
        if (!context.canEvaluatePolicy(.deviceOwnerAuthentication, error : nil)) {
            // we are not able to use the authentication so we just unlock
            stateUnlocked.wrappedValue     = true
            stateUnlockedOnce.wrappedValue = false
        } else {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason : NSLocalizedString("calc.pw uses your iOS credentials to protect your passwords.", comment : "")) {
                (success, authenticationError) in

                if (success) {
                    // the authentication succeeded
                    stateUnlocked.wrappedValue     = true
                    stateUnlockedOnce.wrappedValue = false
                } else {
                    // the authentication failed
                    stateUnlocked.wrappedValue     = false
                    stateUnlockedOnce.wrappedValue = false
                }
            }
        }
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

    @State private static var stateUnlocked     : Bool = true
    @State private static var stateUnlockedOnce : Bool = false

    public static var previews :  some View {
        PrivacyView($stateUnlocked, $stateUnlockedOnce)
    }

}
