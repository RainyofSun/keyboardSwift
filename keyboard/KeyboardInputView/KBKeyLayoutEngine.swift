//
//  KBKeyLayoutEngine.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/4.
//

import UIKit

/// 根据可用宽度、填充和每行规则计算键的帧数。
class KBKeyLayoutEngine: NSObject {
    // public config
    public var keyboardWidth: CGFloat
    public var keyboardHeight: CGFloat
    public var rowHeight: CGFloat
    public var keySpacing: CGFloat
    public var sidePadding: CGFloat
    public var topPadding: CGFloat
    public var bottomPadding: CGFloat

    /// scaling factor used on large devices (iPad) so keys don't get excessively wide
    public var maxKeyWidth: CGFloat? = nil

    private let provider: KeyboardLayoutProviding
    
    init(keyboardWidth: CGFloat, keyboardHeight: CGFloat, rowHeight: CGFloat, keySpacing: CGFloat, sidePadding: CGFloat, topPadding: CGFloat, bottomPadding: CGFloat, maxKeyWidth: CGFloat? = nil, provider: KeyboardLayoutProviding) {
        self.keyboardWidth = keyboardWidth
        self.keyboardHeight = keyboardHeight
        self.rowHeight = rowHeight
        self.keySpacing = keySpacing
        self.sidePadding = sidePadding
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.maxKeyWidth = maxKeyWidth
        self.provider = provider
    }
    
    /// Compute Key frames for given keyboard type and return rows with frames set.
    public func layout(for keyboardType: KeyboardType) -> [KBKeyRow] {
        var rows = provider.rows(for: keyboardType)

        // available content width
        let contentWidth = keyboardWidth - 2 * sidePadding

        // starting y
        var currentY = topPadding

        for rowIndex in 0..<rows.count {
            var row = rows[rowIndex]

            // compute per-key multipliers: default 1.0 unless custom specified
            let defaultMultiplier: CGFloat = 1.0
            let multipliers: [CGFloat] = row.keys.map { key in
                return row.customWidthMultipliers[key.keyId] ?? defaultMultiplier
            }

            // total multiplier sum
            let totalMultiplier = multipliers.reduce(0, +)

            // total spacing in this row (between keys)
            let totalSpacing = keySpacing * CGFloat(max(row.keys.count - 1, 0))

            // available width after indent and spacing
            let rowIndent = row.indent
            let rowAvailableWidth = contentWidth - rowIndent - totalSpacing

            // base unit width
            var unitWidth = rowAvailableWidth / totalMultiplier

            // enforce maxKeyWidth if set
            if let maxKeyWidth = maxKeyWidth {
                // if unitWidth exceeds maxKeyWidth, shrink unit by capping
                if unitWidth > maxKeyWidth {
                    unitWidth = maxKeyWidth
                }
            }

            // If unitWidth computed too small (<8), fallback to minimal spacing layout
            if unitWidth < 8 {
                let fallbackWidth = max(20, rowAvailableWidth / CGFloat(row.keys.count))
                unitWidth = fallbackWidth
            }

            var currentX = sidePadding + rowIndent

            for (i, var key) in row.keys.enumerated() {
                let multiplier = multipliers[i]
                let keyW = multiplier * unitWidth
                let keyFrame = CGRect(x: currentX, y: currentY, width: keyW, height: rowHeight)
                key.frame = keyFrame
                row.keys[i] = key

                currentX += keyW + keySpacing
            }

            // save back
            rows[rowIndex] = row

            currentY += rowHeight + keySpacing
        }

        return rows
    }
}
