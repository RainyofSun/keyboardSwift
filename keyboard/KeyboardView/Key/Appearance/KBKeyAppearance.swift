//
//  KBKeyAppearance.swift
//  keyboard
//
//  Created by Yu Chen  on 2025/12/22.
//

import UIKit

enum KBKeyRole {
    case character
    case function
}

enum KBKeyVisualState {
    case normal
    case pressed
    case disabled
}

struct KBSystemKeyStyle {

    // MARK: - Background

    static func backgroundColor(
        role: KBKeyRole,
        state: KBKeyVisualState,
        darkMode: Bool
    ) -> UIColor {

        if darkMode {
            switch (role, state) {
            case (.character, .normal):  return UIColor(white: 0.18, alpha: 1)
            case (.character, .pressed): return UIColor(white: 0.35, alpha: 1)
            case (.function,  .normal):  return UIColor(white: 0.28, alpha: 1)
            case (.function,  .pressed): return UIColor(white: 0.40, alpha: 1)
            case (_, .disabled):         return UIColor(white: 0.28, alpha: 0.5)
            }
        } else {
            switch (role, state) {
            case (.character, .normal):  return UIColor(white: 0.98, alpha: 1)
            case (.character, .pressed): return UIColor(white: 0.75, alpha: 1)
            case (.function,  .normal):  return UIColor(white: 0.86, alpha: 1)
            case (.function,  .pressed): return UIColor(white: 0.70, alpha: 1)
            case (_, .disabled):         return UIColor(white: 0.86, alpha: 0.5)
            }
        }
    }

    // MARK: - Shadow（系统级）

    static func shadowOpacity(darkMode: Bool) -> Float {
        darkMode ? 0.6 : 0.25
    }

    static func shadowRadius() -> CGFloat {
        3.5
    }

    static func shadowOffset() -> CGSize {
        CGSize(width: 0, height: 1.5)
    }
}
