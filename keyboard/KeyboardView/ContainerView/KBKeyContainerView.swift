//
//  KBKeyContainerView.swift
//  keyboard
//
//  Created by Yu Chen  on 2025/12/27.
//

import UIKit
/*
 KBKeyboardView
 ├─ keyContainerView : KBKeyContainerView
 ├─ popupContainerView : KBPopupContainerView
 ├─ overlayContainerView : KBOverlayContainerView
 │
 ├─ popupPresenter
 └─ popupStateMachine
 */
enum KBKeyTouchEvent {
    case began(point: CGPoint, key: KBKey)
    case moved(point: CGPoint, key: KBKey?)
    case ended(point: CGPoint, key: KBKey?)
    case cancelled
}

enum ShiftGesture {
    case tap
    case longPress
    case doubleTap
}

protocol KBShiftGestureReporting: AnyObject {
    func didRecognizeShiftGesture(_ gesture: ShiftGesture, shiftState state: ShiftState)
}

/* 职责
 1.    管理 key layers
 2.    命中测试（point → key）
 3.    输出“键交互事件流”
 */
class KBKeyContainerView: UIView {

    // MARK: - Public
    var onKeyTouchEvent: ((KBKeyTouchEvent) -> Void)?
    weak var shiftGestureDelegate: KBShiftGestureReporting?
    
    // MARK: - Internal storage
    private var keys: [KBKey] = []
    private var keyLayers: [String: KBBaseKeyLayer] = [:]
    private var activeKeyID: String?
    // 当前活跃 key 的交互序列
    private var interactionSequence: Int = 0
    
    // MARK: - shift
    private var lastShiftTapTime: CFTimeInterval = 0
    private let shiftDoubleTapInterval: CFTimeInterval = 0.28
    private var shiftLongPressTimer: Timer?
    private let shiftLongPressDuration: TimeInterval = 0.32
    /*
     长按优先级 > 单击
     •    一旦触发 long press
     •    touchesEnded 不再走单击 shift
     */
    private var shiftDidLongPress = false
    
    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Key sync
    func updateKeys(_ keys: [KBKey]) {
        self.keys = keys
        syncLayers()
    }
    
    // 更新 shift 键 UI
    func updateShiftKeyUI(animated: Bool = true, shiftState state: ShiftState) {
        guard let shiftLayer = keyLayers["shift"] as? KBShiftKeyLayer else {
            return
        }
        shiftLayer.shiftState = state
        // 更新字母按键文字
        updateCharacterKeysCase(shiftState: state)
    }
    
    // 恢复当前活跃Key的视觉状态
    func finishActiveKeyInteraction() {
        // 1️⃣ 恢复当前 key 的视觉状态
        if let id = activeKeyID,
           let layer = keyLayers[id] {

            layer.animatePressUp {
                layer.setVisualState(.normal, animated: true)
            }
        }

        // 2️⃣ 清理触摸状态
        cleanup()
    }
    
    // touchMove 视觉回弹
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
    func releaseKeyVisualInTouchMove(key: KBKey?, feedback: (() -> Void)) {
        if let _new_key = key {
            if _new_key.keyId != activeKeyID {
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
                activeKeyID = _new_key.keyId
                
                if let _key_layer = keyLayers[_new_key.keyId] {
                    _key_layer.animateKeyPressDown()
                }
                
                feedback()
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
    
    // touchEnd 视觉回弹
    /*
     在一次触摸结束时：
     如果手指最终停在某个 key 上 → 提交该 key；
     如果没有停在任何 key 上 → 只恢复视觉状态，不提交输入。
     Touch Ended
     │
     ├─ Popup consumed?
     │   └─ Yes → Exit
     │
     ├─ Hit test key at end?
     │   ├─ Yes
     │   │   ├─ End key pressed state
     │   │   └─ Commit key action
     │   │
     │   └─ No
     │       ├─ End previously pressed key state
     │       └─ Do NOT commit
     */
    func releaseKeyVisualInTouchEnd(key: KBKey?, performKeyAction: ((KBKey?) -> Void)) {
        if let _new_key = key {
            // visual release
            if let _press_layer = keyLayers[_new_key.keyId] {
                _press_layer.animatePressUp {
                    // 仅恢复当前活跃的 key 的稳定态
                    guard _press_layer.currentInteractionSeq == self.interactionSequence else {
                        return
                    }
                    
                    // 动画结束， 按键恢复至稳定态
                    _press_layer.setVisualState(KBKeyVisualState.normal, animated: true)
                }
            }
            
            performKeyAction(_new_key)
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
    }
    
    func cleanup(resetShiftTap: Bool = true) {
        activeKeyID = nil

        // shift 语义重置
        if resetShiftTap {
            lastShiftTapTime = 0
        }
    }
}

extension KBKeyContainerView {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self),
              let key = key(at: p)
        else { return }

        shiftDidLongPress = false
        activeKeyID = key.keyId
        
        if let _key_layer = keyLayers[key.keyId] {
            // 交互序列 ++
            interactionSequence += 1
            _key_layer.animateKeyPressDown()
            _key_layer.currentInteractionSeq = interactionSequence
        }
        
        // press visual
        if key.keyType == .shift {
            shiftLongPressTimer?.invalidate()
            shiftLongPressTimer = Timer.scheduledTimer(
                withTimeInterval: shiftLongPressDuration,
                repeats: false
            ) { [weak self] _ in
                guard let self else { return }
                self.shiftDidLongPress = true          // ✅ 必须
                self.updateShiftKeyUI(shiftState: ShiftState.locked)
                KBKeyboardHapticEngine.shared.trigger(for: .capsLock)
                self.shiftGestureDelegate?.didRecognizeShiftGesture(ShiftGesture.longPress, shiftState: ShiftState.locked)
            }
        }
        
        onKeyTouchEvent?(.began(point: p, key: key))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else { return }

        let hitKey = key(at: p)

        // 判断 是不是 shift 长按手指移出
        if let active = activeKeyID, let activeKey = keys.first(where: { $0.keyId == active }), activeKey.keyType == .shift {
            if hitKey?.keyId != active {
                // 手指离开 shift
                shiftLongPressTimer?.invalidate()
                shiftLongPressTimer = nil
            }
        }
        
        if hitKey?.keyId != activeKeyID {
            if let prev = activeKeyID {
                keyLayers[prev]?.animatePressUp {
                    self.keyLayers[prev]?.setVisualState(.normal, animated: true)
                }
            }

            if let newKey = hitKey {
                keyLayers[newKey.keyId]?.animateKeyPressDown()
                activeKeyID = newKey.keyId
            } else {
                activeKeyID = nil
            }
        }

        onKeyTouchEvent?(.moved(point: p, key: hitKey))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        shiftLongPressTimer?.invalidate()
        shiftLongPressTimer = nil
        
        guard let p = touches.first?.location(in: self) else {
            onKeyTouchEvent?(.cancelled)
            cleanup()
            return
        }
        
        if shiftDidLongPress {
            lastShiftTapTime = 0
            shiftDidLongPress = false
            cleanup()
            return
        }

        let hitKey = key(at: p)

        if let id = activeKeyID {
            keyLayers[id]?.animatePressUp {
                self.keyLayers[id]?.setVisualState(.normal, animated: true)
            }
        }
        
        if hitKey?.keyType == .shift, let _keyId = hitKey?.keyId, let keyLayer = keyLayers[_keyId] as? KBShiftKeyLayer {
            handleShiftTap(shiftState: keyLayer.shiftState)
        }

        onKeyTouchEvent?(.ended(point: p, key: hitKey))
        cleanup(resetShiftTap: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        shiftLongPressTimer?.invalidate()
        shiftLongPressTimer = nil
        
        onKeyTouchEvent?(.cancelled)
        
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
        cleanup(resetShiftTap: false)
    }

    private func key(at point: CGPoint) -> KBKey? {
        keys.first { $0.frame.contains(point) }
    }
}

private extension KBKeyContainerView {
    func syncLayers() {
        let existing = Set(keyLayers.keys)
        let target = Set(keys.map { $0.keyId })

        // remove
        for id in existing.subtracting(target) {
            keyLayers[id]?.removeFromSuperlayer()
            keyLayers.removeValue(forKey: id)
        }

        for key in keys {
            let layer: KBBaseKeyLayer
            if let l = keyLayers[key.keyId] {
                layer = l
            } else {
                layer = makeLayer(for: key)
                keyLayers[key.keyId] = layer
                self.layer.addSublayer(layer)
            }
            
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
    
    func makeLayer(for key: KBKey) -> KBBaseKeyLayer {
        let config = KBKeyLayerConfig()
        let layer: KBBaseKeyLayer

        switch key.keyType {
        case .shift:
            layer = KBShiftKeyLayer(config: config)
        case .backspace:
            layer = KBDeleteKeyLayer(config: config)
        default:
            layer = KBCharacterKeyLayer(config: config)
        }

        layer.setVisualState(.normal, animated: false)
        return layer
    }
}

// MARK: - shift UI 状态刷新
private extension KBKeyContainerView {
    func updateCharacterKeysCase(shiftState state: ShiftState) {
        for key in keys where key.keyType == .character {
            guard let layer = keyLayers[key.keyId] as? KBCharacterKeyLayer else {
                continue
            }

            let displayText: String
            switch state {
            case .lowercase:
                displayText = key.keyLabel.lowercased()
            case .uppercase, .locked:
                displayText = key.keyLabel.uppercased()
            }

            layer.updateDisplayedText(displayText)
        }
    }
    
    func handleShiftTap(currentTime: TimeInterval = CACurrentMediaTime(), shiftState state: ShiftState) {
        var new_state: ShiftState = state
        switch state {
            case .lowercase:
                // 单击 → 单次大写
                lastShiftTapTime = currentTime
                new_state = .uppercase
                self.shiftGestureDelegate?.didRecognizeShiftGesture(ShiftGesture.tap, shiftState: new_state)
            case .uppercase:
                // 判断是否是双击
                if currentTime - lastShiftTapTime <= shiftDoubleTapInterval {
                    // 双击 → Caps Lock
                    new_state = .locked
                    lastShiftTapTime = 0
                    self.shiftGestureDelegate?.didRecognizeShiftGesture(ShiftGesture.doubleTap, shiftState: new_state)
                } else {
                    // 单击 → 回小写（✅ 关键）
                    new_state = .lowercase
                    lastShiftTapTime = currentTime
                    self.shiftGestureDelegate?.didRecognizeShiftGesture(ShiftGesture.tap, shiftState: new_state)
                }

            case .locked:
                // 再点一次 → 关闭 Caps Lock
                new_state = .lowercase
                self.shiftGestureDelegate?.didRecognizeShiftGesture(ShiftGesture.tap, shiftState: new_state)
                lastShiftTapTime = 0
        }
        
        self.updateShiftKeyUI(shiftState: new_state)
    }
}
