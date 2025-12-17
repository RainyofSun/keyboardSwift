//
//  KBBaseKeyLayer.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/16.
//

import UIKit

struct KBKeyLayerConfig {
    // 背景色
    var keyBackgroundColor: UIColor = UIColor(white: 0.98, alpha: 1)
    // 圆角
    var cornerRadius: CGFloat = 8
}

class KBBaseKeyLayer: CALayer {

    // MARK: - SubLayers
    private let highlightLayer = CAGradientLayer()
    private let bottomShadeLayer = CAGradientLayer()
    private let separatorLayer = CALayer()

    // MARK: - Init

    override init() {
        super.init()
        commonInit()
    }

    init(config: KBKeyLayerConfig) {
        super.init()
        apply(config: config)
        commonInit()
    }

    override init(layer: Any) {
        super.init(layer: layer)

        guard let other = layer as? KBBaseKeyLayer else { return }

        // ⚠️ 复制“状态”，不是“结构”
        self.backgroundColor = other.backgroundColor
        self.cornerRadius = other.cornerRadius
        self.shadowColor = other.shadowColor
        self.shadowOpacity = other.shadowOpacity
        self.shadowRadius = other.shadowRadius
        self.shadowOffset = other.shadowOffset
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func commonInit() {
        masksToBounds = false
        contentsScale = UIScreen.main.scale

        setupSublayers()
    }

    private func apply(config: KBKeyLayerConfig) {
        backgroundColor = config.keyBackgroundColor.cgColor
        cornerRadius = config.cornerRadius
    }

    private func setupSublayers() {
        // highlight
        highlightLayer.name = "highlight"
        highlightLayer.colors = [
            UIColor(white: 1.0, alpha: 0.18).cgColor,
            UIColor(white: 1.0, alpha: 0.02).cgColor
        ]
        highlightLayer.startPoint = CGPoint(x: 0.5, y: 0)
        highlightLayer.endPoint = CGPoint(x: 0.5, y: 1)
        addSublayer(highlightLayer)

        // bottom shade
        bottomShadeLayer.name = "bottomShade"
        bottomShadeLayer.colors = [
            UIColor.clear.cgColor,
            UIColor(white: 0, alpha: 0.06).cgColor
        ]
        bottomShadeLayer.startPoint = CGPoint(x: 0.5, y: 0)
        bottomShadeLayer.endPoint = CGPoint(x: 0.5, y: 1)
        addSublayer(bottomShadeLayer)

        // separator
        separatorLayer.name = "separator"
        separatorLayer.backgroundColor = UIColor(white: 0.78, alpha: 1).cgColor
        addSublayer(separatorLayer)
    }

    // MARK: - Layout

    override func layoutSublayers() {
        super.layoutSublayers()

        highlightLayer.frame = bounds
        highlightLayer.cornerRadius = cornerRadius

        bottomShadeLayer.frame = bounds
        bottomShadeLayer.cornerRadius = cornerRadius

        let scale = UIScreen.main.scale
        separatorLayer.frame = CGRect(
            x: 0,
            y: bounds.height - 1.0 / scale,
            width: bounds.width,
            height: 1.0 / scale
        )
    }
}
