//
// calcpwApp.swift
// calc.pw
//
// Copyright (c) 2022, Yahe
// All rights reserved.
//
// This app implements the calc.pw password calculation algorithm and serves as a reference implementation.
// The calc.pw password calculation contains a key derivation and key expansion function that is combined with
// an encoding function to produce pseudorandom but reproducible passwords from a secret password and a
// service-dependent information.
//

import SwiftUI

@main
struct calcpwApp : App {

    // ===== PUBLIC VARIABLES =====

    // define the app settings
    @AppStorage("characterset", store : .standard) public static var appstorageCharacterset : String = CalcPW.DEFAULT_CHARACTERSET
    @AppStorage("enforce",      store : .standard) public static var appstorageEnforce      : Bool   = CalcPW.DEFAULT_ENFORCE
    @AppStorage("length",       store : .standard) public static var appstorageLength       : String = String(CalcPW.DEFAULT_LENGTH)

    // ===== MAIN INTERFACE TO APP =====

    public var body : some Scene {
        WindowGroup {
            MainView()
        }
    }

}
