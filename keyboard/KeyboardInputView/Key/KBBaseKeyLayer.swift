//
//  KBBaseKeyLayer.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/16.
//

import UIKit

struct KBKeyLayerConfig {
    // 圆角
    var cornerRadius: CGFloat = 8
    // 阴影颜色
    var shadowColor: UIColor = UIColor.black
}

struct KBKeyTextLayerConfig {
    // 字体
    var keyFont: UIFont = UIFont.systemFont(ofSize: 18)
    // 字体颜色
    var keyTextColor: UIColor = UIColor.label
}

class KBBaseKeyLayer: CALayer {

    // MARK: - SubLayers
    private let highlightLayer = CAGradientLayer()
    private let bottomShadeLayer = CAGradientLayer()
    private let separatorLayer = CALayer()
    private var _textLayer: CATextLayer?
    
    var keyRole: KBKeyRole = .character
    private var visualState: KBKeyVisualState = .normal

    var isDarkMode: Bool {
        traitCollection?.userInterfaceStyle == .dark
    }

    weak var traitCollection: UITraitCollection?
    // 当前活跃 key 的 交互序列
    public var currentInteractionSeq: Int = 0
    
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

        guard let other = layer as? KBBaseKeyLayer else {
            return
        }

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
    
    // MARK: - Animation
    // 按键按下动画 -- 按键按下的瞬时态动画
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
    
    // 键盘按键稳定态动画切换
    public func setVisualState(_ state: KBKeyVisualState, animated: Bool) {
        visualState = state
        applyStyle(animated: animated)
    }
    
    // MARK: - Key
    // 创建 key 的文字
    public func createTextLayerIfNeeded(textLayerConfig: KBKeyTextLayerConfig) {
        guard self._textLayer == nil else {
            return
        }
        
        let t = CATextLayer()
        t.contentsScale = UIScreen.main.scale
        t.alignmentMode = .center
        t.isWrapped = false
        t.truncationMode = .end
        t.foregroundColor = textLayerConfig.keyTextColor.cgColor
        t.font = textLayerConfig.keyFont
        t.fontSize = textLayerConfig.keyFont.pointSize
        t.isWrapped = false
        self.addSublayer(t)
        self._textLayer = t
    }
    
    public func updateTextLayer(key: KBKey, config: KBKeyTextLayerConfig) {
        guard let t = _textLayer else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        t.string = key.keyLabel as NSString

        let size = (key.keyLabel as NSString).size(
            withAttributes: [.font: config.keyFont]
        )

        t.frame = CGRect(
            x: 0,
            y: (bounds.height - size.height) * 0.5 - 1,
            width: bounds.width,
            height: size.height
        )

        CATransaction.commit()
    }
    
    // 清理文字层
    public func clearTextLayer() {
        self._textLayer?.removeAllAnimations()
        self._textLayer?.removeFromSuperlayer()
    }
    
    // MARK: - Appearance -- 稳定态
    public func applyStyle(animated: Bool) {

        let bgColor = KBSystemKeyStyle.backgroundColor(
            role: keyRole,
            state: visualState,
            darkMode: isDarkMode
        ).cgColor

        let changes = {
            self.backgroundColor = bgColor
            self.shadowOpacity = KBSystemKeyStyle.shadowOpacity(darkMode: self.isDarkMode)
            self.shadowRadius = KBSystemKeyStyle.shadowRadius()
            self.shadowOffset = KBSystemKeyStyle.shadowOffset()
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

private extension KBBaseKeyLayer {
    func commonInit() {
        masksToBounds = false
        contentsScale = UIScreen.main.scale

        setupSublayers()
    }

    func apply(config: KBKeyLayerConfig) {
        cornerRadius = config.cornerRadius
        self.masksToBounds = false

        // outer shadow for elevation
        self.shadowColor = config.shadowColor.cgColor
    }

    func setupSublayers() {
        
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
}
