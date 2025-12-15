//
//  KBPopupShape.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/8.
//

import UIKit

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
