//
// MainView.swift
// calc.pw
//
// Copyright (c) 2022, Yahe
// All rights reserved.
//

import CommonCrypto
import SwiftUI
import UniformTypeIdentifiers

struct MainView : View {

    // ==== PRIVATE TYPES =====

    // change focused inputs based on this enum
    private enum FocusStateEnum : Hashable {
        case enterPassword
        case repeatPassword
        case enterInformation
        case enterLength
        case enterCharacterSet
    }

    // ===== PRIVATE CONSTANTS =====

    // this defines the timeout to lock the application
    public static let LOCK_TIMEOUT : TimeInterval = 60;

    // this defines the grouping of the displayed password
    private static let PASSWORD_GROUPS_LENGTH : Int = 8

    // this defines the QR code correction level,
    // we select a low-percentage error correction as we will display the QR code on a
    // high-resolution screen which will produce virtually no errors while reading it
    //
    // the available correction levels are:
    // "L" - Low-percentage error correction: 20% of the symbol data is dedicated to error correction.
    // "M" - Medium-percentage error correction: 37% of the symbol data is dedicated to error correction.
    // "Q" - High-percentage error correction: 55% of the symbol data is dedicated to error correction.
    // "H" - Very-high-percentage error correction: 65% of the symbol data is dedicated to error correction.
    private static let QR_CODE_CORRECTION_LEVEL : String = "L"

    // ===== PRIVATE VARIABLES =====

    // let us find out which system text size was chosen
    @Environment(\.dynamicTypeSize) private var environmentDynamicTypeSize  : DynamicTypeSize

    // let us find out if we should hide the app content
    @Environment(\.redactionReasons) private var environmentRedactionReasons : RedactionReasons

    // define our focus state
    @FocusState private var focusState : FocusStateEnum?

    // define our state
    @State private var stateCalculatedPassword     : String              = ""
    @State private var stateCalculationSuccess     : Bool                = false
    @State private var stateCharacterset           : String              = calcpwApp.appstorageCharacterset
    @State private var stateEnforce                : Bool                = calcpwApp.appstorageEnforce
    @State private var stateInformation            : String              = ""
    @State private var stateLastFocus              : FocusStateEnum?     = nil
    @State private var stateLength                 : String              = calcpwApp.appstorageLength
    @State private var stateMessageImage           : String              = ""
    @State private var stateMessageText            : String              = ""
    @State private var statePassword1              : String              = ""
    @State private var statePassword2              : String              = ""
    @State private var stateShowConfiguration      : Bool                = false
    @State private var stateShowMessage            : Bool                = false
    @State private var stateShowPassword           : Bool                = false
    @State private var stateShowQRCode             : Bool                = false
    @State private var stateUIDeviceOrientation    : UIDeviceOrientation = UIDevice.current.orientation
    @State private var stateUnlocked               : Bool                = false
    @State private var stateUnlockedOnce           : Bool                = false
    @State private var stateUnlockedTimestamp      : TimeInterval        = 0

    init(
        _ unlocked : Bool
    ) {
        _stateUnlocked = State(initialValue : unlocked)
    }

    // ===== PRIVATE FUNCTIONS =====

    // handle the calculate-password button click
    private func calculateButtonClicked() {
        if (isMainViewFormFilledOut()) {
            // clear previous password display
            stateCalculatedPassword = ""
            stateCalculationSuccess = false
            stateShowMessage        = false
            stateShowPassword       = false
            stateShowQRCode         = false

            // calculate the password
            stateCalculatedPassword = CalcPW.calcpw(statePassword1, statePassword2, stateInformation, stateLength, stateCharacterset, stateEnforce, $stateCalculationSuccess)
            if (stateCalculationSuccess) {
                // reset configuration
                stateCharacterset = calcpwApp.appstorageCharacterset
                stateEnforce      = calcpwApp.appstorageEnforce
                stateInformation  = ""
                stateLength       = calcpwApp.appstorageLength

                // show an info about it
                showMessageView("Calculated Password", "lock")
            }
        }
    }

    // handle the configuration button click
    private func configurationButtonClicked() {
        withAnimation(.linear) {
            stateShowConfiguration.toggle()
        }
    }

    // handle the configuration return key press
    private func configurationSubmitted() {
        if (!stateShowMessage) {
            if (isMainViewFormFilledOut()) {
                calculateButtonClicked()
            }
        }
    }

    // handle the copy-to-clipboard button click
    private func copyToClipboardButtonClicked() {
        if (stateCalculationSuccess) {
            // copy the password to the local clipboard
            UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier : stateCalculatedPassword]], options : [.localOnly : true])

            // show an info about it
            showMessageView("Copied to Clipboard", "doc.on.clipboard")
        }
    }

    // handle the enter-information return key press
    private func enterInformationSubmitted() {
        if (!stateShowMessage) {
            if (isMainViewFormFilledOut()) {
                calculateButtonClicked()
            } else if (stateCalculationSuccess) {
                copyToClipboardButtonClicked()
            }
        }
    }

    // handle the enter-password return key press
    private func enterPasswordSubmitted() {
        focusState = .repeatPassword
    }

    // check if the configuration is different from the stored default
    private func isConfigurationModified(
    ) -> Bool {
        return ((stateCharacterset != calcpwApp.appstorageCharacterset) ||
                (stateEnforce      != calcpwApp.appstorageEnforce)      ||
                (stateLength       != calcpwApp.appstorageLength))
    }

    // check if all form values are set so that the password can be calculated
    private func isMainViewFormFilledOut(
    ) -> Bool {
        return ((0 < statePassword1.count)     &&
                (0 < statePassword2.count)     &&
                (0 < stateInformation.count)   &&
                (0 < stateLength.count)        &&
                (0 < stateCharacterset.count))
    }

    // handle MainView appear
    private func mainViewAppeared() {
        // when we are unlocked and started the application lock timeout
        // before then let's check if we reached the lock timeout
        if (stateUnlocked && (0 != stateUnlockedTimestamp)) {
            // when the lock timeout is reached we lock the application
            if (MainView.LOCK_TIMEOUT < (Date().timeIntervalSince1970 - stateUnlockedTimestamp)) {
                stateUnlocked     = false
                stateUnlockedOnce = false
            }
        }

        // reset the lock timeout in all cases
        stateUnlockedTimestamp = 0
    }

    // handle MailView disappear
    private func mainViewDisappeared() {
        // when we are unlocked and exit the view then let's start
        // the timeout until the application gets locked
        if (stateUnlocked) {
            stateUnlockedTimestamp = Date().timeIntervalSince1970
        }
    }

    // handle MainView-Form click
    private func mainViewFormClicked() {
        UIApplication.shared.hideKeyboard()
    }

    // handle MessageView disappear
    private func messageViewDisappear() {
        if (nil != stateLastFocus) {
            focusState     = stateLastFocus
            stateLastFocus = nil
        }
    }

    // handle the repeat-password return key press
    private func repeatPasswordSubmitted() {
        focusState = .enterInformation
    }

    // handle save-as-default button click
    private func saveAsDefaultButtonClicked() {
        if (isConfigurationModified()) {
            // store default values
            calcpwApp.appstorageCharacterset = stateCharacterset
            calcpwApp.appstorageEnforce      = stateEnforce
            calcpwApp.appstorageLength       = stateLength

            // show an info about it
            showMessageView("Saved as Default", "square.and.arrow.down")
        }
    }

    // show the message view
    private func showMessageView(
        _ text  : String,
        _ image : String
    ) {
        // save the last focus, will be restored when the message view disappears
        stateLastFocus = focusState

        // configure the message view
        stateMessageImage = image
        stateMessageText  = text

        withAnimation(.linear) {
            // let the message view appear
            stateShowMessage = true
        }
    }

    // handle show-password button click
    private func showPasswordButtonClicked() {
        withAnimation(.linear) {
            stateShowPassword.toggle()
        }
    }

    // handle show-qrcode button click
    private func showQRCodeButtonClicked() {
        withAnimation(.linear) {
            stateShowQRCode = true
        }
    }

    // this splits a string into groups to make it more legible,
    // the deviceOrientation parameter is only used to automatically
    // redraw the text on orientation changes
    private func splitIntoGroups(
        _ string            : String,
        _ deviceOrientation : UIDeviceOrientation
    ) -> String {
        var result : String = ""

        if (0 >= MainView.PASSWORD_GROUPS_LENGTH) {
            result = string
        } else {
            // calculate how many groups per line should fit
            var groupsPerLine : Int = 1
            switch (environmentDynamicTypeSize) {
                case .xSmall:   groupsPerLine = Int((UIScreen.main.bounds.width - 110) / 80)
                case .small:    groupsPerLine = Int((UIScreen.main.bounds.width - 110) / 85)
                case .medium:   groupsPerLine = Int((UIScreen.main.bounds.width - 110) / 85)
                case .large:    groupsPerLine = Int((UIScreen.main.bounds.width - 110) / 90)
                case .xLarge:   groupsPerLine = Int((UIScreen.main.bounds.width - 110) / 95)
                case .xxLarge:  groupsPerLine = Int((UIScreen.main.bounds.width - 110) / 105)
                case .xxxLarge: groupsPerLine = Int((UIScreen.main.bounds.width - 110) / 115)
                default:        groupsPerLine = Int((UIScreen.main.bounds.width - 110) / 200)
            }

            // make sure that there is at least one group per line
            if (groupsPerLine <= 0) {
                groupsPerLine = 1
            }

            for i in stride(from : 0, to : string.count, by : MainView.PASSWORD_GROUPS_LENGTH) {
                // append the next slice
                result.append(string[i..<((i+MainView.PASSWORD_GROUPS_LENGTH <= string.count) ? i+MainView.PASSWORD_GROUPS_LENGTH : string.count)])

                // append a line break or space depending on the number of groups
                result.append((((i / MainView.PASSWORD_GROUPS_LENGTH) + 1) % groupsPerLine == 0) ? "\n" : " ")
            }
        }

        return result.trimmingCharacters(in : .whitespacesAndNewlines)
    }

    // return a Text field with appropriate formatting
    @ViewBuilder private func PasswordText(
        _ string : String
    ) -> some View {
        Text(string)
            .allowsTightening(true)
            .font(.custom("DejaVuSansMono", size : 16))
            .lineLimit(nil)
            .minimumScaleFactor(0.1)
            .scaledToFit()
            .textContentType(.password)
    }

    // ===== MAIN INTERFACE TO APP =====

    public var body : some View {
        if (environmentRedactionReasons.contains(.privacy)) {
            PrivacyView($stateUnlocked, $stateUnlockedOnce)
        } else {
            if (!stateUnlocked) {
                PrivacyView($stateUnlocked, $stateUnlockedOnce)
            } else {
                ZStack {
                    Form {
                        Section(header : Text(LocalizedStringKey("Password"))) {
                            SecureField(LocalizedStringKey("Enter Password"), text : $statePassword1)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .focused($focusState, equals : .enterPassword)
                                .font(Font.custom("DejaVuSansMono", size : 16))
                                .keyboardType(.asciiCapable)
                                .textContentType(.password)
                                .onSubmit {
                                    enterPasswordSubmitted()
                                }

                            SecureField(LocalizedStringKey("Repeat Password"), text : $statePassword2)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .focused($focusState, equals : .repeatPassword)
                                .font(Font.custom("DejaVuSansMono", size : 16))
                                .keyboardType(.asciiCapable)
                                .textContentType(.password)
                                .onSubmit {
                                    repeatPasswordSubmitted()
                                }
                        }

                        Section(header : Text(LocalizedStringKey("Information"))) {
                            TextField(LocalizedStringKey("Enter Information"), text : $stateInformation)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .focused($focusState, equals : .enterInformation)
                                .font(Font.custom("DejaVuSansMono", size : 16))
                                .keyboardType(.asciiCapable)
                                .onSubmit {
                                    enterInformationSubmitted()
                                }

                            // as buttons in Forms look and behave weirdly
                            // we emulate a button by means of an HStack
                            HStack {
                                Text(LocalizedStringKey("Configuration"))
                                    .foregroundColor(.blue)

                                Spacer()

                                Image(systemName : (stateShowConfiguration) ? "chevron.down" : "chevron.right")
                                    .foregroundColor(.blue)
                            }.contentShape(Rectangle())
                            .onTapGesture {
                                configurationButtonClicked()
                            }

                            if (stateShowConfiguration) {
                                HStack {
                                    Text(LocalizedStringKey("Length"))

                                    TextField(LocalizedStringKey("Enter Length"), text : $stateLength)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .focused($focusState, equals : .enterLength)
                                        .font(Font.custom("DejaVuSansMono", size : 16))
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .onSubmit {
                                            configurationSubmitted()
                                        }
                                }

                                HStack {
                                    Text(LocalizedStringKey("Character Set"))

                                    TextField(LocalizedStringKey("Enter Character Set"), text : $stateCharacterset)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .focused($focusState, equals : .enterCharacterSet)
                                        .font(Font.custom("DejaVuSansMono", size : 16))
                                        .keyboardType(.asciiCapable)
                                        .multilineTextAlignment(.trailing)
                                        .onSubmit {
                                            configurationSubmitted()
                                        }
                                }

                                Toggle(isOn : $stateEnforce) {
                                    Text(LocalizedStringKey("Enforce Character Set"))
                                }

                                // as buttons in Forms look and behave weirdly
                                // we emulate a button by means of an HStack
                                HStack(alignment : .center, spacing : 5) {
                                    Spacer()

                                    Image(systemName : "square.and.arrow.down")
                                        .foregroundColor(isConfigurationModified() ? .blue : .gray)

                                    Text(LocalizedStringKey("Save as Default"))
                                        .foregroundColor(isConfigurationModified() ? .blue : .gray)

                                    Spacer()
                                }.contentShape(Rectangle())
                                .onTapGesture {
                                    saveAsDefaultButtonClicked()
                                }
                            }
                        }

                        Section {
                            // as buttons in Forms look and behave weirdly
                            // we emulate a button by means of an HStack
                            HStack(alignment : .center, spacing : 5) {
                                Spacer()

                                Image(systemName : "lock")
                                    .foregroundColor(isMainViewFormFilledOut() ? .blue : .gray)

                                Text(LocalizedStringKey("Calculate Password"))
                                    .foregroundColor(isMainViewFormFilledOut() ? .blue : .gray)

                                Spacer()
                            }.contentShape(Rectangle())
                            .onTapGesture {
                                calculateButtonClicked()
                            }
                        }

                        if ("" != stateCalculatedPassword) {
                            Section {
                                VStack {
                                    if (stateCalculationSuccess) {
                                        HStack {
                                            Image(systemName : "doc.on.clipboard")
                                                .foregroundColor(.blue)
                                                .onTapGesture {
                                                    copyToClipboardButtonClicked()
                                                }

                                            Spacer()

                                            Image(systemName : "qrcode")
                                                .foregroundColor(.blue)
                                                .onTapGesture {
                                                    showQRCodeButtonClicked()
                                                }

                                            Spacer()

                                            Image(systemName : (stateShowPassword) ? "eye.fill" : "eye.slash.fill")
                                                .foregroundColor(.blue)
                                                .onTapGesture {
                                                    showPasswordButtonClicked()
                                                }
                                        }.transaction{ transaction in
                                            transaction.animation = nil
                                        }
                                    }

                                    Spacer()

                                    HStack {
                                        if (!stateCalculationSuccess) {
                                            PasswordText(stateCalculatedPassword)
                                        } else {
                                            if (stateShowPassword) {
                                                PasswordText(splitIntoGroups(stateCalculatedPassword, stateUIDeviceOrientation))
                                            } else {
                                                PasswordText(NSLocalizedString("[hidden]", comment : ""))
                                            }
                                        }
                                    }
                                }.padding(.all)
                            }
                        }
                    }.onTapGesture {
                        mainViewFormClicked()
                    }.disabled(stateShowMessage)

                    if (stateShowMessage) {
                        MessageView(stateMessageText, stateMessageImage, $stateShowMessage)
                            .onDisappear(){
                                messageViewDisappear()
                            }
                    }
                }.onAppear {
                    mainViewAppeared()
                }.onDisappear {
                    mainViewDisappeared()
                }.onReceive(NotificationCenter.Publisher(center : .default, name : UIDevice.orientationDidChangeNotification)) { _ in
                    stateUIDeviceOrientation = UIDevice.current.orientation
                }.sheet(isPresented : $stateShowQRCode) {
                    QRCodeView(UIImage.generateQRCode(stateCalculatedPassword, MainView.QR_CODE_CORRECTION_LEVEL))
                }.statusBar(hidden : false)
                .zIndex(0) // ensure that we are in the back
            }
        }
    }

}

struct MainView_Previews : PreviewProvider {

    public static var previews : some View {
        MainView(true)
    }

}
