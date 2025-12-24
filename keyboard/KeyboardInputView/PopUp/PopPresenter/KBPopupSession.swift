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
    let candidates: [CandidateItem]
    let keyRect: CGRect
    let position: KeyPosition

    // 预计算
    let contentWidth: CGFloat
    let baseRect: CGRect

    // 环境
    let safeAreaInsets: UIEdgeInsets
    let traitCollection: UITraitCollection
}
