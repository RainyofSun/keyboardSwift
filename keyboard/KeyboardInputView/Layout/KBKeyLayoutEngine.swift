//
//  KBKeyLayoutEngine.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/4.
//

import UIKit

struct SystemKeyboardMetrics {
    static let normalSpacing: CGFloat = 6
    static let functionSpacing: CGFloat = 12   // Shift / Delete
    static var secondRowIndentFactor: CGFloat = 0.5
}

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
    // 安全区域
    public var safeAreaInsets: UIEdgeInsets = .zero
    /// iPad 等大屏时限制最大键宽，防止键过宽
    public var maxKeyWidth: CGFloat?
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
    
    /// 计算指定键盘类型的所有行与键位 frame
    public func layout(for keyboardType: KeyboardType) -> [KBKeyRow] {

        var rows = provider.rows(for: keyboardType)

        let contentWidth =
            keyboardWidth
            - sidePadding * 2
            - safeAreaInsets.left
            - safeAreaInsets.right
        var currentY = topPadding
        SystemKeyboardMetrics.secondRowIndentFactor = keyboardWidth > keyboardHeight ? 0.42 : 0.5
        
        for rowIndex in rows.indices {

            var row = rows[rowIndex]

            let multipliers: [CGFloat] = row.keys.map {
                row.customWidthMultipliers[$0.keyId] ?? 1.0
            }
            let totalMultiplier = multipliers.reduce(0, +)

            let isSecondRow = rowIndex == 1

            // 🔥 spacing 由相邻 pair 决定（左右对称）
            func spacingBetween(_ left: KBKey, _ right: KBKey) -> CGFloat {
                if left.keyType == .shift || left.keyType == .backspace ||
                   right.keyType == .shift || right.keyType == .backspace {
                    return SystemKeyboardMetrics.functionSpacing
                }
                return SystemKeyboardMetrics.normalSpacing
            }

            let totalSpacing: CGFloat = row.keys.enumerated().reduce(0) { acc, pair in
                let (i, key) = pair
                guard i < row.keys.count - 1 else { return acc }
                return acc + spacingBetween(key, row.keys[i + 1])
            }

            // ① 先算 unitWidth（不含缩进）
            var unitWidth = (contentWidth - totalSpacing) / totalMultiplier

            if let maxKeyWidth, unitWidth > maxKeyWidth {
                unitWidth = maxKeyWidth
            }

            if unitWidth < 18 {
                unitWidth = max(18, (contentWidth - totalSpacing) / CGFloat(row.keys.count))
            }

            // 🔥 ② 用 unitWidth 反推第二行的真实缩进
            let secondRowInset: CGFloat = isSecondRow
                ? unitWidth * SystemKeyboardMetrics.secondRowIndentFactor
                : 0

            // 🔥 ③ 有效宽度重新计算（左右各扣一个 inset）
            let effectiveContentWidth =
                contentWidth
                - totalSpacing
                - secondRowInset * 2

            // 🔥 ④ 用有效宽度重新算 unitWidth（最终值）
            unitWidth = effectiveContentWidth / totalMultiplier

            var currentX =
                sidePadding
                + safeAreaInsets.left
                + secondRowInset
            
            for i in row.keys.indices {

                var key = row.keys[i]
                let keyWidth = unitWidth * multipliers[i]

                key.frame = CGRect(
                    x: currentX,
                    y: currentY,
                    width: keyWidth,
                    height: rowHeight
                )

                row.keys[i] = key

                if i < row.keys.count - 1 {
                    currentX += keyWidth + spacingBetween(key, row.keys[i + 1])
                }
            }

            updateKeyPositions(for: &row)
            rows[rowIndex] = row
            currentY += rowHeight + keySpacing
        }

        return rows
    }
    
    private func updateKeyPositions(for row: inout KBKeyRow) {
        guard row.keys.count > 0 else { return }

        // 行起始 & 结束
        let rowMinX = row.keys.first!.frame.minX
        let rowMaxX = row.keys.last!.frame.maxX
        let rowCenterX = (rowMinX + rowMaxX) / 2

        // 容错阈值（防止浮点误差）
        let edgeTolerance: CGFloat = 1.0
        let centerTolerance: CGFloat = 6.0

        for i in 0..<row.keys.count {
            let keyFrame = row.keys[i].frame
            let keyCenterX = keyFrame.midX

            let position: KeyPosition

            if abs(keyFrame.minX - rowMinX) < edgeTolerance {
                position = .leftEdge
            } else if abs(keyFrame.maxX - rowMaxX) < edgeTolerance {
                position = .rightEdge
            } else if abs(keyCenterX - rowCenterX) < centerTolerance {
                position = .center
            } else if keyCenterX < rowCenterX {
                position = .left
            } else {
                position = .right
            }

            row.keys[i].keyLocation = position
        }
    }
}
