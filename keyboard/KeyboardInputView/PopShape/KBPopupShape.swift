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
    /// 顶部大圆角
    let topRadius: CGFloat = 6
    
    /// 底部圆角
    let bottomRadius: CGFloat = 6

    /// 脖子到头部的垂直抬升
    let verticalLift: CGFloat = 8

    /// ⭐ 脖子 → 头部弱圆角
    let neckFilletRadius: CGFloat = 3

    /// 脖子与 key 顶部的贴合高度
    let neckAttachInset: CGFloat = 3
}

struct HeadExpand {
    let left: CGFloat
    let right: CGFloat

    static func lerp(
        from: HeadExpand,
        to: HeadExpand,
        t: CGFloat
    ) -> HeadExpand {
        HeadExpand(
            left: from.left + (to.left - from.left) * t,
            right: from.right + (to.right - from.right) * t
        )
    }
}

// V0 版本
//extension KeyPosition {
//
//    func continuousPopupPath(baseRect: CGRect, keyRect: CGRect, keyHeight: CGFloat, headOffsetX: CGFloat = 0 ) -> UIBezierPath {
//        let path = UIBezierPath()
//        let config = PopupShapeConfig()
//        
//        // 起始点
//        let startX: Double = keyRect.minX + config.bottomRadius
//        let startY: Double = keyRect.maxY
//        
//        path.move(to: CGPoint(x: startX, y: startY))
//        
//        // 底部左拐角
//        let endLeftX: Double = keyRect.minX
//        let endLeftY: Double = keyRect.maxY - config.bottomRadius
//        let controlPoint: CGPoint = CGPoint(x: keyRect.minX, y: keyRect.maxY)
//        
//        path.addQuadCurve(to: CGPoint(x: endLeftX, y: endLeftY), controlPoint: controlPoint)
//        
//        // 左边直线
//        path.addLine(to: CGPoint(x: keyRect.minX, y: keyRect.minY + 3))
//        
//        // 拐角终点
//        let cornerEndX: Double = baseRect.minX
//        let cornerEndY: Double = keyRect.minY - config.verticalLift - 6
//        // 控制点
//        let controlPoint1: CGPoint = CGPoint(x: keyRect.minX, y: keyRect.minY - config.verticalLift * 0.35)
//        let controlPoint2: CGPoint = CGPoint(x: baseRect.minX, y: keyRect.minY - config.verticalLift * 0.85)
//        
//        path.addCurve(to: CGPoint(x: cornerEndX, y: cornerEndY), controlPoint1: controlPoint1, controlPoint2: controlPoint2)
//        
//        // 头部左直线
//        path.addLine(to: CGPoint(x: baseRect.minX, y: baseRect.minY + config.topRadius))
//        
//        // 头部左拐角
//        let leftHeadEndX: Double = baseRect.minX + config.topRadius
//        let leftHeadEndY: Double = baseRect.minY
//        
//        path.addQuadCurve(to: CGPoint(x: leftHeadEndX, y: leftHeadEndY), controlPoint: CGPoint(x: baseRect.minX, y: baseRect.minY))
//        
//        // 头部顶直线
//        path.addLine(to: CGPoint(x: baseRect.maxX - config.topRadius, y: baseRect.minY))
//        
//        // 头部右拐角
//        let rightHeadEndX: Double = baseRect.maxX
//        let rightHeadEndY: Double = baseRect.minY + config.topRadius
//        
//        path.addQuadCurve(to: CGPoint(x: rightHeadEndX, y: rightHeadEndY), controlPoint: CGPoint(x: baseRect.maxX, y: baseRect.minY))
//        
//        // 头部右直线
//        path.addLine(to: CGPoint(x: baseRect.maxX, y: cornerEndY))
//        
//        // 拐角终点
//        let cornerEndX1: Double = keyRect.maxX
//        let cornerEndY1: Double = keyRect.minY + 3
//        // 控制点
//        let controlPoint3: CGPoint = CGPoint(x: baseRect.maxX, y: keyRect.minY - config.verticalLift * 0.85)
//        let controlPoint4: CGPoint = CGPoint(x: keyRect.maxX, y: keyRect.minY - config.verticalLift * 0.35)
//        
//        path.addCurve(to: CGPoint(x: cornerEndX1, y: cornerEndY1), controlPoint1: controlPoint3, controlPoint2: controlPoint4)
//        
//        // 右边直线
//        path.addLine(to: CGPoint(x: keyRect.maxX, y: keyRect.maxY - config.bottomRadius))
//        
//        // 底部右边拐角
//        path.addQuadCurve(to: CGPoint(x: keyRect.maxX - config.bottomRadius, y: keyRect.maxY), controlPoint: CGPoint(x: keyRect.maxX, y: keyRect.maxY))
//        
//        path.close()
//        return path
//    }
//}

// V1 版本
//extension KeyPosition {
//
//    func continuousPopupPath(baseRect: CGRect, keyRect: CGRect, keyHeight: CGFloat, headOffsetX: CGFloat = 0) -> UIBezierPath {
//
//        let c = PopupShapeConfig()
//        let path = UIBezierPath()
//
//        // MARK: - 关键 Y 坐标
//        let keyBottomY = keyRect.maxY
//        let keyTopY = keyRect.minY
//        let neckBottomY = keyTopY + c.neckAttachInset
//        let neckTopY = keyTopY - c.verticalLift
//
//        // MARK: - 起点（底部左）
//        path.move(to: CGPoint( x: keyRect.minX + c.bottomRadius, y: keyBottomY))
//
//        // MARK: - 底部左圆角
//        path.addQuadCurve(to: CGPoint(x: keyRect.minX, y: keyBottomY - c.bottomRadius), controlPoint: CGPoint(x: keyRect.minX, y: keyBottomY))
//
//        // MARK: - 左侧直线（key）
//        path.addLine(to: CGPoint(x: keyRect.minX,y: neckBottomY))
//
//        // MARK: - 左脖子弱圆角 + 上升曲线
//        path.addCurve(to: CGPoint(x: baseRect.minX, y: neckTopY), controlPoint1: CGPoint(x: keyRect.minX, y: neckBottomY - c.neckFilletRadius), controlPoint2: CGPoint(x: baseRect.minX, y: neckTopY + c.neckFilletRadius))
//
//        // MARK: - 头部左直线
//        path.addLine(to: CGPoint(x: baseRect.minX, y: baseRect.minY + c.topRadius))
//
//        // MARK: - 头部左上圆角
//        path.addQuadCurve(to: CGPoint(x: baseRect.minX + c.topRadius, y: baseRect.minY),controlPoint: CGPoint(x: baseRect.minX, y: baseRect.minY))
//
//        // MARK: - 头部顶部
//        path.addLine(to: CGPoint(x: baseRect.maxX - c.topRadius, y: baseRect.minY))
//
//        // MARK: - 头部右上圆角
//        path.addQuadCurve( to: CGPoint(x: baseRect.maxX, y: baseRect.minY + c.topRadius), controlPoint: CGPoint(x: baseRect.maxX, y: baseRect.minY))
//
//        // MARK: - 头部右直线
//        path.addLine(to: CGPoint(x: baseRect.maxX, y: neckTopY))
//
//        // MARK: - 右脖子弱圆角 + 下降曲线（完全镜像）
//        path.addCurve(to: CGPoint(x: keyRect.maxX, y: neckBottomY), controlPoint1: CGPoint(x: baseRect.maxX,y: neckTopY + c.neckFilletRadius), controlPoint2: CGPoint(x: keyRect.maxX, y: neckBottomY - c.neckFilletRadius))
//
//        // MARK: - 右侧直线（key）
//        path.addLine(to: CGPoint(x: keyRect.maxX, y: keyBottomY - c.bottomRadius))
//
//        // MARK: - 底部右圆角
//        path.addQuadCurve( to: CGPoint(x: keyRect.maxX - c.bottomRadius, y: keyBottomY), controlPoint: CGPoint(x: keyRect.maxX, y: keyBottomY))
//
//        path.close()
//        return path
//    }
//}

// V2 版本
extension KeyPosition {
    
    func buildPopupPath(
        baseRect: CGRect,
        keyRect: CGRect,
        baseExpand: HeadExpand,
        contentExpand: HeadExpand,
        longPressExtra: HeadExpand,
        longPressProgress: CGFloat
    ) -> UIBezierPath {
        
        let c = PopupShapeConfig()
        let path = UIBezierPath()
        
        let expand = finalHeadExpand(
            base: baseExpand,
            content: contentExpand,
            longPressExtra: longPressExtra,
            progress: longPressProgress
        )

        let headRect = CGRect(
            x: keyRect.minX - expand.left,
            y: baseRect.minY,
            width: keyRect.width + expand.left + expand.right,
            height: baseRect.height
        )
        
        // MARK: - Y 轴关键点
        let keyBottomY = keyRect.maxY
        let keyTopY = keyRect.minY
        let neckBottomY = keyTopY + c.neckAttachInset
        let neckTopY = keyTopY - c.verticalLift
        
        // MARK: - Path 开始
        path.move(to: CGPoint(
            x: keyRect.minX + c.bottomRadius,
            y: keyBottomY
        ))
        
        // 底部左
        path.addQuadCurve(
            to: CGPoint(x: keyRect.minX, y: keyBottomY - c.bottomRadius),
            controlPoint: CGPoint(x: keyRect.minX, y: keyBottomY)
        )
        
        // 左边直线
        path.addLine(to: CGPoint(x: keyRect.minX, y: neckBottomY))
        
        // 左脖子
        path.addCurve(
            to: CGPoint(x: headRect.minX, y: neckTopY),
            controlPoint1: CGPoint(
                x: keyRect.minX,
                y: neckBottomY - c.neckFilletRadius
            ),
            controlPoint2: CGPoint(
                x: headRect.minX,
                y: neckTopY + c.neckFilletRadius
            )
        )
        
        // 头部左
        path.addLine(to: CGPoint(
            x: headRect.minX,
            y: headRect.minY + c.topRadius
        ))
        
        path.addQuadCurve(
            to: CGPoint(
                x: headRect.minX + c.topRadius,
                y: headRect.minY
            ),
            controlPoint: CGPoint(
                x: headRect.minX,
                y: headRect.minY
            )
        )
        
        // 顶部
        path.addLine(to: CGPoint(
            x: headRect.maxX - c.topRadius,
            y: headRect.minY
        ))
        
        // 头部右
        path.addQuadCurve(
            to: CGPoint(
                x: headRect.maxX,
                y: headRect.minY + c.topRadius
            ),
            controlPoint: CGPoint(
                x: headRect.maxX,
                y: headRect.minY
            )
        )
        
        path.addLine(to: CGPoint(
            x: headRect.maxX,
            y: neckTopY
        ))
        
        // 右脖子
        path.addCurve(
            to: CGPoint(x: keyRect.maxX, y: neckBottomY),
            controlPoint1: CGPoint(
                x: headRect.maxX,
                y: neckTopY + c.neckFilletRadius
            ),
            controlPoint2: CGPoint(
                x: keyRect.maxX,
                y: neckBottomY - c.neckFilletRadius
            )
        )
        
        // 右边直线
        path.addLine(to: CGPoint(
            x: keyRect.maxX,
            y: keyBottomY - c.bottomRadius
        ))
        
        // 底部右
        path.addQuadCurve(
            to: CGPoint(
                x: keyRect.maxX - c.bottomRadius,
                y: keyBottomY
            ),
            controlPoint: CGPoint(
                x: keyRect.maxX,
                y: keyBottomY
            )
        )
        
        path.close()
        return path
    }
    
    func finalHeadExpand(
        base: HeadExpand,
        content: HeadExpand,
        longPressExtra: HeadExpand,
        progress: CGFloat
    ) -> HeadExpand {

        HeadExpand(
            left: base.left
                + content.left
                + longPressExtra.left * progress,
            right: base.right
                + content.right
                + longPressExtra.right * progress
        )
    }
}
