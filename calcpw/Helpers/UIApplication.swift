//
// UIApplication.swift
// calc.pw
//
// Copyright (c) 2022, Yahe
// All rights reserved.
//

import SwiftUI

// allow us to dismiss the keyboard with a tap
extension UIApplication {

    public func hideKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to : nil, from : nil, for : nil)
    }

}
