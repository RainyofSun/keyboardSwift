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
  └─ PopupPresenter (接口)
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
final class DefaultPopupPresenter: PopupPresenter {

    // MARK: - Core
    private var popupView: KeyPopupView?
    private var session: KBPopupSession?
    private let interactionController = KBPopupInteractionController()

    // MARK: - Time
    private var displayLink: CADisplayLink?

    // MARK: - Selection
    private var lastPopupSelectedIndex: Int?

    // MARK: - Output
    var selectedCallback: ((String?) -> Void)?
    
    func show(for key: KBKey, from frame: CGRect, in parent: UIView) {

        guard let alts = key.alternatives else { return }

        let session = KBPopupSession(
            key: key,
            candidates: alts,
            keyRect: frame,
            position: key.keyLocation,
            baseRect: parent.bounds
        )

        self.session = session

        // 1️⃣ 启动交互引擎
        interactionController.begin(session: session)

        // 2️⃣ 创建 View（只负责画）
        let popup = KeyPopupView(
            candidates: alts,
            keyPosition: session.position
        )
        parent.addSubview(popup)
        popup.layout(pointingTo: frame, in: parent)
        popup.animateAppear()

        popupView = popup

        // 3️⃣ 启动时间轴
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
        selectedCallback?(selected)
    }

    func hide() {
        cleanup()
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
        lastPopupSelectedIndex = nil
    }

    @objc func tick() {
        guard let geometry = interactionController.tick() else { return }
        popupView?.apply(geometry: geometry)
    }
}
