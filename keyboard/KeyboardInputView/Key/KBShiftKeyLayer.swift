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

    var shiftState: ShiftState = .lowercase {
        didSet { updateAppearance(animated: true) }
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    override init(config: KBKeyLayerConfig) {
        super.init(config: config)
        setupSymbolLayer()
        updateAppearance(animated: false)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSublayers() {
        super.layoutSublayers()

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        symbolLayer.frame = bounds
        symbolLayer.path = shiftSymbolPath(in: bounds).cgPath

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
    
    func shiftSymbolPath(in rect: CGRect) -> UIBezierPath {
        let w = rect.width
        let h = rect.height

        let centerX = w * 0.5
        let topY = h * 0.28
        let headWidth = w * 0.28
        let headHeight = h * 0.18
        let stemWidth = w * 0.12
        let stemHeight = h * 0.32

        let path = UIBezierPath()

        // arrow head
        path.move(to: CGPoint(x: centerX, y: topY))
        path.addLine(to: CGPoint(x: centerX - headWidth * 0.5, y: topY + headHeight))
        path.addLine(to: CGPoint(x: centerX - stemWidth * 0.5, y: topY + headHeight))
        path.addLine(to: CGPoint(x: centerX - stemWidth * 0.5, y: topY + headHeight + stemHeight))
        path.addLine(to: CGPoint(x: centerX + stemWidth * 0.5, y: topY + headHeight + stemHeight))
        path.addLine(to: CGPoint(x: centerX + stemWidth * 0.5, y: topY + headHeight))
        path.addLine(to: CGPoint(x: centerX + headWidth * 0.5, y: topY + headHeight))
        path.close()

        return path
    }
    
    func updateAppearance(animated: Bool) {

        let changes = {
            switch self.shiftState {

            case .lowercase:
                self.symbolLayer.fillColor = UIColor.clear.cgColor
                self.symbolLayer.strokeColor = UIColor.label.cgColor

            case .uppercase:
                self.symbolLayer.fillColor = UIColor.label.cgColor
                self.symbolLayer.strokeColor = UIColor.label.cgColor

            case .locked:
                self.symbolLayer.fillColor = UIColor.label.cgColor
                self.symbolLayer.strokeColor = UIColor.label.cgColor
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
