//
//  KBPopupSession.swift
//  keyboard
//
//  Created by Yu Chen  on 2025/12/25.
//

import UIKit

/*
 •    一次 popup 生命周期内 只读
 •    防止 InteractionController 依赖 View
 •    未来支持：
 •    iPad
 •    Split Keyboard
 •    不同语言 popup
 */
struct KBPopupSession {

    // 固定输入
    let key: KBKey
    let keyRect: CGRect
    let position: KeyPosition
    let parantView: UIView
    // pop 内候选词的内边距
    let contentInset: UIEdgeInsets = .init(top: 8, left: 12, bottom: 8, right: 12)
    // pop 内每个候选词之间的距离
    let itemSpacing: CGFloat = 8
    // pop 内词的字体大小
    let itemFont: UIFont = UIFont.systemFont(ofSize: 20, weight: .medium)
    
    // 预计算
    let baseRect: CGRect

    // 环境
    let safeAreaInsets: UIEdgeInsets
    let traitCollection: UITraitCollection
}
