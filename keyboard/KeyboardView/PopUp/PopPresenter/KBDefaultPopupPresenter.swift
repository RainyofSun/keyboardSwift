//
//  KBDefaultPopupPresenter.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/4.
//

import UIKit
import AVFoundation

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
 
 PopupPresenter (接口)
      └─ DefaultPopupPresenter            🎬 导演
          ├─ PopupSession                 📦 数据快照
          ├─ PopupInteractionController   🧠 交互/几何引擎
          │    ├─ FollowAnimator
          │    ├─ ExpandAnimator
          │    └─ GeometrySolver
          ├─ CADisplayLink                ⏱ 时间轴
          └─ KeyPopupView                 🎨 纯渲染 View
 生命周期：
 show →
   create Session →
   interaction.begin(session) →
   create View →
   startDisplayLink
 
 update →
   popupView.updateSelection →
   interaction.updateDrag
 
 tick →
   interaction.tick →
   popupView.apply(geometry)
 
 commit →
   stopDisplayLink →
   interaction.end →
   removeView →
   callback
 */

/*
 PopupPresenter ——【导演 / 生命周期控制者】

 它解决的是：

 “我要把 popup 从 0 演到 1，再演到结束”

 它关心的是：
     •    View 创建 / 移除
     •    CADisplayLink
     •    InteractionController 生命周期
     •    callback
     •    haptic / selection feedback
     •    session 生命周期
 */
protocol PopupPresenter: AnyObject {
    func show(for session: KBPopupSession)
    func update(at point: CGPoint)
    func commit()
    func hide()
}

// popup 高度意图回调
protocol KBPopupLayoutIntentDelegate: AnyObject {
    func popupRequiresExtendedKeyboard(_ required: Bool)
}

// 选词回调
protocol KBPopupSelectedWordDelegate: AnyObject {
    func didSelectedWord(word: String?)
}

final class DefaultPopupPresenter: PopupPresenter {

    weak public var debugSink: KBPopupDebugSink?
    weak public var layoutIntentDelegate: KBPopupLayoutIntentDelegate?
    weak public var wordDelegate: KBPopupSelectedWordDelegate?
    
    // MARK: - Core
    private weak var popupView: KeyPopupView?
    private var session: KBPopupSession?
    private let interactionController = KBPopupInteractionController()

    // MARK: - Time
    private var displayLink: CADisplayLink?

    // MARK: - Selection
    private var lastPopupSelectedIndex: Int?
    
    // MARK: - Layout
    private var layout: KBPopupLayoutResult?
    private weak var popupContainerView: UIView?
    private let measurer = KBCandidateWidthMeasurer()
    
    init(popupContainerView: UIView? = nil) {
        self.popupContainerView = popupContainerView
    }
    
    func show(for session: KBPopupSession) {
        guard let alts = session.key.alternatives else {
            return
        }
        
        measurer.setFont(font: session.itemFont)
        
        // 1️⃣ 纯数学解析
        let layout = KBPopupGeometryResolver.resolve(session: session)

        // 2️⃣ 创建 popup view（坐标系成立）
        let popup = KeyPopupView(candidates: alts, keyPosition: session.position, itemFont: session.itemFont)
        popup.frame = layout.popupFrame
        popup.layout(candidateLayouts: layout.candidateLayouts)
        popupContainerView?.addSubview(popup)

        popup.animateAppear()
        
        // 3️⃣ 启动交互
        interactionController.begin()

        let popupTopY = layout.popupFrame.minY
        let keyboardTopY = session.keyboardBounds.minY
        /*
         Popup 分两类

         A. 内嵌型 popup（不改高度）
             •    中下行 key（例如 G、H）
             •    popup 完全在键盘 frame 内
             •    ❌ 不需要 height change

         B. 越界型 popup（需要改高度）
             •    第一行 key（Q / W / E）
             •    popup 顶部超出 keyboard bounds
             •    需要 height change
         */
        layoutIntentDelegate?.popupRequiresExtendedKeyboard((keyboardTopY > popupTopY))
        
        self.layout = layout
        self.popupView = popup
        self.session = session
        
        startDisplayLink()
    }

    func update(at point: CGPoint) {
        popupView?.updateSelection(for: point)
        interactionController.updateDrag(point: point)

        guard let popup = popupView else { return }
        if lastPopupSelectedIndex != popup.selectedIndex {
            UISelectionFeedbackGenerator().selectionChanged()
            lastPopupSelectedIndex = popup.selectedIndex
        }
    }

    func commit() {
        let selected = popupView?.currentSelection
        cleanup()
        self.wordDelegate?.didSelectedWord(word: selected)
    }

    func hide() {
        cleanup()
        // 通知高度恢复
        layoutIntentDelegate?.popupRequiresExtendedKeyboard(false)
    }
}

extension DefaultPopupPresenter: KBPopupGestureDriver {
    func beginPopup(session: KBPopupSession) {
        show(for: session)
    }

    func updatePopupDrag(point: CGPoint) {
        update(at: point)
    }

    func commitPopup() {
        commit()
    }

    func cancelPopup() {
        hide()
    }

    func setLongPressing(_ pressing: Bool) {
        interactionController.setLongPressing(pressing)
    }
}

private extension DefaultPopupPresenter {
    func startDisplayLink() {
        displayLink?.invalidate()
        displayLink = CADisplayLink(
            target: self,
            selector: #selector(tick)
        )
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func cleanup() {
        displayLink?.invalidate()
        displayLink = nil

        interactionController.end()

        popupView?.removeFromSuperview()
        popupView = nil
        session = nil
        layout = nil
        lastPopupSelectedIndex = nil
    }
    
    @objc func tick() {

        guard let popup = popupView, let layout = layout, let _session = self.session else {
            return
        }

        let state = interactionController.tick()

        // 内容宽度
        let contentWidth = measurer.totalWidth(
            items: _session.key.alternatives ?? [],
            itemSpacing: _session.itemSpacing,
            contentInset: _session.contentInset
        )

        let baseExpand = baseHeadExpand(
            position: _session.position,
            candidateCount: _session.key.alternatives?.count ?? 0
        )

        let contentExpand = contentDrivenExpand(
            keyRect: _session.keyRect,
            contentWidth: contentWidth,
            position: _session.position
        )

        let longPressExtra = longPressExtraExpand(position: _session.position)

        let path = _session.position.buildPopupPath(
            baseRect: popup.bounds,                 // ✅ popup 坐标
            keyRect: layout.keyFrameInPopup,        // ✅ popup 坐标
            baseExpand: baseExpand,
            contentExpand: contentExpand,
            longPressExtra: longPressExtra,
            longPressProgress: state.expandProgress
        )

        let geometry = PopupGeometry(
            path: path.cgPath,
            blurAlpha: 0.6 + state.expandProgress * 0.4,
            highlightOpacity: Float(0.15 + state.expandProgress * 0.25),
            headOffsetX: state.headOffsetX
        )
        #if DEBUG
        let snapshot: KBPopupDebugSnapshot = KBPopupDebugSnapshot(keyboardBounds: _session.keyboardBounds, safeAreaInsets: _session.safeAreaInsets, keyRect: layout.keyFrameInPopup, popupFrame: popup.frame, popupPath: path.cgPath, candidateFrames: layout.candidateLayouts, textDebugInfos: popup.makeTextDebugSnapshot())
        debugSink?.update(snapshot: snapshot)
        #endif
        
        popupView?.apply(geometry: geometry)
    }
}

private extension DefaultPopupPresenter {
    // head 头部扩展
    func baseHeadExpand(
        position: KeyPosition,
        candidateCount: Int
    ) -> HeadExpand {
        computeHeadExpand(
            keyWidth: 0,
            position: position,
            candidateCount: candidateCount
        )
    }

    func longPressExtraExpand(
        position: KeyPosition
    ) -> HeadExpand {

        let extra: CGFloat = 12

        switch position {
        case .center:
            return HeadExpand(left: extra / 2, right: extra / 2)
        case .left, .leftEdge:
            return HeadExpand(left: 0, right: extra)
        case .right, .rightEdge:
            return HeadExpand(left: extra, right: 0)
        }
    }
    
    func contentDrivenExpand(
        keyRect: CGRect,
        contentWidth: CGFloat,
        position: KeyPosition
    ) -> HeadExpand {

        let extra = max(contentWidth - keyRect.width, 0)

        switch position {
        case .center:
            return HeadExpand(left: extra / 2, right: extra / 2)

        case .left, .leftEdge:
            return HeadExpand(left: 0, right: extra)

        case .right, .rightEdge:
            return HeadExpand(left: extra, right: 0)
        }
    }
    
    func computeHeadExpand(
        keyWidth: CGFloat,
        position: KeyPosition,
        candidateCount: Int
    ) -> HeadExpand {

        let baseExpand: CGFloat = 14
        let candidateStep: CGFloat = 10
        let edgeBoost: CGFloat = 12

        let extra = CGFloat(max(0, candidateCount - 1)) * candidateStep

        switch position {

        case .center:
            return HeadExpand(
                left: baseExpand + extra / 2,
                right: baseExpand + extra / 2
            )

        case .left:
            return HeadExpand(
                left: baseExpand,
                right: baseExpand + extra
            )

        case .right:
            return HeadExpand(
                left: baseExpand + extra,
                right: baseExpand
            )

        case .leftEdge:
            return HeadExpand(
                left: baseExpand,
                right: baseExpand + extra + edgeBoost
            )

        case .rightEdge:
            return HeadExpand(
                left: baseExpand + extra + edgeBoost,
                right: baseExpand
            )
        }
    }
}
