//
//  KBShiftKeyLayer.swift
//  keyboard
//
//  Created by Yu Chen  on 2025/12/22.
//

import UIKit

enum ShiftState {
    case lowercase      // 空心
    case uppercase      // 实心
    case locked         // 实心 + 强高亮（可选）
}

class KBShiftKeyLayer: KBBaseKeyLayer {

    private let symbolLayer = CAShapeLayer()
    private let lockIndicatorLayer = CAShapeLayer()
    var shiftState: ShiftState = .lowercase {
        didSet {
            updateAppearance(animated: true)

            if shiftState == .locked {
                playCapsLockBreathing()
            }
        }
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    override init(config: KBKeyLayerConfig) {
        super.init(config: config)
        setupSymbolLayer()
        setupLockIndicatorLayer()
        updateAppearance(animated: false)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSublayers() {
        super.layoutSublayers()

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        symbolLayer.frame = bounds
        symbolLayer.path = shiftSymbolPath(in: bounds).cgPath

        lockIndicatorLayer.frame = bounds
        lockIndicatorLayer.path = lockIndicatorPath(in: bounds).cgPath
        
        CATransaction.commit()
    }
    
    override func applyStyle(animated: Bool) {
        super.applyStyle(animated: animated)

        let color = isDarkMode ? UIColor.white : UIColor.black
        symbolLayer.strokeColor = color.cgColor
        symbolLayer.fillColor =
            shiftState == .lowercase ? UIColor.clear.cgColor : color.cgColor
    }
}

private extension KBShiftKeyLayer {
    func setupSymbolLayer() {
        symbolLayer.contentsScale = UIScreen.main.scale
        symbolLayer.lineJoin = .round
        symbolLayer.lineCap = .round
        symbolLayer.lineWidth = 1.8

        addSublayer(symbolLayer)
    }
    
    func setupLockIndicatorLayer() {
        lockIndicatorLayer.contentsScale = UIScreen.main.scale
        lockIndicatorLayer.lineCap = .round
        lockIndicatorLayer.fillColor = UIColor.label.cgColor
        lockIndicatorLayer.opacity = 0.0
        addSublayer(lockIndicatorLayer)
    }
    
    func shiftSymbolPath(in rect: CGRect) -> UIBezierPath {

        let h = rect.height

        let bodyW = h * 0.18
        let bodyH = h * 0.12

        let headW = bodyW * 2.35
        let headH = bodyH * 1.55

        let corner = bodyH * 0.25

        let cx = rect.midX
        let cy = rect.midY

        let path = UIBezierPath()

        // 起点：body 顶部中线
        path.move(to: CGPoint(x: cx - bodyW * 0.5, y: cy))

        // 向左到箭头底
        path.addLine(to: CGPoint(x: cx - headW * 0.5, y: cy))

        // 箭头顶
        path.addLine(to: CGPoint(x: cx, y: cy - headH))

        // 向右回到底
        path.addLine(to: CGPoint(x: cx + headW * 0.5, y: cy))

        // 回到 body 右上
        path.addLine(to: CGPoint(x: cx + bodyW * 0.5, y: cy))

        // body 右侧
        path.addLine(to: CGPoint(x: cx + bodyW * 0.5, y: cy + bodyH - corner))

        // 右下圆角
        path.addQuadCurve(
            to: CGPoint(x: cx + bodyW * 0.5 - corner, y: cy + bodyH),
            controlPoint: CGPoint(x: cx + bodyW * 0.5, y: cy + bodyH)
        )

        // 底边
        path.addLine(to: CGPoint(x: cx - bodyW * 0.5 + corner, y: cy + bodyH))

        // 左下圆角
        path.addQuadCurve(
            to: CGPoint(x: cx - bodyW * 0.5, y: cy + bodyH - corner),
            controlPoint: CGPoint(x: cx - bodyW * 0.5, y: cy + bodyH)
        )

        path.close()

        return path
    }
    
    func lockIndicatorPath(in rect: CGRect) -> UIBezierPath {

        let h = rect.height

        let width = h * 0.14
        let height: CGFloat = 1.6
        let corner: CGFloat = height * 0.5

        let cx = rect.midX
        let y = rect.midY + h * 0.18

        let rect = CGRect(
            x: cx - width * 0.5,
            y: y,
            width: width,
            height: height
        )

        return UIBezierPath(roundedRect: rect, cornerRadius: corner)
    }
    
    func updateAppearance(animated: Bool) {

        let baseBackground: CGColor = {
            isDarkMode
            ? UIColor(white: 0.22, alpha: 1).cgColor
            : UIColor(white: 0.98, alpha: 1).cgColor
        }()

        let lockBackground: CGColor =
            UIColor.systemBlue.withAlphaComponent(isDarkMode ? 0.28 : 0.18).cgColor

        let changes = {

            switch self.shiftState {

            case .lowercase:
                self.symbolLayer.fillColor = UIColor.clear.cgColor
                self.symbolLayer.strokeColor = UIColor.label.cgColor
                self.backgroundColor = baseBackground
                self.animateLockIndicator(show: false)

            case .uppercase:
                self.symbolLayer.fillColor = UIColor.label.cgColor
                self.symbolLayer.strokeColor = UIColor.label.cgColor
                self.backgroundColor = baseBackground
                self.animateLockIndicator(show: false)

            case .locked:
                self.symbolLayer.fillColor = UIColor.label.cgColor
                self.symbolLayer.strokeColor = UIColor.label.cgColor
                self.backgroundColor = lockBackground
                self.animateLockIndicator(show: true)
            }
        }

        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.12)
            changes()
            CATransaction.commit()
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            changes()
            CATransaction.commit()
        }
    }
}

// MARK: - Animation
private extension KBShiftKeyLayer {
    func animateLockIndicator(show: Bool) {

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = show ? 0.0 : 1.0
        opacityAnim.toValue = show ? 1.0 : 0.0
        opacityAnim.duration = 0.12

        let scaleAnim = CABasicAnimation(keyPath: "transform.scale.x")
        scaleAnim.fromValue = show ? 0.6 : 1.0
        scaleAnim.toValue = show ? 1.0 : 0.6
        scaleAnim.duration = 0.12
        scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)

        lockIndicatorLayer.opacity = show ? 1.0 : 0.0
        lockIndicatorLayer.add(opacityAnim, forKey: "opacity")
        lockIndicatorLayer.add(scaleAnim, forKey: "scale")
    }
    
    func playCapsLockBreathing() {

        lockIndicatorLayer.removeAnimation(forKey: "capsBreath")

        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 0.4
        anim.toValue = 1.0
        anim.duration = 0.9
        anim.autoreverses = true
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.repeatCount = 2       // ❗ 系统只呼吸两次
        anim.isRemovedOnCompletion = true

        lockIndicatorLayer.add(anim, forKey: "capsBreath")
    }
}
