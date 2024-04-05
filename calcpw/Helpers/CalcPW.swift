//
// CalcPW.swift
// calc.pw
//
// Copyright (c) 2022-2024, Yahe
// All rights reserved.
//

import CommonCrypto
import SwiftUI

struct CalcPW {

    // ===== PRIVATE CONSTANTS =====

    // this will be dependent on the speed of the Raspberry Pi Pico
    private static let PBKDF2_ITERATIONS : UInt32 = 512000

    // ===== PUBLIC CONSTANTS =====

    // set default parameters for generated passwords
    public static let DEFAULT_CHARACTERSET : String = "0-9 A-Z a-z"
    public static let DEFAULT_ENFORCE      : Bool   = false
    public static let DEFAULT_LENGTH       : Int    = 16

    // this defines the max length of the generated password
    public static let PASSWORD_MAX_LENGTH : Int = 1024

    // ===== PRIVATE FUNCTIONS =====

    // encrypt a plaintext block with the key using AES-256-ECB
    private static func aes256_ecb(
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

    // generate the actual password based on the given secret
    // password and information string
    private static func calculatePassword(
        _ password    : String,
        _ information : String,
        _ length      : Int,
        _ charset     : [[Character]],
        _ enforce     : Bool,
        _ state       : Binding<Bool>
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
        state.wrappedValue = true

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
            result             = NSLocalizedString("key derivation failed", comment : "")
            state.wrappedValue = false
        } else {
            // random IV generation
            counter = aes256_ecb(pbkdf2, [UInt8](repeating : 0, count : 16))
            if (0 >= counter.count) {
                result             = NSLocalizedString("random IV generation failed", comment : "")
                state.wrappedValue = false
            } else {
                // key expansion and encoding
                repeat {
                    // get one block of randomness
                    block = aes256_ecb(pbkdf2, counter)

                    if (0 >= block.count) {
                        result             = NSLocalizedString("key expansion failed", comment : "")
                        state.wrappedValue = false
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
                        for i in stride(from : (counter.count-1), to : 0, by : -1) {
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
    private static func deduplicatearray(
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
    private static func isAscii(
        _ string : String
    ) -> Bool {
        var result : Bool = true

        for char in string {
            result = (result && char.isASCII)
        }

        return result
    }

    // check if a string only contains numerics
    private static func isNumeric(
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
    private static func parseCharset(
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
    private static func parseInfo(
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
    private static func pbkdf2_sha256(
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
    private static func sortarray(
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

    // ===== PUBLIC FUNCTIONS =====

    // execute calc.pw password calculation
    public static func calcpw(
        _ password1    : String,
        _ password2    : String,
        _ information  : String,
        _ length       : String,
        _ characterset : String,
        _ enforce      : Bool,
        _ state        : Binding<Bool>
    ) -> String {
        var parsedCharacterset : [[Character]] = []
        var parsedInformation  : String        = ""
        var parsedLength       : Int           = 0
        var result             : String        = ""

        // we fail by default
        state.wrappedValue = false

        // check for errors
        if (!isAscii(password1)) {
            result = NSLocalizedString("password contains illegal characters", comment : "")
        } else if (!isAscii(information)) {
            result = NSLocalizedString("information contains illegal characters", comment : "")
        } else if (!isNumeric(length)) {
            result = NSLocalizedString("length contains illegal characters", comment : "")
        } else if (!isAscii(characterset)) {
            result = NSLocalizedString("character set contains illegal characters", comment : "")
        } else {
            // prepare values
            parsedCharacterset = parseCharset(characterset)
            parsedInformation  = parseInfo(information)
            parsedLength       = Int(length) ?? 0

            // check for more errors
            if (0 >= password1.count) {
                result = NSLocalizedString("password must not be empty", comment : "")
            } else if (password1 != password2) {
                result = NSLocalizedString("passwords do not match", comment : "")
            } else if (0 >= information.count) {
                result = NSLocalizedString("information must not be empty", comment : "")
            } else if (0 >= length.count) {
                result = NSLocalizedString("length must not be empty", comment : "")
            } else if (0 >= parsedLength) {
                result = NSLocalizedString("length must be larger than 0", comment : "")
            } else if (PASSWORD_MAX_LENGTH < parsedLength) {
                result = String(format: NSLocalizedString("length must be smaller than or equal to %d", comment : ""), PASSWORD_MAX_LENGTH)
            } else if (enforce && (parsedLength < parsedCharacterset.count)) {
                result = NSLocalizedString("length is smaller than the number of enforced character groups", comment : "")
            } else if (0 >= characterset.count) {
                result = NSLocalizedString("character set must not be empty", comment : "")
            } else if (0 >= parsedCharacterset.count) {
                result = NSLocalizedString("character set is malformed", comment : "")
            } else {
                // calculate the password
                result = calculatePassword(password1, parsedInformation, parsedLength, parsedCharacterset, enforce, state)
            }
        }

        return result
    }

}
