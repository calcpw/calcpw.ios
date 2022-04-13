//
// ContentView.swift
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

import CommonCrypto
import SwiftUI
import UniformTypeIdentifiers

// set default parameters for generated passwords
let DEFAULT_CHARACTERSET : String = "0-9 A-Z a-z"
let DEFAULT_ENFORCE      : Bool   = false
let DEFAULT_LENGTH       : Int    = 16

// this will be dependent on the speed of the Raspberry Pi Pico
let PBKDF2_ITERATIONS : UInt32 = 512000

// ===== DO NOT EDIT HERE =====

extension String {
    // string[i]
    subscript(
        _ i : Int
    ) -> Character {
        return self[index(startIndex, offsetBy : i)]
    }

    // string[n...]
    subscript (
        _ r : PartialRangeFrom<Int>
    ) -> String {
        let idx1 = index(startIndex, offsetBy : r.lowerBound)
        let idx2 = index(startIndex, offsetBy : count)

        return String(self[idx1..<idx2])
    }

    // string[...n]
    subscript (
        _ r : PartialRangeThrough<Int>
    ) -> String {
        let idx1 = index(startIndex, offsetBy : 0)
        let idx2 = index(startIndex, offsetBy : r.upperBound)

        return String(self[idx1...idx2])
    }

    // string[..<n]
    subscript (
        _ r : PartialRangeUpTo<Int>
    ) -> String {
        let idx1 = index(startIndex, offsetBy : 0)
        let idx2 = index(startIndex, offsetBy : r.upperBound)

        return String(self[idx1..<idx2])
    }

    // string[n..<m]
    subscript (
        _ r : Range<Int>
    ) -> String {
        let idx1 = index(startIndex, offsetBy : r.lowerBound)
        let idx2 = index(startIndex, offsetBy : r.upperBound)

        return String(self[idx1..<idx2])
    }
}

// allow us to dismiss the keyboard with a tap
extension UIApplication {
    func hideKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to : nil, from : nil, for : nil)
    }
}

struct ContentView : View {
    // let us find out if we should hide the app content
    @Environment(\.redactionReasons) private var redactionReasons : RedactionReasons

    // define our state
    @State private var calculatedPassword    : String        = ""
    @State private var calculationSuccess    : Bool          = false
    @State private var charset               : [[Character]] = []
    @State private var charset_str           : String        = DEFAULT_CHARACTERSET
    @State private var enforce               : Bool          = DEFAULT_ENFORCE
    @State private var information           : String        = ""
    @State private var length                : Int           = 0
    @State private var length_str            : String        = String(DEFAULT_LENGTH)
    @State private var password1             : String        = ""
    @State private var password2             : String        = ""
    @State private var showConfiguration     : Bool          = false
    @State private var showCopiedToClipboard : Bool          = false
    @State private var showPassword          : Bool          = false
    @State private var value                 : String        = ""

    // encrypt a plaintext block with the key using AES-256-ECB
    func aes256_ecb(
        _ key       : [UInt8],
        _ plaintext : [UInt8]
    ) -> [UInt8] {
        var result : [UInt8] = [UInt8](repeating : 0, count : kCCBlockSizeAES128)

        if (kCCSuccess != CCCrypt(CCOperation(kCCEncrypt),
                                  CCAlgorithm(kCCAlgorithmAES),
                                  CCOptions(kCCOptionECBMode),
                                  key,
                                  key.count,
                                  nil,
                                  plaintext,
                                  plaintext.count,
                                  &result,
                                  result.count,
                                  nil)) {
            result = []
        }

        return result
    }

    // handle the button click
    func buttonClicked() {
        // clear previous password display
        calculatedPassword = ""
        calculationSuccess = false
        showPassword       = false

        // check for errors
        if (!isAscii(password1)) {
            calculatedPassword = "password contains illegal characters"
        } else if (!isAscii(information)) {
            calculatedPassword = "information contains illegal characters"
        } else if (!isNumeric(length_str)) {
            calculatedPassword = "length contains illegal characters"
        } else if (!isAscii(charset_str)) {
            calculatedPassword = "character set contains illegal characters"
        } else {
            // prepare values
            charset = parseCharset(charset_str)
            length  = Int(length_str) ?? 0
            value   = parseInfo(information)

            // check for more errors
            if (0 >= password1.count) {
                calculatedPassword = "password must not be empty"
            } else if (password1 != password2) {
                calculatedPassword = "passwords do not match"
            } else if (0 >= value.count) {
                calculatedPassword = "information must not be empty"
            } else if (0 >= length_str.count) {
                calculatedPassword = "length must not be empty"
            } else if (0 >= length) {
                calculatedPassword = "length must be larger than 0"
            } else if (1024 < length) {
                calculatedPassword = "length must be smaller than or equal to 1024"
            } else if (enforce && (length < charset.count)) {
                calculatedPassword = "length is smaller than the number of enforced character groups"
            } else if (0 >= charset_str.count) {
                calculatedPassword = "character set must not be empty"
            } else if (0 >= charset.count) {
                calculatedPassword = "character set is malformed"
            } else {
                // calculate the password
                calculatedPassword = calcpw(password1, information, length, charset, enforce)

                // reset configuration
                charset      = []
                charset_str  = DEFAULT_CHARACTERSET
                enforce      = DEFAULT_ENFORCE
                information  = ""
                length       = 0
                length_str   = String(DEFAULT_LENGTH)
                value        = ""
            }
        }
    }

    // generate the actual password based on the given secret
    // password and information string
    func calcpw(
        _ password    : String,
        _ information : String,
        _ length      : Int,
        _ charset     : [[Character]],
        _ enforce     : Bool
    ) -> String {
        var block      : [UInt8]     = []
        var char       : Character   = "\0"
        var characters : [Character] = []
        var counter    : [UInt8]     = []
        var full       : Bool        = false
        var i          : Int         = 0
        var increment  : UInt8       = 0
        var max        : Int         = 0
        var partial    : Bool        = false
        var pbkdf2     : [UInt8]     = []
        var result     : String      = ""
        var temp       : UInt16      = 0

        // prepare display of calculated password
        calculationSuccess = true

        // flatten the charset to be more time-constant during
        // the encoding, this way we do not have to switch between
        // arrays based on the random data, the generation of the
        // password is also more reproducible as we sort and
        // deduplicate everything
        for i in 0..<charset.count {
            for j in 0..<charset[i].count {
                characters.append(charset[i][j])
            }
        }
        characters = sortarray(characters)
        characters = deduplicatearray(characters)

        // get the max random number we can use to prevent modulo bias later on
        max = (0x100 / characters.count) * characters.count

        // key derivation
        pbkdf2 = pbkdf2_sha256(password, information, PBKDF2_ITERATIONS)
        if (0 >= pbkdf2.count) {
            calculationSuccess = false
            result             = "key derivation failed"
        } else {
            // random IV generation
            counter = aes256_ecb(pbkdf2, [UInt8](repeating : 0, count : 16))
            if (0 >= counter.count) {
                calculationSuccess = false
                result             = "random IV generation failed"
            } else {
                // key expansion and and encoding
                repeat {
                    // get one block of randomness
                    block = aes256_ecb(pbkdf2, counter)

                    if (0 >= block.count) {
                        calculationSuccess = false
                        result             = "key expansion failed"
                    } else {
                        // generate password characters
                        i = 0
                        while ((i < block.count) && (result.count < length)) {
                            // get the character within the flattened charset
                            char = characters[Int(block[i]) % characters.count]

                            // only use bytes that are LOWER than the max value so that
                            // we do not fall victim to the modulo bias
                            if (block[i] < max) {
                                result.append(char)
                            }

                            // enforce the character groups if the length of
                            // the requested password is reached
                            if (enforce && (result.count >= length)) {
                                full = true

                                for a in 0..<charset.count {
                                    partial = false

                                    for b in 0..<charset[a].count {
                                        for c in 0..<result.count {
                                            // we do the comparison first to prevent lazy evaluation from
                                            // hitting us and giving us a more time-constant execution
                                            partial = ((charset[a][b] == result[c]) || partial)
                                        }
                                    }

                                    // if a character from one character group is missing
                                    // then we will switch to false and retry as a consequence,
                                    // to be more time-constant we proceed with the check
                                    full = (partial && full)
                                }

                                // the check failed so we start again
                                if (!full) {
                                    result = ""
                                }
                            }

                            // increment counter
                            i += 1
                        }

                        // time-constant increment counter
                        increment = 0x01
                        for i in stride(from : counter.count-1, to : 0, by : -1) {
                            temp       = UInt16(counter[i]) + UInt16(increment)
                            counter[i] = UInt8(temp % 0x100)
                            increment  = UInt8(temp >> 0x08)
                        }
                    }
                } while ((result.count < length) && (0 < block.count))
            }
        }

        return result
    }

    // Swift may provide such a function but the standard library
    // of the Raspberry Pi Pico may not so we implement it ourselves
    func deduplicatearray(
        _ array : [Character]
    ) -> [Character] {
        var result : [Character] = []

        // we assume that the array is sorted and simply proceed
        // when the next character in the array differs from the
        // previously deduplicated character
        for i in 0..<array.count {
            if ((0 >= result.count) || (array[i] != result[result.count-1])) {
                result.append(array[i])
            }
        }

        return result
    }

    // check if a string only contains ASCII charactes
    func isAscii(
        _ string : String
    ) -> Bool {
        var result : Bool = true

        for char in string {
            result = (result && char.isASCII)
        }

        return result
    }

    // check if a string only contains numerics
    func isNumeric(
        _ string : String
    ) -> Bool {
        var result : Bool = true

        for char in string {
            result = (result && char.isASCII && (0x30...0x39 ~= char.asciiValue!))
        }

        return result
    }

    // parse the character set string and generate a
    // two-dimensional array so we know which characters
    // are valid in an encoded password
    func parseCharset(
        _ charset : String
    ) -> [[Character]] {
        var first   : Character     = "\0"
        var max     : Int           = 0
        var pos     : Int           = 0
        var range   : Bool          = false
        var result  : [[Character]] = [[]]
        var second  : Character     = "\0"
        var temp    : [Character]   = []

        for char in charset.trimmingCharacters(in : .whitespacesAndNewlines) {
            switch (char.asciiValue!) {
            // separator characters start a new character group,
            // several separator characters in a row act as one
            // separator
            case 0x09, 0x0A, 0x0D, 0x20 :
                // clean up the range variables so that their
                // content is accounted for in the current
                // character group
                if ("\0" != first) {
                    result[result.count-1].append(first)
                }
                if (range) {
                    result[result.count-1].append("\u{2D}")
                }

                // seperate two character groups but only if the
                // last character group contains at least one
                // character, otherwise we do nothing
                if (0 < result.last!.count) {
                    result.append([])
                }

                // reset the range variables
                first  = "\0"
                range  = false
                second = "\0"

            case 0x2D :
                // we encountered a minus, if we have not encountered
                // a character before then we just handle it like any
                // other character, otherwise this might be a range
                if (("\0" != first) && (!range)) {
                    range = true
                } else {
                    // this cannot be a range so we continue with the
                    // the default handling of characters by falling through
                    // to the default case
                    fallthrough
                }

            default :
                // if we are not in a range then we just put the character
                // in the character group, otherwise we iterate through the
                // range and add all characters to the character group
                if (!range) {
                    // we have not encountered a range so we can add the
                    // previous character to the character group
                    if ("\0" != first) {
                        result[result.count-1].append(first)
                    }

                    // store current character as $first in case a range is
                    // coming up afterwards
                    first = char
                } else {
                    // we have encountered a range so prepare the iteration
                    second = char

                    // iterate over the range even if it is just a single character
                    if (first.asciiValue! <= second.asciiValue!) {
                        for i in first.asciiValue!...second.asciiValue! {
                            result[result.count-1].append(Character(UnicodeScalar(i)))
                        }
                    } else {
                        for i in second.asciiValue!...first.asciiValue! {
                            result[result.count-1].append(Character(UnicodeScalar(i)))
                        }
                    }

                    // reset the range variables
                    first  = "\0"
                    range  = false
                    second = "\0"
                }
            }
        }

        // clean up the range variables so that their
        // content is accounted for in the current
        // character group
        if ("\0" != first) {
            result[result.count-1].append(first)
        }
        if (range) {
            result[result.count-1].append("\u{2D}")
        }

        // clean up the character groups so that we
        // do not have an empty character group
        if (0 >= result.last!.count) {
            result.removeLast()
        }

        // only proceed if there are character groups left
        if (0 < result.count) {
            // clean up the character groups to improve
            // reproducibility, characters within character
            // groups are sorted and deduplicated
            for i in 0..<result.count {
                // sort the character group
                result[i] = sortarray(result[i])

                // deduplicate the character group
                result[i] = deduplicatearray(result[i])
            }

            // finally sort the character groups based on the first
            // characters within the character group so improve
            // reproducibility, just use a simple bubble sort for
            // that as well
            for a in 0..<result.count {
                for b in 1..<(result.count-a) {
                    // make sure that we do not go out of bounds
                    max = result[b-1].count
                    if (max > result[b].count) {
                        max = result[b].count
                    }

                    // find the first character in the character groups that differs
                    pos = 0
                    while ((pos < max) && (result[b-1][pos] == result[b][pos])) {
                        pos += 1
                    }

                    if (pos == max) {
                        // we did not find a character that differs, but maybe
                        // one character group is larger than the other, the
                        // smaller character group is sorted to the front
                        if (result[b-1].count > result[b].count) {
                            temp        = result[b-1]
                            result[b-1] = result[b]
                            result[b]   = temp
                        }
                    } else {
                        // we found a character that differs
                        if (result[b-1][pos].asciiValue! > result[b][pos].asciiValue!) {
                            temp        = result[b-1]
                            result[b-1] = result[b]
                            result[b]   = temp
                        }
                    }
                }
            }
        }

        return result
    }

    // the information string normally uses in-line-signalling to trigger
    // the querying of additional information, but with a graphical UI we
    // can display corresponding input fields directly, therefore we just
    // cut away the trigger flags and return the actual information value
    func parseInfo(
        _ information : String
    ) -> String {
        var pos    : Int    = -1
        var result : String = ""

        for i in 0..<information.count {
            // the first character of the actual information value needs
            // to be alphanumeric
            if ((0x30...0x39 ~= information[i].asciiValue!) ||
                (0x41...0x5A ~= information[i].asciiValue!) ||
                (0x61...0x7A ~= information[i].asciiValue!)) {
                pos = i

                break
            }
        }

        // handle information value
        if (0 <= pos) {
            result = information[pos...]
        }

        return result
    }

    // derive a key from the password and salt using
    // the iteration count with PBKDF2-SHA-256
    func pbkdf2_sha256(
        _ password   : String,
        _ salt       : String,
        _ iterations : UInt32
    ) -> [UInt8] {
        var result : [UInt8] = [UInt8](repeating : 0, count : kCCKeySizeAES256)

        if (kCCSuccess != CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                               password,
                                               password.lengthOfBytes(using : String.Encoding.utf8),
                                               salt,
                                               salt.lengthOfBytes(using : String.Encoding.utf8),
                                               CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                                               iterations,
                                               &result,
                                               result.count)) {
            result = []
        }

        return result
    }

    // Swift may provide such a function but the standard library
    // of the Raspberry Pi Pico may not so we implement it ourselves
    func sortarray(
        _ array : [Character]
    ) -> [Character] {
        var result : [Character] = array
        var temp   : Character   = "\0"

        // we just use a slightly optimized bubblesort
        for i in 0..<result.count {
            for j in 1..<(result.count-i) {
                if (result[j-1].asciiValue! > result[j].asciiValue!) {
                    temp        = result[j-1]
                    result[j-1] = result[j]
                    result[j]   = temp
                }
            }
        }

        return result
    }

    var body : some View {
        if (redactionReasons.contains(.privacy)) {
            ZStack {
                Rectangle()
                    .fill(Color("BackgroundColor"))
                    .frame(maxWidth : .infinity, maxHeight : .infinity)

                Image("ApplicationImage")
            }.onAppear {
                UIApplication.shared.hideKeyboard()
            }.statusBar(hidden : true)
        } else {
            ZStack {
                Form {
                    Section(header : Text("Password")) {
                        SecureField("Enter Password", text : $password1)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(Font.custom("DejaVuSansMono", size : 16))
                            .keyboardType(.asciiCapable)
                            .textContentType(.password)

                        SecureField("Repeat Password", text : $password2)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(Font.custom("DejaVuSansMono", size : 16))
                            .keyboardType(.asciiCapable)
                            .textContentType(.password)
                    }

                    Section(header : Text("Information")) {
                        TextField("Enter Information", text : $information)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(Font.custom("DejaVuSansMono", size : 16))
                            .keyboardType(.asciiCapable)

                        HStack {
                            Text("Configuration")
                                .foregroundColor(.blue)

                            Spacer()

                            Image(systemName : (showConfiguration) ? "chevron.down" : "chevron.right")
                                .foregroundColor(.blue)
                        }.contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.linear) {
                                showConfiguration.toggle()
                            }
                        }

                        if (showConfiguration) {
                            HStack {
                                Text("Length")

                                TextField("Enter Length", text : $length_str)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .font(Font.custom("DejaVuSansMono", size : 16))
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                            }

                            HStack {
                                Text("Character Set")

                                TextField("Enter Character Set", text : $charset_str)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .font(Font.custom("DejaVuSansMono", size : 16))
                                    .keyboardType(.asciiCapable)
                                    .multilineTextAlignment(.trailing)
                            }

                            Toggle(isOn : $enforce) {
                                Text("Enforce")
                            }
                        }
                    }

                    // as buttons in Forms look and behave weirdly
                    // we emulate a button by means of an HStack
                    Section {
                        HStack {
                            Text("Calculate Password")
                                .foregroundColor(.blue)
                                .frame(maxWidth : .infinity, maxHeight : .infinity, alignment : .center)
                        }.contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.linear) {
                                buttonClicked()
                            }
                        }
                    }

                    Section {
                        HStack (alignment : .firstTextBaseline) {
                            Text((calculationSuccess && (!showPassword)) ? "[hidden]" : calculatedPassword)
                                .fixedSize(horizontal : false, vertical : true)
                                .font(Font.custom("DejaVuSansMono", size : 16))
                                .frame(maxWidth : .infinity, maxHeight : .infinity, alignment : .center)
                                .lineLimit(nil)
                                .padding(.vertical)
                                .textContentType(.password)
                                .textSelection(.enabled)

                            if (calculationSuccess) {
                                Image(systemName : (showPassword) ? "eye.fill" : "eye.slash.fill")
                                .onTapGesture {
                                    showPassword.toggle()
                                }
                            }
                        }.clipped()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // copy the password to the local clipboard
                            UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier : calculatedPassword]], options : [.localOnly : true])

                            // show an info about it
                            withAnimation(.linear) {
                                showCopiedToClipboard = true
                            }
                        }
                    }
                }.onTapGesture {
                    UIApplication.shared.hideKeyboard()
                }

                if (showCopiedToClipboard) {
                    // let us cancel an animation
                    let dispatchItem : DispatchWorkItem = DispatchWorkItem {
                        withAnimation(.linear) {
                            // hide the info with an animation
                            showCopiedToClipboard = false
                        }
                    }

                    ZStack {
                        Rectangle()
                            .fill(.black.opacity(0.5))
                            .frame(maxWidth : .infinity, maxHeight : .infinity)

                        ZStack {
                            RoundedRectangle(cornerRadius : 20)
                                .fill(.gray.opacity(1.0))
                                .frame(width : 250, height : 250)

                            VStack {
                                Image(systemName : "checkmark")
                                    .foregroundColor(.white)
                                    .font(.system(size : 50, weight : .semibold))
                                    .padding(.bottom)

                                Text("Copied to Clipboard")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        }
                    }.onAppear {
                        // start hiding the info right after showing it
                        DispatchQueue.main.asyncAfter(deadline : .now() + 1, execute : dispatchItem)
                    }.onTapGesture {
                        // cancel the hiding animation
                        dispatchItem.cancel()

                        // hide the info directly
                        showCopiedToClipboard = false
                    }.zIndex(1) // ensure that we are on top
                }
            }.statusBar(hidden : false)
        }
    }
}

struct ContentView_Previews : PreviewProvider {
    static var previews : some View {
        ContentView()
    }
}
