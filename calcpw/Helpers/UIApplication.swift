//
// UIApplication.swift
// calc.pw
//
// Copyright (c) 2022-2024, Yahe
// All rights reserved.
//

import SwiftUI

extension UIApplication {

    // dismiss the keyboard with a tap
    public func hideKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to : nil, from : nil, for : nil)
    }

}
