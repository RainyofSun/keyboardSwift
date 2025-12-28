//
//  KBKeyboardHapticEngine.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/23.
//

import UIKit

class KBKeyboardHapticEngine: NSObject {

    static let shared = KBKeyboardHapticEngine()

    private let selection = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)

    override init() {
        super.init()
        prepare()
    }

    func prepare() {
        selection.prepare()
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
    }

    func trigger(for role: KeyFeedbackRole) {
        switch role {
        case .character, .space:
            impactLight.impactOccurred(intensity: 0.35)
        case .function:
            impactLight.impactOccurred(intensity: 0.55)
        case .delete:
            impactMedium.impactOccurred(intensity: 0.6)
        case .capsLock:
            impactHeavy.impactOccurred(intensity: 0.8)
        case .popupSelect:
            selection.selectionChanged()
        }
    }
    
    func triggerSlide() {
        selection.selectionChanged()
    }
}
