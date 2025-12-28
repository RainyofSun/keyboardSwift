//
//  KBPopupGestureStateMachine.swift
//  keyboard
//
//  Created by Yu Chen  on 2025/12/25.
//

import UIKit
/*
 KBKeyboardViewFull
    │
    │  touchesBegan / Moved / Ended
    ▼
 KBPopupGestureStateMachine        ←【新加：交互意图层】
    │
    │  beginPopup / update / commit / cancel
    ▼
 DefaultPopupPresenter             ←【导演 / 生命周期层】
    │
    │  begin / tick / apply
    ▼
 KBPopupInteractionController      ←【几何 & 动画内核】
 */
enum KBPopupGestureState {
    case idle                     // 没有任何触摸
    case pressing                 // 已按下，但未达到长按
    case popupActive              // 候选 popup 已展开
    case cancelling               // 手势取消 / 滑出
}

/*
 KBPopupGestureDriver ——【意图接口 / 命令接口】

 它解决的是这件事：

 “手势状态机决定：现在该 show / update / commit / cancel popup 了”

 它不关心：
     •    View 怎么画
     •    CADisplayLink
     •    path、geometry
     •    animator 细节
 */
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

extension KBPopupGestureStateMachine {
    
    func touchBegan(
        at point: CGPoint,
        session: KBPopupSession
    ) {
        guard state == .idle else { return }
        
        self.state = .pressing
        self.session = session
        self.initialPoint = point
        self.pressBeganTime = CACurrentMediaTime()
        
        startLongPressTimer()
    }
    
    func touchMoved(to point: CGPoint) {
        switch state {
            
        case .pressing:
            // 超出移动容差 → 认为是普通滑动 / 取消长按
            if distance(point, initialPoint) > moveTolerance {
                cancelLongPress()
                state = .idle
            }
            
        case .popupActive:
            driver?.updatePopupDrag(point: point)
            
        default:
            break
        }
    }
    
    func touchEnded(at point: CGPoint) {
        switch state {
            
        case .pressing:
            // 没到长按时间 → 普通 tap
            cancelLongPress()
            state = .idle
            
        case .popupActive:
            driver?.commitPopup()
            driver?.setLongPressing(false)
            cleanup()
            
        default:
            cleanup()
        }
    }
    
    func touchCancelled() {
        driver?.cancelPopup()
        driver?.setLongPressing(false)
        cleanup()
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
