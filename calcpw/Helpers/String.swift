//
// String.swift
// calc.pw
//
// Copyright (c) 2022-2024, Yahe
// All rights reserved.
//

import Foundation

extension String {

    // string[i]
    public subscript(
        _ i : Int
    ) -> Character {
        return self[index(startIndex, offsetBy : i)]
    }

    // string[n...]
    public subscript (
        _ r : PartialRangeFrom<Int>
    ) -> String {
        let idx1 = index(startIndex, offsetBy : r.lowerBound)
        let idx2 = index(startIndex, offsetBy : count)

        return String(self[idx1..<idx2])
    }

    // string[...n]
    public subscript (
        _ r : PartialRangeThrough<Int>
    ) -> String {
        let idx1 = index(startIndex, offsetBy : 0)
        let idx2 = index(startIndex, offsetBy : r.upperBound)

        return String(self[idx1...idx2])
    }

    // string[..<n]
    public subscript (
        _ r : PartialRangeUpTo<Int>
    ) -> String {
        let idx1 = index(startIndex, offsetBy : 0)
        let idx2 = index(startIndex, offsetBy : r.upperBound)

        return String(self[idx1..<idx2])
    }

    // string[n..<m]
    public subscript (
        _ r : Range<Int>
    ) -> String {
        let idx1 = index(startIndex, offsetBy : r.lowerBound)
        let idx2 = index(startIndex, offsetBy : r.upperBound)

        return String(self[idx1..<idx2])
    }

}
