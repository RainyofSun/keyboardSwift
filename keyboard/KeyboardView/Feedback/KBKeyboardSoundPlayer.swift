//
//  KBKeyboardSoundPlayer.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/23.
//

import UIKit
import AudioToolbox

class KBKeyboardSoundPlayer: NSObject {
    
    static let shared = KBKeyboardSoundPlayer()

    func play(for role: KeyFeedbackRole) {
        switch role {
        case .character, .space:
            AudioServicesPlaySystemSound(1104)   // system click
        case .function:
            AudioServicesPlaySystemSound(1156)
        case .delete:
            AudioServicesPlaySystemSound(1155)   // delete tick（可选）
        case .popupSelect, .capsLock:
            break // 系统无声音
        }
    }
}
