//
//  KBPopupShape.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/8.
//

import UIKit
/*
 head
┌──────────────┐
│              │
└─╮          ╭─┘  ← 弱圆角（r = 3）
  │          │
  │──────────│
  │ keyRect  │
  └──────────┘
 KeyPosition    左外扩               右外扩
 .center        expand              expand
 .left          0.6 × expand        expand
 .right         expand              0.6 × expand
 .leftEdge      0                   expand
 .rightEdge     expand              0
 */

struct PopupShapeConfig {
    /// 头部相对 key 左右外扩
    static let headExpand: CGFloat = 14
    /// 顶部大圆角
    static let topRadius: CGFloat = 12
    /// 脖子到头部的垂直抬升
    static let verticalLift: CGFloat = 8
    /// ⭐ 脖子 → 头部「弱圆角」半径（Apple 核心）
    static let neckFilletRadius: CGFloat = 3
    /// ⭐ 底部圆角
    static let bottomRadius: CGFloat = 6
}

extension KeyPosition {
    
    func path(baseRect: CGRect, keyRect: CGRect, corner: CGFloat = 4) -> UIBezierPath {
        switch self {
        case .leftEdge:
            return drawLeftEdgePopPath(baseRect: baseRect, keyRect: keyRect, corner: corner)
        case .left:
            return drawLeftPopPath(baseRect: baseRect, keyRect: keyRect, corner: corner)
        case .center:
            return drawCenterPopPath(baseRect: baseRect, keyRect: keyRect, corner: corner)
        case .right:
            return drawRightPopPath(baseRect: baseRect, keyRect: keyRect, corner: corner)
        case .rightEdge:
            return drawRightEdgePopPath(baseRect: baseRect, keyRect: keyRect, corner: corner)
        }
    }

    func continuousPopupPath(
            baseRect: CGRect,
            keyRect: CGRect,
            keyHeight: CGFloat,
            headOffsetX: CGFloat = 0
        ) -> UIBezierPath {

        let cfg = PopupShapeConfig.self

        // MARK: - 头部扩展
        let expandL: CGFloat
        let expandR: CGFloat

        switch self {
        case .center:
            expandL = cfg.headExpand
            expandR = cfg.headExpand
        case .left:
            expandL = cfg.headExpand * 0.6
            expandR = cfg.headExpand
        case .right:
            expandL = cfg.headExpand
            expandR = cfg.headExpand * 0.6
        case .leftEdge:
            expandL = 0
            expandR = cfg.headExpand
        case .rightEdge:
            expandL = cfg.headExpand
            expandR = 0
        }

        // MARK: - 关键几何点
        let bottomY = keyRect.maxY

        let bottomLeft  = CGPoint(x: keyRect.minX, y: bottomY)
        let bottomRight = CGPoint(x: keyRect.maxX, y: bottomY)

        let bottomLeftIn  = CGPoint(x: keyRect.minX + cfg.bottomRadius, y: bottomY)
        let bottomRightIn = CGPoint(x: keyRect.maxX - cfg.bottomRadius, y: bottomY)

        let neckTopY = keyRect.minY - cfg.verticalLift
        let filletY  = neckTopY - cfg.neckFilletRadius

        let baseCenterX = keyRect.midX + headOffsetX
        let headLeftX  = max(0, baseCenterX - keyRect.width / 2 - expandL)
        let headRightX = min(baseRect.width, baseCenterX + keyRect.width / 2 + expandR)

        let headTopY = max(0, neckTopY - cfg.topRadius)

        // MARK: - Path
        let path = UIBezierPath()

        // ===== 起点：左下圆角起点 =====
        path.move(to: bottomLeftIn)

        // ===== 左下圆角 =====
        path.addQuadCurve(
            to: CGPoint(x: keyRect.minX, y: bottomY - cfg.bottomRadius),
            controlPoint: bottomLeft
        )

        // ===== 左侧：脖子直上 =====
        path.addLine(to: CGPoint(x: keyRect.minX, y: filletY))

        // ===== 左侧：脖子 → 头部（弱圆角）=====
        path.addQuadCurve(
            to: CGPoint(x: headLeftX, y: neckTopY),
            controlPoint: CGPoint(x: keyRect.minX, y: neckTopY)
        )

        // ===== 左侧：头部直上 =====
        path.addLine(
            to: CGPoint(x: headLeftX, y: headTopY + cfg.topRadius)
        )

        // ===== 左上角 =====
        path.addQuadCurve(
            to: CGPoint(x: headLeftX + cfg.topRadius, y: headTopY),
            controlPoint: CGPoint(x: headLeftX, y: headTopY)
        )

        // ===== 顶边 =====
        path.addLine(
            to: CGPoint(x: headRightX - cfg.topRadius, y: headTopY)
        )

        // ===== 右上角 =====
        path.addQuadCurve(
            to: CGPoint(x: headRightX, y: headTopY + cfg.topRadius),
            controlPoint: CGPoint(x: headRightX, y: headTopY)
        )

        // ===== 右侧：头部直下 =====
        path.addLine(
            to: CGPoint(x: headRightX, y: neckTopY)
        )

        // ===== 右侧：头部 → 脖子（弱圆角）=====
        path.addQuadCurve(
            to: CGPoint(x: keyRect.maxX, y: filletY),
            controlPoint: CGPoint(x: keyRect.maxX, y: neckTopY)
        )

        // ===== 右侧：脖子直下 =====
        path.addLine(
            to: CGPoint(x: keyRect.maxX, y: bottomY - cfg.bottomRadius)
        )

        // ===== 右下圆角 =====
        path.addQuadCurve(
            to: bottomRightIn,
            controlPoint: bottomRight
        )

        // ===== 底边 =====
        path.addLine(to: bottomLeftIn)

        path.close()
        return path
    }
    
    private func drawCenterPopPath(baseRect: CGRect, keyRect: CGRect, corner: CGFloat = 4) -> UIBezierPath {
        
        let path = UIBezierPath()
        
        // 左下角
        let leftBottomStartPoint: CGPoint = CGPoint.init(x: (baseRect.width - keyRect.width) * 0.5 + corner, y: 0)
        let leftBottomEndPoint: CGPoint = CGPoint.init(x: baseRect.width - keyRect.width, y: keyRect.height * 0.5)
//        let leftBottomControlPoint: CGPoint = CGPoint.init(x: (baseRect.width - keyRect.width) * 0.5, y: alienViewSize.height)
        
        path.move(to: leftBottomStartPoint)
//        path.addQuadCurve(to: leftBottomEndPoint, controlPoint: leftBottomControlPoint)
//        
//        let radiusScale: CGFloat = 1.75
//        // 拐角1
//        let leftCorner1StartPoint: CGPoint = CGPoint.init(x: (alienViewSize.width - translateFrame.width) * 0.5, y: alienViewSize.height * alienHeightRatio2 + radius * radiusScale)
//        let leftConner1ControlPoint: CGPoint = CGPoint.init(x: (alienViewSize.width - translateFrame.width) * 0.5, y: alienViewSize.height * alienHeightRatio2)
//        
//        path.addLine(to: leftCorner1StartPoint)
//        
//        // 拐角2
//        let leftCorner2EndPoint: CGPoint = CGPoint.init(x: 0, y: alienViewSize.height * alienHeightRatio1 - radius * radiusScale)
//        let leftConner2ControlPoint: CGPoint = CGPoint.init(x: 0, y: alienViewSize.height * alienHeightRatio1)
//
//        path.addCurve(to: leftCorner2EndPoint, controlPoint1: leftConner1ControlPoint, controlPoint2: leftConner2ControlPoint)
//        
//        // 左上角
//        let leftTopStartPoint: CGPoint = CGPoint.init(x: 0, y: radius * 2)
//        let leftTopEndPoint: CGPoint = CGPoint.init(x: radius * 2, y: 0)
//        let leftTopControlPoint: CGPoint = CGPoint.init(x: 0, y: 0)
//        
//        path.addLine(to: leftTopStartPoint)
//        path.addQuadCurve(to: leftTopEndPoint, controlPoint: leftTopControlPoint)
//    
//        // 右上角
//        let rightTopStartPoint: CGPoint = CGPoint.init(x: alienViewSize.width - radius * 2, y: 0)
//        let rightTopEndPoint: CGPoint = CGPoint.init(x: alienViewSize.width, y: radius * 2)
//        let rightTopControlPoint: CGPoint = CGPoint.init(x: alienViewSize.width, y: 0)
//        
//        path.addLine(to: rightTopStartPoint)
//        path.addQuadCurve(to: rightTopEndPoint, controlPoint: rightTopControlPoint)
//        
//        // 拐角1
//        let rightCorner1StartPoint: CGPoint = CGPoint.init(x: alienViewSize.width, y: alienViewSize.height * alienHeightRatio1 - radius * radiusScale)
//        let rightConner1ControlPoint: CGPoint = CGPoint.init(x: alienViewSize.width, y: alienViewSize.height * alienHeightRatio1)
//        
//        path.addLine(to: rightCorner1StartPoint)
//        
//        // 拐角2
//        let rightCorner2EndPoint: CGPoint = CGPoint.init(x: (alienViewSize.width + translateFrame.width) * 0.5, y: alienViewSize.height * alienHeightRatio2 + radius * radiusScale)
//        let rightConner2ControlPoint: CGPoint = CGPoint.init(x: (alienViewSize.width + translateFrame.width) * 0.5, y: alienViewSize.height * alienHeightRatio2)
//        
//        path.addCurve(to: rightCorner2EndPoint, controlPoint1: rightConner1ControlPoint, controlPoint2: rightConner2ControlPoint)
//        
//        // 右下角
//        let rightBottomStartPoint: CGPoint = CGPoint.init(x: (alienViewSize.width + translateFrame.width) * 0.5, y: alienViewSize.height - radius)
//        let rightBottomEndPoint: CGPoint = CGPoint.init(x: (alienViewSize.width + translateFrame.width) * 0.5 - radius, y: alienViewSize.height)
//        let rightBottomControlPoint: CGPoint = CGPoint.init(x: (alienViewSize.width + translateFrame.width) * 0.5, y: alienViewSize.height)
//        
//        path.addLine(to: rightBottomStartPoint)
//        path.addQuadCurve(to: rightBottomEndPoint, controlPoint: rightBottomControlPoint)
        
        path.close()
        return path
    }
    
    private func drawLeftPopPath(baseRect: CGRect, keyRect: CGRect, corner: CGFloat = 8) -> UIBezierPath {
        return UIBezierPath()
    }
    
    private func drawLeftEdgePopPath(baseRect: CGRect, keyRect: CGRect, corner: CGFloat = 8) -> UIBezierPath {
        return UIBezierPath()
    }
    
    private func drawRightPopPath(baseRect: CGRect, keyRect: CGRect, corner: CGFloat = 8) -> UIBezierPath {
        return UIBezierPath()
    }
    
    private func drawRightEdgePopPath(baseRect: CGRect, keyRect: CGRect, corner: CGFloat = 8) -> UIBezierPath {
        return UIBezierPath()
    }
}
