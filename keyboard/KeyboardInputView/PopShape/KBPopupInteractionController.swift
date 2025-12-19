//
//  KBPopupInteractionController.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/19.
//

import UIKit
/*
 // 手指按下
 controller.setLongPressing(true)

 // 手指抬起
 controller.setLongPressing(false)

 // displayLink
 controller.tick()
 */
class KBPopupInteractionController: NSObject {

    let shapeLayer = CAShapeLayer()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    let highlightLayer = CALayer()

    private let followAnimator = KBPopupFollowAnimator()
    private let expandAnimator = KBPopupHeadExpandAnimator()
    private let measurer = KBCandidateWidthMeasurer(
        font: UIFont.systemFont(ofSize: 22, weight: .medium)
    )

    var candidates: [CandidateItem] = []
    var keyRect: CGRect = .zero
    var baseRect: CGRect = .zero
    var position: KeyPosition = .center

    func tick() {

        // 跟手
        let offsetX = followAnimator.tick()
        shapeLayer.setAffineTransform(
            CGAffineTransform(translationX: offsetX, y: 0)
        )

        // expand progress
        let progress = expandAnimator.tick()

        // 内容宽度
        let contentWidth = measurer.totalWidth(
            items: candidates,
            itemSpacing: 8,
            horizontalPadding: 12
        )

        let baseExpand = baseHeadExpand(
            position: position,
            candidateCount: candidates.count
        )

        let contentExpand = contentDrivenExpand(
            keyRect: keyRect,
            contentWidth: contentWidth,
            position: position
        )

        let longPressExtra = longPressExtraExpand(position: position)
        
        let path = position.buildPopupPath(
            baseRect: baseRect,
            keyRect: keyRect,
            baseExpand: baseExpand,
            contentExpand: contentExpand,
            longPressExtra: longPressExtra,
            longPressProgress: progress
        )

        shapeLayer.path = path.cgPath

        // blur + highlight 同步
        blurView.alpha = 0.6 + progress * 0.4
        highlightLayer.opacity = Float(0.15 + progress * 0.25)
    }
    
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
