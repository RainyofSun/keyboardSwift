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
class KBKeyContainerView: UIView {

    

}
/* 需要重构的地方
 final class KBKeyContainerView: UIView {

     weak var delegate: KeyboardViewProtocol?

     // Layout
     private var layoutEngine: KBKeyLayoutEngine!
     private var rows: [KBKeyRow] = []
     private var keysFlat: [KBKey] = []
     private var keyLayers: [String: KBBaseKeyLayer] = [:]

     // Touch
     private var activeKeyID: String?
     private var interactionSequence: Int = 0

     // Shift state
     private var shiftState: ShiftState = .lowercase
     private var lastShiftTapTime: CFTimeInterval = 0
     private let shiftDoubleTapInterval: CFTimeInterval = 0.28
     private var shiftLongPressTimer: Timer?
     private var shiftDidLongPress = false

     // Popup hook（只暴露事件，不知道 presenter）
     var popupTouchHandler: ((KBPopupTouchEvent) -> Void)?

     // MARK: - Init
     init() {
         super.init(frame: .zero)
         isMultipleTouchEnabled = false
         backgroundColor = .clear
     }

     required init?(coder: NSCoder) { fatalError() }

     // MARK: - Touch
     override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
         guard let p = touches.first?.location(in: self),
               let key = key(at: p) else { return }

         activeKeyID = key.keyId
         popupTouchHandler?(.began(point: p, key: key))
         handleKeyPressDown(key)
     }

     override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
         guard let p = touches.first?.location(in: self) else { return }
         popupTouchHandler?(.moved(point: p))
         handleSlide(at: p)
     }

     override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
         guard let p = touches.first?.location(in: self) else { return }
         popupTouchHandler?(.ended(point: p))
         handleKeyCommit(at: p)
     }

     override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
         popupTouchHandler?(.cancelled)
         resetTouch()
     }
 }
 */
