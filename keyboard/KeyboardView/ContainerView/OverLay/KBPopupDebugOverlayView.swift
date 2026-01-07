//
//  KBPopupDebugOverlayView.swift
//  keyboard
//
//  Created by Yu Chen  on 2025/12/28.
//

import UIKit

struct KBPopupDebugSnapshot {
    let keyboardBounds: CGRect
    let safeAreaInsets: UIEdgeInsets
    let keyRect: CGRect               // keyboard 坐标系
    let popupFrame: CGRect            // keyboard 坐标系
    let popupPath: CGPath?            // 最终 path
    
    let candidateFrames: [CandidateLayoutItem]
    let textDebugInfos: [KBCenteredTextDebugInfo]
}

protocol KBPopupDebugSink: AnyObject {
    func update(snapshot: KBPopupDebugSnapshot)
}

final class KBPopupDebugOverlayView: UIView {

    // MARK: - Layers
    private let keyRectLayer = CAShapeLayer()
    private let safeAreaLayer = CAShapeLayer()
    private let popupFrameLayer = CAShapeLayer()
    private let popupPathLayer = CAShapeLayer()
    private let centerLineLayer = CAShapeLayer()
    private let candidateLayer = CAShapeLayer()
    
    // MARK: - State
    private var snapshot: KBPopupDebugSnapshot?

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        setupLayers()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setupLayers() {
        // 🔴 Key Rect
        keyRectLayer.strokeColor = UIColor.red.cgColor
        keyRectLayer.fillColor = UIColor.red.withAlphaComponent(0.15).cgColor
        keyRectLayer.lineWidth = 1

        // 🟢 Safe Area
        safeAreaLayer.strokeColor = UIColor.green.cgColor
        safeAreaLayer.fillColor = UIColor.clear.cgColor
        safeAreaLayer.lineDashPattern = [4, 4]
        safeAreaLayer.lineWidth = 1

        // 🔵 Popup Frame
        popupFrameLayer.strokeColor = UIColor.blue.cgColor
        popupFrameLayer.fillColor = UIColor.blue.withAlphaComponent(0.1).cgColor
        popupFrameLayer.lineWidth = 1

        // 🟣 Popup Path
        popupPathLayer.strokeColor = UIColor.purple.cgColor
        popupPathLayer.fillColor = UIColor.clear.cgColor
        popupPathLayer.lineWidth = 2

        // 🟡 Center Line
        centerLineLayer.strokeColor = UIColor.yellow.cgColor
        centerLineLayer.lineWidth = 1
        
        //  candidate Line
        candidateLayer.strokeColor = UIColor.orange.cgColor
        candidateLayer.fillColor = UIColor.clear.cgColor
        candidateLayer.lineWidth = 1

        layer.addSublayer(safeAreaLayer)
        layer.addSublayer(centerLineLayer)
        layer.addSublayer(keyRectLayer)
        layer.addSublayer(popupFrameLayer)
        layer.addSublayer(popupPathLayer)
        layer.addSublayer(candidateLayer)
    }

    // MARK: - Public
    func update(snapshot: KBPopupDebugSnapshot?) {
        self.snapshot = snapshot
        redraw()
    }

    func clear() {
        snapshot = nil

        [keyRectLayer, safeAreaLayer, popupFrameLayer, popupPathLayer, centerLineLayer]
            .forEach { $0.path = nil }

        candidateLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }

    // MARK: - Draw
    private func redraw() {
        guard let s = snapshot else {
            clear()
            return
        }

        candidateLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        // 1️⃣ Key Rect
        keyRectLayer.path = UIBezierPath(rect: s.keyRect).cgPath

        // 2️⃣ Safe Area Rect
        let safeRect = s.keyboardBounds.inset(by: s.safeAreaInsets)
        safeAreaLayer.path = UIBezierPath(rect: safeRect).cgPath

        // 3️⃣ Popup Frame
        popupFrameLayer.path = UIBezierPath(rect: s.popupFrame).cgPath

        // 4️⃣ Popup Path
        popupPathLayer.path = s.popupPath

        // 5️⃣ Center Line
        let midX = s.keyboardBounds.midX
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: midX, y: 0))
        linePath.addLine(to: CGPoint(x: midX, y: s.keyboardBounds.height))
        centerLineLayer.path = linePath.cgPath
        
        //
        // 候选 frame
        s.candidateFrames.forEach {
            addRect($0.frame, color: .systemBlue)
        }

        // 文字调试
        s.textDebugInfos.forEach { info in
            addRect(info.textFrame, color: .systemGreen)
            addLine(y: info.baselineY, color: .systemRed)
            addLine(y: info.ascenderY, color: .systemOrange)
            addLine(y: info.descenderY, color: .systemPurple)
        }
    }
    
    private func addRect(_ rect: CGRect, color: UIColor) {
        let layer = CAShapeLayer()
        layer.path = UIBezierPath(rect: rect).cgPath
        layer.strokeColor = color.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 1
        candidateLayer.addSublayer(layer)
    }

    private func addLine(y: CGFloat, color: UIColor) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: bounds.width, y: y))

        let layer = CAShapeLayer()
        layer.path = path.cgPath
        layer.strokeColor = color.cgColor
        layer.lineDashPattern = [4, 3]
        layer.lineWidth = 1
        candidateLayer.addSublayer(layer)
    }
}
