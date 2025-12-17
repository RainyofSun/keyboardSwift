//
//  KBDefaultPopupPresenter.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/4.
//

import UIKit
import AVFoundation

final class DefaultPopupPresenter: PopupPresenter {
    private var popupView: KeyPopupView?
    private var hapticGenerator: UISelectionFeedbackGenerator?
    private var lastPopupSelectedIndex: Int?
    public var selectedCallback: ((String?) -> Void)?
    
    func show(for key: KBKey, from frame: CGRect, in parent: UIView) {
        
        guard let _al = key.alternatives else { return }

        let popup = KeyPopupView(candidates: _al, keyPosition: key.keyLocation)
        popup.alpha = 0
        popup.layer.opacity = 0

        parent.addSubview(popup)
        self.popupView = popup
        popup.layout(pointingTo: frame, in: parent)
        popup.selectedIndex = 0

        // simple appear animation
        popup.transform = CGAffineTransform(scaleX: 0.9, y: 0.9).translatedBy(x: 0, y: 6)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut], animations: {
            popup.alpha = 1
            popup.transform = .identity
        }, completion: nil)

        // prepare haptics
        hapticGenerator = UISelectionFeedbackGenerator()
        hapticGenerator?.prepare()
    }

    func update(at point: CGPoint) {
        popupView?.updateSelection(for: point)
        guard let popup = popupView else { return }
        popup.updateSelection(for: point)

        // play small haptic on change
        if lastPopupSelectedIndex != popup.selectedIndex {
            UISelectionFeedbackGenerator().selectionChanged()
            // optional click sound
            AudioServicesPlaySystemSound(1104)
            lastPopupSelectedIndex = popup.selectedIndex
        }
    }

    func commit() {
        let selected = popupView?.currentSelection
        popupView?.removeFromSuperview()
        popupView = nil
        selectedCallback?(selected)
    }

    func hide() {
        guard let popup = popupView else { return }
        UIView.animate(withDuration: 0.12, animations: {
            popup.alpha = 0
            popup.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }, completion: { _ in
            popup.removeFromSuperview()
        })
        popupView = nil
        lastPopupSelectedIndex = nil
        hapticGenerator = nil
    }
}
