//
//  KBKeyboardViewFull.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/8.
//
// KeyboardViewFull.swift
// 完整实现：系统键盘风格按键（layer 驱动） + 按下缩放动画 + UITextDocumentProxy 支持

import UIKit
import AudioToolbox

class KBKeyboardViewFull: UIView {
    weak open var keyboardDelegate: KeyboardViewProtocol?
    // Public injection points
    public weak var documentProxy: UITextDocumentProxy?    // set by input extension's view controller
    var popupPresenter: DefaultPopupPresenter?            // injected presenter for long-press alternatives

    // Layout provider
    private var layoutEngine: KBKeyLayoutEngine!

    // Appearance
    public var cornerRadius: CGFloat = 8
    public var keyBackgroundColor: UIColor = UIColor(white: 0.98, alpha: 1)
    public var keyTextColor: UIColor = .label
    public var keyFont: UIFont = .systemFont(ofSize: 18)

    // Runtime storage
    private var rows: [KBKeyRow] = []
    private var keysFlat: [KBKey] = []
    private var keyLayers: [String: CALayer] = [:]       // id -> key layer
    private var textLayers: [String: CATextLayer] = [:]  // id -> text layer

    // Touch state
    private var activeKeyID: String? = nil
    private var longPressTimer: Timer?
    private var isLongPressActive = false

    // Haptics & sound
    private let selectionHaptic = UISelectionFeedbackGenerator()
    private let impactHaptic = UIImpactFeedbackGenerator(style: .light)
    public var enableClickSound: Bool = true
    private var keyboardType: KeyboardType = .letters
    
    // MARK: - Init
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        self.layoutEngine = KBKeyLayoutEngine(keyboardWidth: bounds.width, keyboardHeight: bounds.height, rowHeight: 52, keySpacing: 6, sidePadding: 6, topPadding: 8, bottomPadding: 8, maxKeyWidth: 120, provider: KBDefaultKeyboardProvider() as KeyboardLayoutProviding)
        commonInit()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func commonInit() {
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = false
        popupPresenter?.selectedCallback = {[weak self](text: String?) in
            self?.keyboardDelegate?.didSelectedKeyCap(capText: text ?? "")
        }
    }

    // MARK: - Layout
    public override func layoutSubviews() {
        super.layoutSubviews()
        reloadLayout()
    }

    public func reloadLayout() {
        guard layoutEngine != nil else { return }
        rows = layoutEngine.layout(for: self.keyboardType)
        keysFlat = rows.flatMap { $0.keys }
        syncLayersWithKeys()
    }

    // Sync layers: create if missing, update frames and text
    private func syncLayersWithKeys() {
        let existingIds = Set(keyLayers.keys)
        let targetIds = Set(keysFlat.map { $0.keyId })

        // remove obsolete
        for id in existingIds.subtracting(targetIds) {
            keyLayers[id]?.removeFromSuperlayer()
            keyLayers.removeValue(forKey: id)
            textLayers[id]?.removeFromSuperlayer()
            textLayers.removeValue(forKey: id)
        }

        for key in keysFlat {
            let id = key.keyId
            let layer: CALayer
            if let l = keyLayers[id] {
                layer = l
            } else {
                layer = createKeyLayer()
                keyLayers[id] = layer
                self.layer.addSublayer(layer)
            }

            // update frame without implicit animations
            CATransaction.begin(); CATransaction.setDisableActions(true)
            layer.frame = key.frame
            layer.cornerRadius = cornerRadius
            // update sublayer frames
            for case let g as CAGradientLayer in (layer.sublayers ?? []) where g.name == "highlight" {
                g.frame = layer.bounds
            }
            if let sep = layer.sublayers?.first(where: { $0.name == "separator" }) {
                let scale = UIScreen.main.scale
                sep.frame = CGRect(x: 0, y: layer.bounds.height - 1.0/scale, width: layer.bounds.width, height: 1.0/scale)
            }
            CATransaction.commit()

            // text layer
            if textLayers[id] == nil {
                let t = CATextLayer()
                t.contentsScale = UIScreen.main.scale
                t.alignmentMode = .center
                t.isWrapped = false
                t.truncationMode = .end
                t.foregroundColor = keyTextColor.cgColor
                t.font = keyFont
                t.fontSize = keyFont.pointSize
                t.isWrapped = false
                layer.addSublayer(t)
                textLayers[id] = t
            }
            if let t = textLayers[id] {
                CATransaction.begin(); CATransaction.setDisableActions(true)
                t.string = key.keyLabel as NSString
                let size = (key.keyLabel as NSString).size(withAttributes: [.font: keyFont])
                t.frame = CGRect(x: 0, y: (layer.bounds.height - size.height)/2 - 1, width: layer.bounds.width, height: size.height)
                CATransaction.commit()
            }
        }
    }

    // Create a layer that looks like a system keycap (rounded, inner highlight, bottom separator)
    private func createKeyLayer() -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = keyBackgroundColor.cgColor
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = false

        // outer shadow for elevation
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 3)

        // top highlight gradient (inner light)
        let grad = CAGradientLayer()
        grad.name = "highlight"
        grad.colors = [UIColor(white: 1.0, alpha: 0.18).cgColor, UIColor(white: 1.0, alpha: 0.02).cgColor]
        grad.startPoint = CGPoint(x: 0.5, y: 0)
        grad.endPoint = CGPoint(x: 0.5, y: 1)
        grad.frame = layer.bounds
        grad.cornerRadius = cornerRadius
        layer.addSublayer(grad)

        // subtle bottom shade
        let bottomShade = CAGradientLayer()
        bottomShade.name = "bottomShade"
        bottomShade.colors = [UIColor.clear.cgColor, UIColor(white: 0, alpha: 0.06).cgColor]
        bottomShade.startPoint = CGPoint(x: 0.5, y: 0)
        bottomShade.endPoint = CGPoint(x: 0.5, y: 1)
        bottomShade.frame = layer.bounds
        bottomShade.cornerRadius = cornerRadius
        layer.addSublayer(bottomShade)

        // separator
        let sep = CALayer()
        sep.name = "separator"
        sep.backgroundColor = UIColor(white: 0.78, alpha: 1).cgColor
        let scale = UIScreen.main.scale
        sep.frame = CGRect(x: 0, y: layer.bounds.height - 1.0/scale, width: layer.bounds.width, height: 1.0/scale)
        layer.addSublayer(sep)

        // performance hint
        layer.shouldRasterize = false
        layer.rasterizationScale = UIScreen.main.scale

        return layer
    }

    // MARK: - Touch handling & animations
    private func keyId(at point: CGPoint) -> String? {
        return keysFlat.first { $0.frame.contains(point) }?.keyId
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self), let id = keyId(at: p) else { return }
        activeKeyID = id
        isLongPressActive = false

        // press visual
        animatePressDown(keyID: id)

        // prepare haptics
        selectionHaptic.prepare()
        impactHaptic.prepare()

        // schedule long press
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false, block: { [weak self] _ in
            guard let self = self, let id = self.activeKeyID else { return }
            guard let key = self.keysFlat.first(where: { $0.keyId == id }), key.alternatives?.isEmpty == false else { return }
            self.isLongPressActive = true
            // show popup (popupPresenter is responsible for adding itself to the view)
            self.popupPresenter?.show(for: key, from: key.frame, in: self)
        })

        if enableClickSound { AudioServicesPlaySystemSound(1104) }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else { return }
        if isLongPressActive {
            // route to popup for selection
            popupPresenter?.update(at: p)
            return
        }

        // update active key when sliding
        if let id = keyId(at: p) {
            if id != activeKeyID {
                // previous key release visual
                if let prev = activeKeyID { animatePressUp(keyID: prev) }
                activeKeyID = id
                animatePressDown(keyID: id)
                selectionHaptic.selectionChanged()
                if enableClickSound { AudioServicesPlaySystemSound(1104) }
            }
        } else {
            // left keys area
            if let prev = activeKeyID { animatePressUp(keyID: prev) }
            activeKeyID = nil
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate()
        longPressTimer = nil

        guard let p = touches.first?.location(in: self) else { cleanupTouch(); return }

        if isLongPressActive {
            popupPresenter?.commit()
            popupPresenter?.hide()
            isLongPressActive = false
            cleanupTouch()
            return
        }

        // normal tap
        if let id = keyId(at: p), let key = keysFlat.first(where: { $0.keyId == id }) {
            // visual release
            animatePressUp(keyID: id)
            performKeyAction(key)
            self.keyboardDelegate?.didSelectedKeyCap(capText: key.keyLabel)
        } else if let prev = activeKeyID {
            animatePressUp(keyID: prev)
        }

        cleanupTouch()
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate()
        longPressTimer = nil
        if isLongPressActive { popupPresenter?.hide(); isLongPressActive = false }
        if let id = activeKeyID { animatePressUp(keyID: id) }
        cleanupTouch()
    }

    private func cleanupTouch() {
        activeKeyID = nil
        selectionHaptic.prepare() // keep generator ready
    }

    // MARK: - Animations (press down / up)
    private func animatePressDown(keyID: String) {
        guard let layer = keyLayers[keyID] else { return }
        // immediate transform with UIView animation for spring-friendly behavior on release
        UIView.animate(withDuration: 0.06, delay: 0, options: [.beginFromCurrentState], animations: {
            layer.setAffineTransform(CGAffineTransform(scaleX: 0.96, y: 0.96))
            layer.shadowOffset = CGSize(width: 0, height: 1)
            layer.shadowRadius = 3
            layer.shadowOpacity = 0.22
        })

        // intensify highlight via opacity change
        if let grad = layer.sublayers?.first(where: { $0.name == "highlight" }) as? CAGradientLayer {
            let anim = CABasicAnimation(keyPath: "opacity")
            anim.fromValue = grad.opacity
            anim.toValue = 1.0
            anim.duration = 0.12
            grad.opacity = 1.0
            grad.add(anim, forKey: "highlightIn")
        }
    }

    private func animatePressUp(keyID: String, completion: (() -> Void)? = nil) {
        guard let layer = keyLayers[keyID] else { completion?(); return }

        UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 8, options: [.allowUserInteraction], animations: {
            layer.setAffineTransform(.identity)
            layer.shadowOffset = CGSize(width: 0, height: 3)
            layer.shadowRadius = 6
            layer.shadowOpacity = 0.18
        }, completion: { _ in
            // restore highlight
            if let grad = layer.sublayers?.first(where: { $0.name == "highlight" }) as? CAGradientLayer {
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

    // MARK: - Key actions
    private func performKeyAction(_ key: KBKey) {
        switch key.keyType {
        case .character:
            commitText(key.keyLabel)
        case .backspace:
            deleteBackward()
        case .space:
            commitText(" ")
        case .returnKey:
            commitText("\n")
        case .shift:
            // leave to host to implement casing
            break
        case .special:
            // switching layouts (assume id == "numbers" or id == "123")
            if key.keyId == "numbers" || key.keyLabel == "123" {
                self.keyboardType = .numbers
                reloadLayout()
            } else if key.keyId == "#=" || key.keyLabel == "#+=" {
                self.keyboardType = .symbols
                reloadLayout()
            } else if key.keyId == "ABC" {
                self.keyboardType = .letters
                reloadLayout()
            }
        }
    }

    private func commitText(_ text: String) {
        if let proxy = documentProxy {
            proxy.insertText(text)
        } else {
            // fallback: inform delegate via Notification or other mechanism — here we play click
            // For demo purposes we'll play click and do nothing else
            if enableClickSound { AudioServicesPlaySystemSound(1104) }
        }
    }

    private func deleteBackward() {
        if let proxy = documentProxy {
            proxy.deleteBackward()
        } else {
            if enableClickSound { AudioServicesPlaySystemSound(1104) }
        }
    }
}
