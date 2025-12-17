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
    // 阴影颜色
    var shadowColor: UIColor = UIColor.black
    // 阴影透明度
    var shadowOpacity: Float = 0.18
    // 阴影圆角
    var shadowRadius: CGFloat = 6.0
    // 阴影扩散
    var shadowOffset: CGSize = CGSize(width: 0, height: 3)
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
        self.masksToBounds = false

        // outer shadow for elevation
        self.shadowColor = config.shadowColor.cgColor
        self.shadowOpacity = config.shadowOpacity
        self.shadowRadius = config.shadowRadius
        self.shadowOffset = config.shadowOffset
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
    
    // 按键按下动画
    public func animateKeyPressDown() {
        // immediate transform with UIView animation for spring-friendly behavior on release
        UIView.animate(withDuration: 0.06, delay: 0, options: [.beginFromCurrentState], animations: {
//            layer.setAffineTransform(CGAffineTransform(scaleX: 0.96, y: 0.96))
            self.shadowOffset = CGSize(width: 0, height: 1)
            self.shadowRadius = 3
            self.backgroundColor = UIColor.lightGray.cgColor
            self.shadowOpacity = 0.22
        })

        // intensify highlight via opacity change
        if let grad = self.sublayers?.first(where: { $0.name == "highlight" }) as? CAGradientLayer {
            let anim = CABasicAnimation(keyPath: "opacity")
            anim.fromValue = grad.opacity
            anim.toValue = 1.0
            anim.duration = 0.12
            grad.opacity = 1.0
            grad.add(anim, forKey: "highlightIn")
        }
    }
    
    // 按键弹起动画
    public func animatePressUp(completion: (() -> Void)? = nil) {

        UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 8, options: [.allowUserInteraction], animations: {
//            layer.setAffineTransform(.identity)
            self.shadowOffset = CGSize(width: 0, height: 3)
            self.shadowRadius = 6
            self.backgroundColor = UIColor(white: 0.98, alpha: 1).cgColor
            self.shadowOpacity = 0.18
        }, completion: { _ in
            // restore highlight
            if let grad = self.sublayers?.first(where: { $0.name == "highlight" }) as? CAGradientLayer {
                let anim = CABasicAnimation(keyPath: "opacity")
                anim.fromValue = grad.opacity
                anim.toValue = 0.9
                anim.duration = 0.12
                grad.opacity = 0.9
                grad.add(anim, forKey: "highlightOut")
            }
            completion?()
        })
    }
}
