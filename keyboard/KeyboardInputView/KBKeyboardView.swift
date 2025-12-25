//
//  KBKeyboardView.swift
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
 2. 字幕键盘的长按 pop
 */

// 句首状态机
enum AutoCapContext {
    case none
    case afterPunctuation
}

class KBKeyboardView: UIView {
    weak open var keyboardDelegate: KeyboardViewProtocol?
    
    // Layout provider
    private var layoutEngine: KBKeyLayoutEngine!
    // Runtime storage
    private var rows: [KBKeyRow] = []
    private var keysFlat: [KBKey] = []
    private var keyLayers: [String: KBBaseKeyLayer] = [:]       // id -> key layer

    // Touch state
    private var activeKeyID: String? = nil
    /////////////////////////////////////////////////////////////////////
    // injected presenter for long-press alternatives
    private lazy var popupPresenter = DefaultPopupPresenter()
    private lazy var popupStateMachine = KBPopupGestureStateMachine(driver: popupPresenter)
    /////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////////////
    // 键盘状态
    public var enableClickSound: Bool = true
    private var keyboardType: KeyboardType = .letters
    // 记录屏幕尺寸变化
    private var lastLayoutSize: CGSize = .zero
    private var needsRelayout = true
    // 是否需要恢复字母布局
    private var shouldRestoreLettersOnAppear = false
    /////////////////////////////////////////////////////////////////////
    
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
        guard superview != nil, newSize.width > 0, newSize.height > 0 else { return }
        // 尺寸没变 + 没被标记 → 不重排
        if newSize == lastLayoutSize, !needsRelayout {
            return
        }

        lastLayoutSize = newSize
        needsRelayout = false

        updateLayoutEngineSize()
        reloadLayout()
    }
    
    // MARK: - 键盘生命周期性方法
    public func keyboardDidAppear() {
        // 🔥 关键 1：恢复字母键盘
        if shouldRestoreLettersOnAppear {
            keyboardType = .letters
            reloadLayout()
            shouldRestoreLettersOnAppear = false
        }
        // 🔥 关键 2：应用系统级单次大写
        applyInitialShiftStateIfNeeded()
    }
    
    public func keyboardDidDisappear() {
        // 1. Shift 语义重置
        autoCapContext = .none
        lastShiftTapTime = 0
        shiftState = .lowercase

        // 2. Layout 语义重置标记
        if keyboardType != .letters {
            shouldRestoreLettersOnAppear = true
        }
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
        guard let p = touches.first?.location(in: self), let id = keyId(at: p), let key = keysFlat.first(where: { $0.keyId == id }) else {
            return
        }
        
        activeKeyID = id
        shiftDidLongPress = false
        
        // press visual
        if let _key_layer = keyLayers[id] {
            // 交互序列 ++
            interactionSequence += 1
            _key_layer.animateKeyPressDown()
            _key_layer.currentInteractionSeq = interactionSequence
        }

        if key.keyType == .shift {
            shiftLongPressTimer?.invalidate()
            shiftLongPressTimer = Timer.scheduledTimer(
                withTimeInterval: shiftLongPressDuration,
                repeats: false
            ) { [weak self] _ in
                guard let self else { return }

                self.shiftDidLongPress = true          // ✅ 必须
                self.shiftState = .locked
                self.updateShiftKeyUI(animated: true)
                KBKeyboardHapticEngine.shared.trigger(for: .capsLock)
            }
        }
        
        if key.keyType == .character {
            // 创建 KBPopupSession 时，contentWidth 怎么给？
            let session = KBPopupSession(
                key: key,
                keyRect: key.frame,
                position: key.keyLocation,
                parantView: self,
                baseRect: bounds,
                safeAreaInsets: safeAreaInsets,
                traitCollection: self.traitCollection
            )

            popupStateMachine.touchBegan(
                at: p,
                session: session
            )
        }

        if enableClickSound {
            let role = feedbackRole(for: id)
            KBKeyboardFeedbackEngine.shared.trigger(for: role)
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else {
            return
        }
        // pop 状态机执行
        popupStateMachine.touchMoved(to: p)
        
        // shift 长按手指移出
        if let active = activeKeyID,
           let activeKey = keysFlat.first(where: { $0.keyId == active }),
           activeKey.keyType == .shift {

            if keyId(at: p) != active {
                // 手指离开 shift
                shiftLongPressTimer?.invalidate()
                shiftLongPressTimer = nil
            }
        }

        // 普通滑动换键，只在 popup idle 时执行
        guard popupStateMachine.state == .idle else {
            return
        }

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

        shiftLongPressTimer?.invalidate()
        shiftLongPressTimer = nil
        
        guard let p = touches.first?.location(in: self) else {
            cleanupTouch()
            return
        }
        
        // popup 状态机
        popupStateMachine.touchEnded(at: p)

        if shiftDidLongPress {
            lastShiftTapTime = 0
            shiftDidLongPress = false
            cleanupTouch()
            return
        }
        
        // popup 仍在活跃状态，则不再执行普通点击
        guard popupStateMachine.state == .idle else {
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
        
        shiftLongPressTimer?.invalidate()
        shiftLongPressTimer = nil
        
        // pop 状态机执行取消
        popupStateMachine.touchCancelled()
        
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
private extension KBKeyboardView {
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
        guard let shiftLayer = keyLayers["shift"] as? KBShiftKeyLayer else {
            return
        }
        shiftLayer.shiftState = shiftState
        // 更新字母按键文字
        updateCharacterKeysCase()
    }
    
    func updateCharacterKeysCase() {
        for key in keysFlat where key.keyType == .character {
            guard let layer = keyLayers[key.keyId] as? KBCharacterKeyLayer else {
                continue
            }

            let displayText: String
            switch shiftState {
            case .lowercase:
                displayText = key.keyLabel.lowercased()
            case .uppercase, .locked:
                displayText = key.keyLabel.uppercased()
            }

            layer.updateDisplayedText(displayText)
        }
    }
    
    func handleShiftTap(currentTime: TimeInterval = CACurrentMediaTime()) {

        switch shiftState {

        case .lowercase:
            // 单击 → 单次大写
            shiftState = .uppercase
            lastShiftTapTime = currentTime

        case .uppercase:
            // 判断是否是双击
            if currentTime - lastShiftTapTime <= shiftDoubleTapInterval {
                // 双击 → Caps Lock
                shiftState = .locked
            } else {
                // 单击 → 回小写（✅ 关键）
                shiftState = .lowercase
            }
            lastShiftTapTime = currentTime

        case .locked:
            // 再点一次 → 关闭 Caps Lock
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

private extension KBKeyboardView {
    func commonInit() {
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = false
        self.layoutEngine = KBKeyLayoutEngine(keyboardWidth: bounds.width, keyboardHeight: bounds.height, rowHeight: 52, keySpacing: 6, sidePadding: 6, topPadding: 8, bottomPadding: 8, maxKeyWidth: 120, provider: KBDefaultKeyboardProvider() as KeyboardLayoutProviding)
        
        popupPresenter.selectedCallback = {[weak self](text: String?) in
            if let _t = text {
                self?.commitPopupText(_t)
            }
        }
    }
    
    func applyInitialShiftStateIfNeeded() {
        // 系统行为：首次进入字母键盘 = 单次大写
        shiftState = .uppercase
        updateShiftKeyUI(animated: false)
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

// MARK: - Popup
private extension KBKeyboardView {
    func commitPopupText(_ text: String) {
        // 1. 提交文本（不走 performKeyAction）
        commitText(text)

        // 2. popup 模式下，处理 shift 语义
        if shiftState == .uppercase {
            shiftState = .lowercase
            updateShiftKeyUI(animated: true)
        }

        // 3. 强制结束本轮触摸（🔥关键）
        finishActiveKeyInteraction()
    }
    
    func finishActiveKeyInteraction() {

        // 1️⃣ 恢复当前 key 的视觉状态
        if let id = activeKeyID,
           let layer = keyLayers[id] {

            layer.animatePressUp {
                layer.setVisualState(.normal, animated: true)
            }
        }

        // 2️⃣ 清理触摸状态
        activeKeyID = nil
        shiftDidLongPress = false

        // 3️⃣ 终止 popup
        popupPresenter.hide()
    }
}

// MARK: - Key feedback
private extension KBKeyboardView {
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
