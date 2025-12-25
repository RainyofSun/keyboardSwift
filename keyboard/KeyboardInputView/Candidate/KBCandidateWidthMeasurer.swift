//
//  KBCandidateWidthMeasurer.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/19.
//

import UIKit

class KBCandidateWidthMeasurer: NSObject {

    private var font: UIFont = UIFont.systemFont(ofSize: 22, weight: .medium)
    private var cache: [String: CGFloat] = [:]

    init(font: UIFont = UIFont.systemFont(ofSize: 22, weight: .medium)) {
        super.init()
        self.font = font
    }

    func setFont(font: UIFont = UIFont.systemFont(ofSize: 22, weight: .medium)) {
        self.font = font
    }
    
    func width(for text: String) -> CGFloat {
        if let cached = cache[text] {
            return cached
        }

        let width = (text as NSString).size(
            withAttributes: [.font: font]
        ).width.rounded(.up)

        cache[text] = width
        return width
    }

    func totalWidth(
        items: [CandidateItem],
        itemSpacing: CGFloat,
        contentInset: UIEdgeInsets
    ) -> CGFloat {

        guard !items.isEmpty else { return 0 }

        let textWidth = items.reduce(0) {
            $0 + width(for: $1.text)
        }

        let spacing = CGFloat(items.count - 1) * itemSpacing

        return textWidth + spacing + contentInset.left + contentInset.right
    }
}
