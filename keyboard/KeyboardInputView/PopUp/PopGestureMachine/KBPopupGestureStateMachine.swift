//
//  KBPopupGestureStateMachine.swift
//  keyboard
//
//  Created by Yu Chen  on 2025/12/25.
//

import UIKit

enum KBPopupGestureState {
    case idle                     // 没有任何触摸
    case pressing                 // 已按下，但未达到长按
    case popupActive              // 候选 popup 已展开
    case cancelling               // 手势取消 / 滑出
}

protocol KBPopupGestureDriver: AnyObject {
    func beginPopup(session: KBPopupSession)
    func updatePopupDrag(point: CGPoint)
    func commitPopup()
    func cancelPopup()
    
    func setLongPressing(_ pressing: Bool)
}

class KBPopupGestureStateMachine: NSObject {
    
    // MARK: - Config
    private let longPressDuration: TimeInterval = 0.35
    private let moveTolerance: CGFloat = 8
    
    // MARK: - State
    private(set) var state: KBPopupGestureState = .idle
    
    private weak var driver: KBPopupGestureDriver?
    
    private var pressBeganTime: TimeInterval = 0
    private var initialPoint: CGPoint = .zero
    private var longPressTimer: Timer?
    
    private var session: KBPopupSession?
    
    // MARK: - Init
    init(driver: KBPopupGestureDriver) {
        self.driver = driver
    }
}

private extension KBPopupGestureStateMachine {
    
    func startLongPressTimer() {
        longPressTimer = Timer.scheduledTimer(
            withTimeInterval: longPressDuration,
            repeats: false
        ) { [weak self] _ in
            self?.activatePopup()
        }
    }
    
    func cancelLongPress() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
    
    func activatePopup() {
        guard state == .pressing,
              let session = session
        else { return }
        
        state = .popupActive
        
        driver?.beginPopup(session: session)
        driver?.setLongPressing(true)
        
        cancelLongPress()
    }
    
    func cleanup() {
        cancelLongPress()
        driver?.setLongPressing(false)
        
        state = .idle
        session = nil
    }
    
    func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        hypot(p1.x - p2.x, p1.y - p2.y)
    }
}
