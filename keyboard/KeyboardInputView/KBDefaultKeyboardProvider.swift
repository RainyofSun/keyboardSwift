//
//  KBDefaultKeyboardProvider.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/4.
//

import UIKit

class KBDefaultKeyboardProvider: KeyboardLayoutProviding {

    public func rows(for keyboardType: KeyboardType) -> [KBKeyRow] {
        switch keyboardType {
        case .letters:
            return KBDefaultKeyboardProvider.letterRows()
        case .numbers:
            return KBDefaultKeyboardProvider.numberRows()
        case .symbols:
            return KBDefaultKeyboardProvider.symbolRows()
        }
    }

    static func letterRows() -> [KBKeyRow] {
        // Row 1: Q-P (10 keys)
        let row1Labels = ["Q","W","E","R","T","Y","U","I","O","P"]
        let row1 = KBKeyRow(keys: row1Labels.enumerated().map { KBKey(keyId: "r1_\($0.offset)", keyLabel: $0.element) })

        // Row 2: A-L (9 keys) with half indent
        let row2Labels = ["A","S","D","F","G","H","J","K","L"]
        let row2 = KBKeyRow(keys: row2Labels.enumerated().map { KBKey(keyId: "r2_\($0.offset)", keyLabel: $0.element) }, indent: 0)

        // Row 3: shift, Z-M, backspace. shift/backspace bigger
        var row3Keys = [KBKey(keyId: "shift", keyLabel: "shift", keyType: .shift)]
        row3Keys += ["Z","X","C","V","B","N","M"].enumerated().map { KBKey(keyId: "r3_\($0.offset)", keyLabel: $0.element) }
        row3Keys.append(KBKey(keyId: "backspace", keyLabel: "⌫", keyType: .backspace))
        let row3 = KBKeyRow(keys: row3Keys, customWidthMultipliers: ["shift": 1.6, "backspace": 1.6])

        // Row 4: numbers, emoji, space, return
        let row4Keys = [
            KBKey(keyId: "numbers", keyLabel: "123", keyType: .special),
            KBKey(keyId: "emoji", keyLabel: "🌐", keyType: .special),
            KBKey(keyId: "space", keyLabel: "space", keyType: .space),
            KBKey(keyId: "return", keyLabel: "return", keyType: .returnKey)
        ]
        var row4 = KBKeyRow(keys: row4Keys)
        row4.customWidthMultipliers = ["numbers": 1.2, "emoji": 1.2, "return": 1.6, "space": 6.0]

        return [row1, row2, row3, row4]
    }

    static func numberRows() -> [KBKeyRow] {
        // Simple numeric pad with 3 columns
        let r1 = KBKeyRow(keys: ["1","2","3"].enumerated().map { KBKey(keyId: "n1_\($0.offset)", keyLabel: $0.element) })
        let r2 = KBKeyRow(keys: ["4","5","6"].enumerated().map { KBKey(keyId: "n2_\($0.offset)", keyLabel: $0.element) })
        let r3 = KBKeyRow(keys: ["7","8","9"].enumerated().map { KBKey(keyId: "n3_\($0.offset)", keyLabel: $0.element) })
        let r4 = KBKeyRow(keys: [KBKey(keyId: "decimal", keyLabel: "."), KBKey(keyId: "0", keyLabel: "0"), KBKey(keyId: "backspace", keyLabel: "⌫", keyType: .backspace)])
        return [r1, r2, r3, r4]
    }

    static func symbolRows() -> [KBKeyRow] {
        let r1 = KBKeyRow(keys: ["[","]","{","}","#","%","^","*","+","="].enumerated().map { KBKey(keyId: "s1_\($0.offset)", keyLabel: $0.element) })
        let r2 = KBKeyRow(keys: ["_","/","\\","|","~","<",">","€","£","¥"].enumerated().map { KBKey(keyId: "s2_\($0.offset)", keyLabel: $0.element) })
        let r3 = KBKeyRow(keys: [KBKey(keyId: "123", keyLabel: "123", keyType: .special), KBKey(keyId: "space", keyLabel: "space", keyType: .space), KBKey(keyId: "return", keyLabel: "return", keyType: .returnKey)])
        return [r1, r2, r3]
    }
}
