//
//  KBPopupFollowAnimator.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/19.
//

import UIKit

class KBPopupFollowAnimator: NSObject {

    private(set) var currentOffsetX: CGFloat = 0
    private var targetOffsetX: CGFloat = 0
    // smoothing ≈ 0.18 ~ 0.25
    private let smoothing: CGFloat = 0.22

    func updateTarget(_ x: CGFloat) {
        targetOffsetX = x
    }
    
    func reset() {
        currentOffsetX = 0    // 从键中心开始
        targetOffsetX = 0
    }

    func tick() -> CGFloat {
        currentOffsetX += (targetOffsetX - currentOffsetX) * smoothing
        return currentOffsetX
    }
}
