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
    var popupPresenter: DefaultPopupPresenter?            // injected presenter for long-press alternatives
    
    // Layout provider
    private var layoutEngine: KBKeyLayoutEngine!

    // Appearance
    public var cornerRadius: CGFloat = 8
    public var keyBackgroundColor: UIColor = UIColor(white: 0.98, alpha: 1)

    // Runtime storage
    private var rows: [KBKeyRow] = []
    private var keysFlat: [KBKey] = []
    private var keyLayers: [String: KBBaseKeyLayer] = [:]       // id -> key layer

    // Touch state
    private var activeKeyID: String? = nil
    private var longPressTimer: Timer?
    private var isLongPressActive = false

    // Haptics & sound
    private let selectionHaptic = UISelectionFeedbackGenerator()
    private let impactHaptic = UIImpactFeedbackGenerator(style: .light)
    public var enableClickSound: Bool = true
    private var keyboardType: KeyboardType = .letters
    // 记录屏幕尺寸变化
    private var lastLayoutSize: CGSize = .zero
    private var needsRelayout = true
    
    // MARK: - Init
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Layout
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass ||
              traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass
        else { return }

        // ❗️只标记，不 reload
        needsRelayout = true
        setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        let newSize = bounds.size
        guard newSize.width > 0, newSize.height > 0 else { return }

        // 尺寸没变 + 没被标记 → 不重排
        if newSize == lastLayoutSize, !needsRelayout {
            return
        }

        lastLayoutSize = newSize
        needsRelayout = false

        updateLayoutEngineSize()
        reloadLayout()
    }

    public func reloadLayout() {
        guard layoutEngine != nil else {
            return
        }
        rows = layoutEngine.layout(for: self.keyboardType)
        keysFlat = rows.flatMap { $0.keys }
        syncLayersWithKeys()
    }

    // MARK: - Touch handling & animations
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self), let id = keyId(at: p) else { return }
        activeKeyID = id
        isLongPressActive = false

        // press visual
        if let _key_layer = keyLayers[id] {
            _key_layer.animateKeyPressDown()
        }

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

        if enableClickSound {
            AudioServicesPlaySystemSound(1104)
        }
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
                if let prev = activeKeyID, let _pre_key_layer = keyLayers[prev] {
                    _pre_key_layer.animatePressUp()
                }
                activeKeyID = id
                
                if let _key_layer = keyLayers[id] {
                    _key_layer.animateKeyPressDown()
                }
                
                selectionHaptic.selectionChanged()
                if enableClickSound {
                    AudioServicesPlaySystemSound(1104)
                }
            }
        } else {
            // left keys area
            if let prev = activeKeyID, let _pre_key_layer = keyLayers[prev] {
                _pre_key_layer.animatePressUp()
            }
            activeKeyID = nil
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate()
        longPressTimer = nil

        guard let p = touches.first?.location(in: self) else {
            cleanupTouch()
            return
        }

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
            if let _press_layer = keyLayers[id] {
                _press_layer.animatePressUp()
            }
            performKeyAction(key)
        } else if let prev = activeKeyID, let _pre_key_layer = keyLayers[prev] {
            _pre_key_layer.animatePressUp()
        }

        cleanupTouch()
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate()
        longPressTimer = nil
        if isLongPressActive { popupPresenter?.hide(); isLongPressActive = false }
        if let id = activeKeyID, let _active_key_layer = keyLayers[id] {
            _active_key_layer.animatePressUp()
        }
        cleanupTouch()
    }
}

// MARK: - Key actions
private extension KBKeyboardViewFull {
    func performKeyAction(_ key: KBKey) {
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

    func commitText(_ text: String) {
        self.keyboardDelegate?.didSelectedKeyCap(capText: text)
    }

    func deleteBackward() {
        self.keyboardDelegate?.deleteText()
    }
}

private extension KBKeyboardViewFull {
    func commonInit() {
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = false
        self.layoutEngine = KBKeyLayoutEngine(keyboardWidth: bounds.width, keyboardHeight: bounds.height, rowHeight: 52, keySpacing: 6, sidePadding: 6, topPadding: 8, bottomPadding: 8, maxKeyWidth: 120, provider: KBDefaultKeyboardProvider() as KeyboardLayoutProviding)
        
        popupPresenter?.selectedCallback = {[weak self](text: String?) in
            self?.keyboardDelegate?.didSelectedKeyCap(capText: text ?? "")
        }
    }
    
    // Sync layers: create if missing, update frames and text
    func syncLayersWithKeys() {
        let existingIds = Set(keyLayers.keys)
        let targetIds = Set(keysFlat.map { $0.keyId })

        // remove obsolete
        for id in existingIds.subtracting(targetIds) {
            keyLayers[id]?.clearTextLayer()
            keyLayers[id]?.removeFromSuperlayer()
            keyLayers.removeValue(forKey: id)
        }

        for key in keysFlat {
            let id = key.keyId
            var layer: KBBaseKeyLayer
            let config = KBKeyLayerConfig.init(cornerRadius: cornerRadius)
            if let l = keyLayers[id] {
                layer = l
            } else {
                if key.keyType == .backspace {
                    layer = KBDeleteKeyLayer(config: config)
                    layer.keyRole = .function
                } else if key.keyType == .shift {
                    layer = KBShiftKeyLayer(config: config)
                    layer.keyRole = .function
                } else {
                    layer = KBCharacterKeyLayer(config: config)
                }
                
                layer.traitCollection = self.traitCollection
                layer.visualState = .normal
                keyLayers[id] = layer
                self.layer.addSublayer(layer)
            }

            // update frame without implicit animations
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.frame = key.frame
            CATransaction.commit()
            
            if key.keyType != .backspace && key.keyType != .shift {
                let textLayerConfig = KBKeyTextLayerConfig()
                layer.createTextLayerIfNeeded(textLayerConfig: textLayerConfig)
                layer.updateTextLayer(key: key, config: textLayerConfig)
            }
        }
    }
    
    func keyId(at point: CGPoint) -> String? {
        return keysFlat.first { $0.frame.contains(point) }?.keyId
    }
    
    func cleanupTouch() {
        activeKeyID = nil
        selectionHaptic.prepare() // keep generator ready
    }

    func updateLayoutEngineSize() {
        layoutEngine.keyboardWidth = bounds.width
        layoutEngine.keyboardHeight = bounds.height

        // 🔥 关键：传 safeArea
        layoutEngine.safeAreaInsets = self.safeAreaInsets
        if traitCollection.userInterfaceIdiom == .pad {
            layoutEngine.maxKeyWidth = bounds.width > bounds.height ? 56 : 64
        } else {
            layoutEngine.maxKeyWidth = nil
        }
    }
}
