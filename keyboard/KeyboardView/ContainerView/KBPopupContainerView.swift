//
//  KBPopupContainerView.swift
//  keyboard
//
//  Created by Yu Chen  on 2025/12/27.
//

import UIKit

// MARK: - Popup Layer Type
enum KBPopupLayer {
    case candidate
    case emoji
    case menu
}

// MARK: - Popup Container
final class KBPopupContainerView: UIView {

    let candidateContainer = UIView()
    let emojiContainer = UIView()
    let menuContainer = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        setupLayers()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupLayers() {
        [candidateContainer, emojiContainer, menuContainer].forEach {
            $0.isUserInteractionEnabled = false
            $0.backgroundColor = .clear
            addSubview($0)
            $0.frame = bounds
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
    }

    func attach(_ view: UIView, to layer: KBPopupLayer) {
        switch layer {
        case .candidate:
            candidateContainer.addSubview(view)
        case .emoji:
            emojiContainer.addSubview(view)
        case .menu:
            menuContainer.addSubview(view)
        }
    }

    func detach(_ view: UIView) {
        view.removeFromSuperview()
    }

    func removeAllPopups() {
        [candidateContainer, emojiContainer, menuContainer].forEach {
            $0.subviews.forEach { $0.removeFromSuperview() }
        }
    }
}
