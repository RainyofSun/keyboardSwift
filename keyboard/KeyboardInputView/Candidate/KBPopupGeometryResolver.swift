//
//  KBPopupGeometryResolver.swift
//  keyboard
//
//  Created by Yu Chen  on 2025/12/26.
//

import UIKit

// 职责 - 计算pop的frame、转换键盘按键的frame到popview坐标系
class KBPopupGeometryResolver: NSObject {
    
    public static func resolve(keyRect: CGRect, session: KBPopupSession, popupView: KeyPopupView, keyboardView: UIView) -> (popRect: CGRect, keyRect: CGRect, candidateLayouts: [CandidateLayoutItem]) {
        guard let alts = session.key.alternatives else {
            return (CGRect.zero, CGRect.zero, [])
        }
        
        let measurer = KBCandidateWidthMeasurer(font: session.itemFont)
        let contentWidth = measurer.totalWidth(items: alts, itemSpacing: session.itemSpacing, contentInset: session.contentInset)
        // 计算 pop 的frame
        let popupHeight = keyRect.height * 2 + session.contentInset.top + session.contentInset.bottom

        var x = keyRect.midX - contentWidth / 2
        x = max(8, min(x, keyboardView.bounds.width - contentWidth - 8))
        let y = keyRect.maxY - popupHeight

        let popRect = CGRect(x: x, y: y, width: contentWidth, height: popupHeight)
        
        // 转换坐标系
        let kRect = keyboardView.convert(keyRect, to: popupView)
        
        // 计算每个候选词的宽度
        let widths = alts.map { measurer.width(for: $0.text) }
        let candidateLayouts = layoutCandidates(items: alts, contentWidth: contentWidth, itemWidths: widths, keyRect: kRect, session: session, verticalCenterY: popRect.midY)
        return (popRect: popRect, keyRect: kRect, candidateLayouts: candidateLayouts)
    }
}

private extension KBPopupGeometryResolver {
    // MARK: - 候选词布局
    static func layoutCandidates(
        items: [CandidateItem],
        contentWidth: CGFloat,
        itemWidths: [CGFloat],
        keyRect: CGRect,
        session: KBPopupSession,
        verticalCenterY: CGFloat
    ) -> [CandidateLayoutItem] {

        guard !items.isEmpty else { return [] }

        // 1️⃣ 算总宽度
//        let widths = items.map { measurer.width(for: $0.text) }
//        let contentWidth =
//            widths.reduce(0, +)
//            + CGFloat(items.count - 1) * itemSpacing

        // 1️⃣ 起始 X
        var x = contentStartX(
            headRect: keyRect,
            contentWidth: contentWidth,
            position: session.position,
            contentInset: session.contentInset
        )

        // 2️⃣ 逐个布局
        var result: [CandidateLayoutItem] = []

        for (item, width) in zip(items, itemWidths) {
            let frame = CGRect(
                x: x,
                y: verticalCenterY - 14,   // 字体高度一半，建议测
                width: width,
                height: 28
            )

            result.append(
                CandidateLayoutItem(text: item.text, frame: frame)
            )

            x += width + session.itemSpacing
        }

        return result
    }
    
    static func contentStartX(
        headRect: CGRect,
        contentWidth: CGFloat,
        position: KeyPosition,
        contentInset: UIEdgeInsets
    ) -> CGFloat {

        switch position {

        case .center:
            return headRect.midX - contentWidth / 2

        case .left:
            return max(
                headRect.minX + contentInset.left,
                headRect.midX - contentWidth * 0.6
            )

        case .right:
            return min(
                headRect.maxX - contentInset.right - contentWidth,
                headRect.midX - contentWidth * 0.4
            )

        case .leftEdge:
            return headRect.minX + contentInset.left

        case .rightEdge:
            return headRect.maxX - contentInset.right - contentWidth
        }
    }
}
