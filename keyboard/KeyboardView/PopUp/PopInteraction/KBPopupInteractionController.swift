//
//  KBPopupInteractionController.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/19.
//

import UIKit
/*
 popup 交互动画引擎
 职责：
 1.    跟手偏移（drag → offset）
 2.    长按进度（time → progress）
 3.    生成几何数据（path / alpha / highlight）
 */

struct PopupInteractionState {
    let headOffsetX: CGFloat
    let expandProgress: CGFloat
}

final class KBPopupInteractionController {
        
    private let followAnimator = KBPopupFollowAnimator()
    private let expandAnimator = KBPopupHeadExpandAnimator()
    
    func begin() {
        expandAnimator.reset()
        followAnimator.reset()
    }
    
    func updateDrag(point: CGPoint) {
//        followAnimator.updateTarget(point.x)
    }
    
    func end() {
        
    }
    
    func setLongPressing(_ pressing: Bool) {
        expandAnimator.setLongPressing(pressing)
    }
    
    func tick() -> PopupInteractionState {
        
        // 跟手
        let offsetX = followAnimator.tick()
        // expand progress
        let progress = expandAnimator.tick()
        return PopupInteractionState(headOffsetX: offsetX, expandProgress: progress)
    }
}
