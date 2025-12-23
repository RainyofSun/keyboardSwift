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

/*
 TODO:
 1. 键盘退下。再次唤醒时，切回至字幕键盘
 2. 字幕键盘的长按 pop
 */

// 句首状态机
enum AutoCapContext {
    case none
    case afterPunctuation
}

class KBKeyboardViewFull: UIView {
    weak open var keyboardDelegate: KeyboardViewProtocol?
    // Public injection points
    var popupPresenter: DefaultPopupPresenter?            // injected presenter for long-press alternatives
    
    // Layout provider
    private var layoutEngine: KBKeyLayoutEngine!
    // Runtime storage
    private var rows: [KBKeyRow] = []
    private var keysFlat: [KBKey] = []
    private var keyLayers: [String: KBBaseKeyLayer] = [:]       // id -> key layer

    // Touch state
    private var activeKeyID: String? = nil
    /////////////////////////////////////////////////////////////////////
    // 长按 popUp
    private var longPressTimer: Timer?
    private var isLongPressActive = false
    private let characterLongPressDuration: TimeInterval = 0.45
    /////////////////////////////////////////////////////////////////////

    public var enableClickSound: Bool = true
    private var keyboardType: KeyboardType = .letters
    // 记录屏幕尺寸变化
    private var lastLayoutSize: CGSize = .zero
    private var needsRelayout = true
    // 当前活跃 key 的交互序列
    private var interactionSequence: Int = 0
    
    /////////////////////////////////////////////////////////////////////
    // shift 键状态机
    /*
    lowercase
       │ 单击
       ▼
    uppercase (临时)
       │ 输入字符 → 自动回 lowercase
       │
       │ 双击（在时间窗口内）
       ▼
    locked (Caps Lock)
       │ 再点一次
       ▼
    lowercase
    */
    private var shiftState: ShiftState = .lowercase
    private var lastShiftTapTime: CFTimeInterval = 0
    private let shiftDoubleTapInterval: CFTimeInterval = 0.28
    private var shiftLongPressTimer: Timer?
    private let shiftLongPressDuration: TimeInterval = 0.32
    private var autoCapContext: AutoCapContext = .none
    /*
     长按优先级 > 单击
     •    一旦触发 long press
     •    touchesEnded 不再走单击 shift
     */
    private var shiftDidLongPress = false
    /////////////////////////////////////////////////////////////////////
    
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
        shiftDidLongPress = false
        
        // press visual
        if let _key_layer = keyLayers[id] {
            // 交互序列 ++
            interactionSequence += 1
            _key_layer.animateKeyPressDown()
            _key_layer.currentInteractionSeq = interactionSequence
        }

        if let _key = self.keysFlat.first(where: { $0.keyId == id }), _key.keyType == .shift {

            shiftLongPressTimer = Timer.scheduledTimer(
                withTimeInterval: shiftLongPressDuration,
                repeats: false
            ) { [weak self] _ in
                guard let self else { return }

                self.shiftDidLongPress = true          // ✅ 必须
                self.shiftState = .locked
                self.longPressTimer?.invalidate()
                self.longPressTimer = nil
                self.updateShiftKeyUI(animated: true)
                KBKeyboardHapticEngine.shared.trigger(for: .capsLock)
            }
        }
        
        // schedule long press
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(
            withTimeInterval: characterLongPressDuration,
            repeats: false
        ) { [weak self] _ in
            guard let self = self else { return }
            guard !self.shiftDidLongPress else { return }   // ✅ 关键熔断
            guard let id = self.activeKeyID else { return }
            guard let key = self.keysFlat.first(where: { $0.keyId == id }),
                  key.alternatives?.isEmpty == false else { return }

            self.isLongPressActive = true
            self.popupPresenter?.show(for: key, from: key.frame, in: self)
        }

        if enableClickSound {
            let role = feedbackRole(for: id)
            KBKeyboardFeedbackEngine.shared.trigger(for: role)
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else { return }
        if let active = activeKeyID,
           let activeKey = keysFlat.first(where: { $0.keyId == active }),
           activeKey.keyType == .shift {

            if keyId(at: p) != active {
                // 手指离开 shift
                shiftLongPressTimer?.invalidate()
                shiftLongPressTimer = nil
            }
        }
        
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
                    _pre_key_layer.animatePressUp {
                        // 仅恢复当前活跃的 key 的稳定态
                        guard _pre_key_layer.currentInteractionSeq == self.interactionSequence else {
                            return
                        }
                        
                        // 动画结束， 按键恢复至稳定态
                        _pre_key_layer.setVisualState(KBKeyVisualState.normal, animated: true)
                    }
                }
                activeKeyID = id
                
                if let _key_layer = keyLayers[id] {
                    _key_layer.animateKeyPressDown()
                }
                
                KBKeyboardFeedbackEngine.shared.triggerSlide()
            }
        } else {
            // left keys area
            if let prev = activeKeyID, let _pre_key_layer = keyLayers[prev] {
                _pre_key_layer.animatePressUp {
                    // 仅恢复当前活跃的 key 的稳定态
                    guard _pre_key_layer.currentInteractionSeq == self.interactionSequence else {
                        return
                    }
                    
                    // 动画结束， 按键恢复至稳定态
                    _pre_key_layer.setVisualState(KBKeyVisualState.normal, animated: true)
                }
            }
            activeKeyID = nil
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate()
        longPressTimer = nil

        shiftLongPressTimer?.invalidate()
        shiftLongPressTimer = nil
        
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

        if shiftDidLongPress {
            lastShiftTapTime = 0
            cleanupTouch()
            return
        }
        
        // normal tap
        if let id = keyId(at: p), let key = keysFlat.first(where: { $0.keyId == id }) {
            // visual release
            if let _press_layer = keyLayers[id] {
                _press_layer.animatePressUp {
                    // 仅恢复当前活跃的 key 的稳定态
                    guard _press_layer.currentInteractionSeq == self.interactionSequence else {
                        return
                    }
                    
                    // 动画结束， 按键恢复至稳定态
                    _press_layer.setVisualState(KBKeyVisualState.normal, animated: true)
                }
            }
            performKeyAction(key)
        } else if let prev = activeKeyID, let _pre_key_layer = keyLayers[prev] {
            _pre_key_layer.animatePressUp {
                // 仅恢复当前活跃的 key 的稳定态
                guard _pre_key_layer.currentInteractionSeq == self.interactionSequence else {
                    return
                }
                
                // 动画结束， 按键恢复至稳定态
                _pre_key_layer.setVisualState(KBKeyVisualState.normal, animated: true)
            }
        }

        cleanupTouch()
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate()
        longPressTimer = nil
        
        shiftLongPressTimer?.invalidate()
        shiftLongPressTimer = nil
        
        if isLongPressActive { popupPresenter?.hide(); isLongPressActive = false }
        if let id = activeKeyID, let _active_key_layer = keyLayers[id] {
            _active_key_layer.animatePressUp {
                // 仅恢复当前活跃的 key 的稳定态
                guard _active_key_layer.currentInteractionSeq == self.interactionSequence else {
                    return
                }
                
                // 动画结束， 按键恢复至稳定态
                _active_key_layer.setVisualState(KBKeyVisualState.normal, animated: true)
            }
        }
        cleanupTouch()
    }
}

// MARK: - Key actions
private extension KBKeyboardViewFull {
    func performKeyAction(_ key: KBKey) {
        switch key.keyType {
        case .character where ".!?".contains(key.keyLabel):
            commitText(key.keyLabel)
            if shiftState != .locked {
                autoCapContext = .afterPunctuation
            }
            
        case .character:
            let output = transformedCharacter(key.keyLabel)
            self.commitText(output)
            // 单词大写在输入后自动回到 lowercase
            if shiftState == .uppercase {
                shiftState = .lowercase
                updateShiftKeyUI(animated: true)
                autoCapContext = .none
            }
        case .backspace:
            deleteBackward()
        case .space:
            commitText(" ")

            if autoCapContext == .afterPunctuation,
               shiftState == .lowercase {
                shiftState = .uppercase
                updateShiftKeyUI(animated: true)
            }

            autoCapContext = .none
        case .returnKey:
            commitText("\n")
            // return 后系统也会取消一次性大写
            if shiftState == .uppercase {
                shiftState = .lowercase
                updateShiftKeyUI(animated: true)
            }
        case .shift:
            handleShiftTap()
            updateShiftKeyUI(animated: true)
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
    
    func transformedCharacter(_ raw: String) -> String {
        switch shiftState {
        case .lowercase:
            return raw.lowercased()
        case .uppercase, .locked:
            return raw.uppercased()
        }
    }
    
    func updateShiftKeyUI(animated: Bool) {
        guard let shiftLayer = keyLayers["shift"] as? KBShiftKeyLayer else { return }
        shiftLayer.shiftState = shiftState
    }
    
    func handleShiftTap(currentTime: TimeInterval = CACurrentMediaTime()) {

        switch shiftState {

        case .lowercase:
            // 第一次点击
            shiftState = .uppercase
            lastShiftTapTime = currentTime

        case .uppercase:
            // 判断是否是双击
            if currentTime - lastShiftTapTime <= shiftDoubleTapInterval {
                shiftState = .locked
            } else {
                // 超时 → 视为重新开始
                shiftState = .uppercase
            }
            lastShiftTapTime = currentTime

        case .locked:
            // Caps Lock 下再点一次 → 关闭
            shiftState = .lowercase
            lastShiftTapTime = 0
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
            let config = KBKeyLayerConfig()
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
                layer.setVisualState(KBKeyVisualState.normal, animated: false)
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

// MARK: - Key feedback
private extension KBKeyboardViewFull {
    func feedbackRole(for keyId: String) -> KeyFeedbackRole {
        guard let key = keysFlat.first(where: { $0.keyId == keyId }) else {
            return .character
        }

        switch key.keyType {
        case .character:
            return key.keyLabel == " " ? .space : .character
        case .backspace:
            return .delete
        case .shift, .returnKey, .special:
            return .function
        case .space:
            return .space
        }
    }
}
