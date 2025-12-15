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

protocol PopupPresenter: AnyObject {
    func show(for key: KBKey, from frame: CGRect, in parent: UIView)
    func update(at point: CGPoint)
    func commit()
    func hide()
}

protocol KeyboardViewProtocol: AnyObject {
    func didSelectedKeyCap(capText: String)
    func deleteText()
}
