//
//  KBPopupSession.swift
//  keyboard
//
//  Created by Yu Chen  on 2025/12/25.
//

import UIKit

/*
 • Popup 生命周期内只读
 • 所有 rect 都是 Keyboard 坐标系
 */
struct KBPopupSession {

    // MARK: - 输入源
    let key: KBKey
    let keyRect: CGRect              // ⬅️ keyboard 坐标系
    let position: KeyPosition

    // MARK: - 内容配置（与坐标无关）
    // pop 内候选词的内边距
    let contentInset: UIEdgeInsets = .init(top: 8, left: 12, bottom: 8, right: 12)
    // pop 内每个候选词之间的距离
    let itemSpacing: CGFloat = 8
    // pop 内词的字体大小
    let itemFont: UIFont = UIFont.systemFont(ofSize: 20, weight: .medium)
    let candidateWidthScale: CGFloat = 0.95   // e.g. 0.95
    let minCandidateWidth: CGFloat = 32     // e.g. 32
    let maxCandidateWidth: CGFloat = 72    // e.g. 72
    
    // MARK: - 环境（Keyboard 世界）
    let keyboardBounds: CGRect       // keyboard.bounds
    let safeAreaInsets: UIEdgeInsets
    let traitCollection: UITraitCollection
}
