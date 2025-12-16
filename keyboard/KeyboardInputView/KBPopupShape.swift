//
//  KBPopupShape.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/8.
//

import UIKit

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

public enum KBPopupShape {
    case center(count: Int)
    case left(count: Int)
    case right(count: Int)

    func path(baseRect: CGRect, keyRect: CGRect, corner: CGFloat = 8) -> UIBezierPath {
        let w = baseRect.width
        let h = baseRect.height
        let triangleH: CGFloat = 10
        let triangleW: CGFloat = keyRect.width * 0.6
        let midX = keyRect.midX - baseRect.minX
        let path = UIBezierPath()

        // Top rounded 
        path.move(to: CGPoint(x: corner, y: 0))
        path.addLine(to: CGPoint(x: w - corner, y: 0))
        path.addQuadCurve(to: CGPoint(x: w, y: corner), controlPoint: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h - triangleH - corner))
        path.addQuadCurve(to: CGPoint(x: w - corner, y: h - triangleH), controlPoint: CGPoint(x: w, y: h - triangleH))

        // Right side depends on shape
        switch self {
        case .center:
            // Center popup → triangle in the middle
            path.addLine(to: CGPoint(x: midX + triangleW/2, y: h - triangleH))
            path.addLine(to: CGPoint(x: midX, y: h))
            path.addLine(to: CGPoint(x: midX - triangleW/2, y: h - triangleH))
        case .left:
            // Concave left (triangle biased to left)
            let tx = max(corner*2, midX * 0.6)
            path.addLine(to: CGPoint(x: tx + triangleW/2, y: h - triangleH))
            path.addLine(to: CGPoint(x: tx, y: h))
            path.addLine(to: CGPoint(x: tx - triangleW/2, y: h - triangleH))
        case .right:
            // Concave right (triangle biased to right)
            let tx = min(w - corner*2, midX + (w - midX) * 0.4)
            path.addLine(to: CGPoint(x: tx + triangleW/2, y: h - triangleH))
            path.addLine(to: CGPoint(x: tx, y: h))
            path.addLine(to: CGPoint(x: tx - triangleW/2, y: h - triangleH))
        }

        // Left side
        path.addLine(to: CGPoint(x: corner, y: h - triangleH))
        path.addQuadCurve(to: CGPoint(x: 0, y: h - triangleH - corner), controlPoint: CGPoint(x: 0, y: h - triangleH))
        path.addLine(to: CGPoint(x: 0, y: corner))
        path.addQuadCurve(to: CGPoint(x: corner, y: 0), controlPoint: CGPoint(x: 0, y: 0))

        path.close()
        return path
    }
}
