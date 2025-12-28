//
//  KBKeyboardFeedback.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/23.
//

enum KeyFeedbackRole {
    case character
    case space
    case function      // shift / return / layout
    case delete
    case popupSelect
    case capsLock
}

class KBKeyboardFeedbackEngine {

    static let shared = KBKeyboardFeedbackEngine()

    private let sound = KBKeyboardSoundPlayer.shared
    private let haptic = KBKeyboardHapticEngine.shared

    func trigger(for role: KeyFeedbackRole) {
        sound.play(for: role)
        haptic.trigger(for: role)
    }
    
    func triggerSlide() {
        haptic.triggerSlide()
    }
}
