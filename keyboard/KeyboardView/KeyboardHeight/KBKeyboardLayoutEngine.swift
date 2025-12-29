//
//  KBKeyboardLayoutEngine.swift
//  keyboard
//
//  Created by Yu Chen  on 2025/12/30.
//

import UIKit

// 定义高度常景枚举
enum KBKeyboardPresentation {
    case original
    case normal
    case withPopup
    case withCandidateBar
    case emoji
    case floating // iPad
}

// 设备环境描述
struct KBKeyboardEnvironment {
    let idiom: UIUserInterfaceIdiom
    let isLandscape: Bool
    let safeAreaBottom: CGFloat
}

struct KBKeyboardMetrics {
    static func height(
        for presentation: KBKeyboardPresentation,
        environment env: KBKeyboardEnvironment
    ) -> CGFloat {

        let base: CGFloat

        switch env.idiom {
        case .pad:
            base = env.isLandscape ? 300 : 360
        default:
            base = env.isLandscape ? 210 : 260
        }

        switch presentation {
        case .normal, .original:
            return base

        case .withPopup:
            return base + 40

        case .withCandidateBar:
            return base + 48

        case .emoji:
            return base + 80

        case .floating:
            return 200
        }
    }
}

protocol KBKeyboardLayoutDriving: AnyObject {
    func keyboardHeightDidChange(_ height: CGFloat, animated: Bool)
}

final class KBKeyboardLayoutEngine: NSObject {

    weak var delegate: KBKeyboardLayoutDriving?

    private(set) var presentation: KBKeyboardPresentation = .original

    func updatePresentation(
        _ newPresentation: KBKeyboardPresentation,
        environment env: KBKeyboardEnvironment,
        animated: Bool
    ) {
        guard newPresentation != presentation else {
            return
        }

        presentation = newPresentation

        let height = KBKeyboardMetrics.height(
            for: newPresentation,
            environment: env
        )

        delegate?.keyboardHeightDidChange(height, animated: animated)
    }

    func refresh(environment env: KBKeyboardEnvironment, animated: Bool) {
        let height = KBKeyboardMetrics.height(
            for: presentation,
            environment: env
        )

        delegate?.keyboardHeightDidChange(height, animated: animated)
    }
}
