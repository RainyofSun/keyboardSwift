//
//  KBKeyboardView.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/8.
//
// KeyboardViewFull.swift
// 完整实现：系统键盘风格按键（layer 驱动） + 按下缩放动画

import UIKit
import AudioToolbox

/*
 TODO:
 1. popup 弹窗
 */
// 句首状态机
enum AutoCapContext {
    case none
    case afterPunctuation
}
/*
 KBKeyboardView
 ├─ keyContainerView          // 按键（可响应事件）
 │
 ├─ popupContainerView        // 🔥 所有 popup 的舞台（不响应事件）
 │   ├─ candidateLayer        // 候选词 popup
 │   ├─ emojiLayer            // emoji popup
 │   ├─ menuLayer             // 菜单 / 工具 popup
 │
 └─ overlayContainerView      // debug / guide / 可视化层
 
 调用链路:
 touch
  ↓
 popupStateMachine
  ↓
 popupPresenter
  ↓
 popupLayoutIntentDelegate (KBKeyboardView)
  ↓
 keyboardLayoutEngine.updatePresentation(...)
  ↓
 keyboardHeightDidChange
  ↓
 contentHeight → intrinsicContentSize
 */
class KBKeyboardView: UIView {
    weak open var keyboardDelegate: KeyboardViewProtocol?
    
    let keyContainerView = KBKeyContainerView()
    let popupContainerView = KBPopupContainerView()
    let debugOverlayContainerView = KBDebugOverlayContainerView()
    
    // Layout provider
    private var layoutEngine: KBKeyLayoutEngine!
    // Runtime storage
    private var rows: [KBKeyRow] = []
    private var keysFlat: [KBKey] = []

    /////////////////////////////////////////////////////////////////////
    // 键盘自身高度变化
    private let keyboardLayoutEngine = KBKeyboardLayoutEngine()

    private var contentHeight: CGFloat = 0 {
        didSet {
            invalidateIntrinsicContentSize()
            animateHeightChangeIfNeeded()
        }
    }
    private var isPopupExtended = false
    /////////////////////////////////////////////////////////////////////
    
    /////////////////////////////////////////////////////////////////////
    // injected presenter for long-press alternatives
    private lazy var popupPresenter = DefaultPopupPresenter(popupContainerView: popupContainerView)
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
    private var autoCapContext: AutoCapContext = .none
    /////////////////////////////////////////////////////////////////////
    
    // MARK: - Init
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        commonInit()
        setupHierarchy()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: contentHeight + safeAreaInsets.bottom
        )
    }
    
    // MARK: - Layout
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass ||
              traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass
        else { return }
        keyboardLayoutEngine.refresh(environment: currentEnvironment(), animated: true)
        // ❗️只标记，不 reload
        needsRelayout = true
        setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if popupStateMachine.state != .idle {
            // ❗️popup 活跃时，只允许容器尺寸变化
            updateLayoutEngineSize()
            return
        }
        
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
        // 键盘环境采集
        keyboardLayoutEngine.updatePresentation(
            .normal,
            environment: currentEnvironment(),
            animated: true
        )
    }
    
    public func keyboardDidDisappear() {
        // 1. Shift 语义重置
        autoCapContext = .none
        shiftState = .lowercase
        
        // 2. Layout 语义重置标记
        if keyboardType != .letters {
            shouldRestoreLettersOnAppear = true
        }
        
        // 3. 清理旧状态
        keyContainerView.cleanup(resetShiftTap: true)
        
        // 4. 清理旧高度
        keyboardLayoutEngine.updatePresentation(
            .normal,
            environment: currentEnvironment(),
            animated: false
        )
    }
    
    func reloadLayout() {
        rows = layoutEngine.layout(for: keyboardType)
        keysFlat = rows.flatMap { $0.keys }
        keyContainerView.updateKeys(keysFlat)
    }
}

// MARK: - touch
private extension KBKeyboardView {
    func handleKeyTouchBegan(point: CGPoint, key: KBKey) {
        
        if key.keyType == .character {
            // 创建 KBPopupSession
            let session = KBPopupSession(key: key, keyRect: key.frame, position: key.keyLocation, keyboardBounds: bounds, safeAreaInsets: safeAreaInsets, traitCollection: self.traitCollection
            )

            popupStateMachine.touchBegan(at: point, session: session)
        }

        if enableClickSound {
            let role = feedbackRole(for: key)
            KBKeyboardFeedbackEngine.shared.trigger(for: role)
        }
    }
    
    func handleKeyTouchMoved(point: CGPoint, key: KBKey?) {
        // pop 状态机执行
        popupStateMachine.touchMoved(to: point)

        // 普通滑动换键，只在 popup idle 时执行
        guard popupStateMachine.state == .idle else {
            return
        }

        /*
         Idle
          └─ touch enters key A → Active(A)
         Active(A)
          ├─ move within A → Active(A)
          ├─ move to B → Release(A) → Active(B)
          ├─ move to empty → Release(A) → Idle
          └─ popup takeover → Freeze
         在 popup 未介入（idle）的前提下，根据手指移动的位置，动态维护“当前活跃 key”，并确保：
             •    同一时间只有 一个 key 处于 pressed 状态
             •    离开旧 key → 旧 key 弹起
             •    进入新 key → 新 key 按下
             •    离开键区 → 当前 key 弹起并清空
             •    所有动画都必须服从 interactionSequence，避免异步动画串台
         */
        keyContainerView.releaseKeyVisualInTouchMove(key: key) {
            KBKeyboardFeedbackEngine.shared.triggerSlide()
        }
    }
    
    func handleKeyTouchEnded(point: CGPoint, key: KBKey?) {
        // popup 状态机
        popupStateMachine.touchEnded(at: point)
        
        // popup 仍在活跃状态，则不再执行普通点击
        guard popupStateMachine.state == .idle else {
            return
        }
        
        // 在一次触摸结束时：
        // 如果手指最终停在某个 key 上 → 提交该 key；
        // 如果没有停在任何 key 上 → 只恢复视觉状态，不提交输入。
        keyContainerView.releaseKeyVisualInTouchEnd(key: key) {[weak self] (actionKey: KBKey?) in
            guard let _new_key = actionKey else {
                return
            }
            self?.performKeyAction(_new_key)
        }
    }
    
    func handleKeyTouchesCancelled() {
        // pop 状态机执行取消
        popupStateMachine.touchCancelled()
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
                keyContainerView.updateShiftKeyUI(shiftState: shiftState)
                autoCapContext = .none
            }
        case .backspace:
            deleteBackward()
        case .space:
            commitText(" ")

            if autoCapContext == .afterPunctuation,
               shiftState == .lowercase {
                shiftState = .uppercase
                keyContainerView.updateShiftKeyUI(shiftState: shiftState)
            }

            autoCapContext = .none
        case .returnKey:
            commitText("\n")
            // return 后系统也会取消一次性大写
            if shiftState == .uppercase {
                shiftState = .lowercase
                keyContainerView.updateShiftKeyUI(shiftState: shiftState)
            }
        case .shift:
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

    func commitText(_ text: String) {
        self.keyboardDelegate?.didSelectedKeyCap(capText: text)
    }

    func deleteBackward() {
        self.keyboardDelegate?.deleteText()
    }
}

extension KBKeyboardView: KBPopupDebugSink {
    func update(snapshot: KBPopupDebugSnapshot) {
        debugOverlayContainerView.updateSnapshot(snaps: snapshot)
    }
}

extension KBKeyboardView: KBShiftGestureReporting {
    func didRecognizeShiftGesture(_ gesture: ShiftGesture, shiftState state: ShiftState) {
        shiftState = state
        switch gesture {
        case .tap:
            break
        case .longPress:
            KBKeyboardHapticEngine.shared.trigger(for: .capsLock)
        case .doubleTap:
            KBKeyboardHapticEngine.shared.trigger(for: .capsLock)
        }
    }
}

extension KBKeyboardView: KBKeyboardLayoutDriving {

    func keyboardHeightDidChange(_ height: CGFloat, animated: Bool) {
        if animated {
            contentHeight = height
        } else {
            UIView.performWithoutAnimation {
                contentHeight = height
                layoutIfNeeded()
            }
        }
    }
}

extension KBKeyboardView: KBPopupLayoutIntentDelegate {    
    func popupRequiresExtendedKeyboard(_ required: Bool) {
        guard required != isPopupExtended else { return }
        isPopupExtended = required

        keyboardLayoutEngine.updatePresentation(
            required ? .withPopup : .normal,
            environment: currentEnvironment(),
            animated: true
        )
    }
}

extension KBKeyboardView: KBPopupSelectedWordDelegate {
    func didSelectedWord(word: String?) {
        if let _t = word {
            self.commitPopupText(_t)
        }
    }
}

private extension KBKeyboardView {
    func commonInit() {
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = false
        keyboardLayoutEngine.delegate = self
        
        self.layoutEngine = KBKeyLayoutEngine(keyboardWidth: bounds.width, keyboardHeight: bounds.height, rowHeight: 52, keySpacing: 6, sidePadding: 6, topPadding: 8, bottomPadding: 8, maxKeyWidth: 120, provider: KBDefaultKeyboardProvider() as KeyboardLayoutProviding)
        
        popupPresenter.debugSink = self
        popupPresenter.layoutIntentDelegate = self
        popupPresenter.wordDelegate = self
    }
    
    func setupHierarchy() {

        keyContainerView.shiftGestureDelegate = self
        
        addSubview(keyContainerView)
        addSubview(popupContainerView)
        addSubview(debugOverlayContainerView)

        keyContainerView.frame = bounds
        popupContainerView.frame = bounds
        debugOverlayContainerView.frame = bounds

        keyContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        popupContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        debugOverlayContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        debugOverlayContainerView.addPopupDebugOverlayView()
        bindKeyContainer()
    }
    
    func bindKeyContainer() {
        keyContainerView.onKeyTouchEvent = { [weak self] event in
            guard let self else { return }

            switch event {

            case .began(let point, let key):
                self.handleKeyTouchBegan(point: point, key: key)

            case .moved(let point, let key):
                self.handleKeyTouchMoved(point: point, key: key)

            case .ended(let point, let key):
                self.handleKeyTouchEnded(point: point, key: key)

            case .cancelled:
                self.handleKeyTouchesCancelled()
            }
        }
    }
    
    // 键盘环境采集
    func currentEnvironment() -> KBKeyboardEnvironment {
        KBKeyboardEnvironment(
            idiom: traitCollection.userInterfaceIdiom,
            isLandscape: bounds.width > bounds.height,
            safeAreaBottom: safeAreaInsets.bottom
        )
    }
    
    func animateHeightChangeIfNeeded() {

        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            self.invalidateIntrinsicContentSize()
            self.superview?.setNeedsLayout()
            self.superview?.layoutIfNeeded()
        }
    }
    
    func applyInitialShiftStateIfNeeded() {
        // 系统行为：首次进入字母键盘 = 单次大写
        shiftState = .uppercase
        keyContainerView.updateShiftKeyUI(animated: false, shiftState: shiftState)
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
            keyContainerView.updateShiftKeyUI(shiftState: shiftState)
        }

        // 3. 强制结束本轮触摸（🔥关键）
        finishActiveKeyInteraction()
    }
    
    func finishActiveKeyInteraction() {

        // 1️⃣ 恢复当前 key 的视觉状态
        keyContainerView.finishActiveKeyInteraction()

        // 2️⃣ 终止 popup
        popupPresenter.hide()
    }
}

// MARK: - Key feedback
private extension KBKeyboardView {
    func feedbackRole(for key: KBKey) -> KeyFeedbackRole {
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
