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
final class KBPopupInteractionController {
    
    private var session: KBPopupSession?
    
    private let followAnimator = KBPopupFollowAnimator()
    private let expandAnimator = KBPopupHeadExpandAnimator()
    private let measurer = KBCandidateWidthMeasurer(
        font: UIFont.systemFont(ofSize: 22, weight: .medium)
    )
    
    func begin(session: KBPopupSession) {
        self.session = session
        expandAnimator.reset()
        followAnimator.reset()
    }
    
    func updateDrag(point: CGPoint) {
        followAnimator.updateTarget(point.x)
    }
    
    func end() {
        session = nil
    }
    
    func tick() -> PopupGeometry? {
        
        guard let _session = self.session else {
            return nil
        }
        
        // 跟手
        let offsetX = followAnimator.tick()
        
        // expand progress
        let progress = expandAnimator.tick()
        
        // 内容宽度
        let contentWidth = measurer.totalWidth(
            items: _session.candidates,
            itemSpacing: 8,
            horizontalPadding: 12
        )
        
        let baseExpand = baseHeadExpand(
            position: _session.position,
            candidateCount: _session.candidates.count
        )
        
        let contentExpand = contentDrivenExpand(
            keyRect: _session.keyRect,
            contentWidth: contentWidth,
            position: _session.position
        )
        
        let longPressExtra = longPressExtraExpand(position: _session.position)
        
        let path = _session.position.buildPopupPath(
            baseRect: _session.baseRect,
            keyRect: _session.keyRect,
            baseExpand: baseExpand,
            contentExpand: contentExpand,
            longPressExtra: longPressExtra,
            longPressProgress: progress
        )
        
        return PopupGeometry(
            path: path.cgPath,
            blurAlpha: 0.6 + progress * 0.4,
            highlightOpacity: Float(0.15 + progress * 0.25),
            headOffsetX: offsetX
        )
    }
}

private extension KBPopupInteractionController {
    // head 头部扩展
    func baseHeadExpand(
        position: KeyPosition,
        candidateCount: Int
    ) -> HeadExpand {
        computeHeadExpand(
            keyWidth: 0,
            position: position,
            candidateCount: candidateCount
        )
    }

    func longPressExtraExpand(
        position: KeyPosition
    ) -> HeadExpand {

        let extra: CGFloat = 12

        switch position {
        case .center:
            return HeadExpand(left: extra / 2, right: extra / 2)
        case .left, .leftEdge:
            return HeadExpand(left: 0, right: extra)
        case .right, .rightEdge:
            return HeadExpand(left: extra, right: 0)
        }
    }
    
    func contentDrivenExpand(
        keyRect: CGRect,
        contentWidth: CGFloat,
        position: KeyPosition
    ) -> HeadExpand {

        let extra = max(contentWidth - keyRect.width, 0)

        switch position {
        case .center:
            return HeadExpand(left: extra / 2, right: extra / 2)

        case .left, .leftEdge:
            return HeadExpand(left: 0, right: extra)

        case .right, .rightEdge:
            return HeadExpand(left: extra, right: 0)
        }
    }
    
    func computeHeadExpand(
        keyWidth: CGFloat,
        position: KeyPosition,
        candidateCount: Int
    ) -> HeadExpand {

        let baseExpand: CGFloat = 14
        let candidateStep: CGFloat = 10
        let edgeBoost: CGFloat = 12

        let extra = CGFloat(max(0, candidateCount - 1)) * candidateStep

        switch position {

        case .center:
            return HeadExpand(
                left: baseExpand + extra / 2,
                right: baseExpand + extra / 2
            )

        case .left:
            return HeadExpand(
                left: baseExpand,
                right: baseExpand + extra
            )

        case .right:
            return HeadExpand(
                left: baseExpand + extra,
                right: baseExpand
            )

        case .leftEdge:
            return HeadExpand(
                left: baseExpand,
                right: baseExpand + extra + edgeBoost
            )

        case .rightEdge:
            return HeadExpand(
                left: baseExpand + extra + edgeBoost,
                right: baseExpand
            )
        }
    }
}
