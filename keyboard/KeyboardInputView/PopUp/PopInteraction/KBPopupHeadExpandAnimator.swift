//
//  KBPopupHeadExpandAnimator.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/19.
//

import UIKit

class KBPopupHeadExpandAnimator: NSObject {

    // progress 就是你整个系统的“长按状态源”
    private(set) var progress: CGFloat = 0      // 0 ~ 1
    private var target: CGFloat = 0
    private let smoothing: CGFloat = 0.18

    func setLongPressing(_ pressing: Bool) {
        target = pressing ? 1.0 : 0.0
    }

    func reset() {
        progress = 0          // 当前无扩展
        target = 0            // 目标也为无扩展
    }
    
    func tick() -> CGFloat {
        progress += (target - progress) * smoothing
        return progress
    }
}
