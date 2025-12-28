//
//  KBLayoutProviding.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/4.
//

import Foundation
import UIKit

enum KeyboardType {
    case letters
    case numbers
    case symbols
}

protocol KeyboardLayoutProviding {
    func rows(for keyboardType: KeyboardType) -> [KBKeyRow]
}

protocol KeyboardViewProtocol: AnyObject {
    func didSelectedKeyCap(capText: String)
    func deleteText()
}
