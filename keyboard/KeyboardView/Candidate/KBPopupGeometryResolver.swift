//
//  KBPopupGeometryResolver.swift
//  keyboard
//
//  Created by Yu Chen  on 2025/12/26.
//

import UIKit

/*
 Resolver 只负责回答三个问题
     1.    Popup 本身多大、放在哪
     2.    候选项在 Popup 自身坐标系里的布局
     3.    Key 在 Popup 坐标系里“应该长什么样”
 */
struct KBPopupLayoutResult {

    /// popup 在 keyboard 坐标系下的 frame
    let popupFrame: CGRect

    /// key 在 popup 坐标系下的 frame
    let keyFrameInPopup: CGRect

    /// 候选词在 popup 坐标系下的布局
    let candidateLayouts: [CandidateLayoutItem]
}

/// 纯数学 Popup 布局计算器
/// ❗️不依赖 UIView
/// ❗️不做坐标转换
/// ❗️所有 rect 都基于 keyboard 坐标系
enum KBPopupGeometryResolver {
    
//    static func resolve(session: KBPopupSession) -> KBPopupLayoutResult {
//        
//        guard let alts = session.key.alternatives else {
//            return KBPopupLayoutResult(popupFrame: CGRect.zero, keyFrameInPopup: CGRect.zero, candidateLayouts: [])
//        }
//        
//        let measurer = KBCandidateWidthMeasurer(font: session.itemFont)
//        
//        // 1️⃣ 内容宽度
//        let contentWidth = measurer.totalWidth(
//            items: alts,
//            itemSpacing: session.itemSpacing,
//            contentInset: session.contentInset
//        )
//        
//        // 2️⃣ popup 尺寸
//        let popupHeight = popupHeight(
//            keyRect: keyRect,
//            session: session
//        )
//        
//        // 3️⃣ popup frame（keyboard 坐标系）
//        let popupFrame = popupFrame(
//            keyRect: keyRect,
//            keyboardBounds: keyboardBounds,
//            contentWidth: contentWidth,
//            popupHeight: popupHeight
//        )
//        
//        // 4️⃣ key → popup 坐标系（⚠️ 纯数学）
//        let keyFrameInPopup = CGRect(
//            x: keyRect.minX - popupFrame.minX,
//            y: keyRect.minY - popupFrame.minY,
//            width: keyRect.width,
//            height: keyRect.height
//        )
//        
//        // 5️⃣ 候选项布局（popup 坐标系）
//        let candidateLayouts = layoutCandidates(
//            items: alts,
//            measurer: measurer,
//            keyFrameInPopup: keyFrameInPopup,
//            popupBounds: CGRect(origin: .zero, size: popupFrame.size),
//            session: session
//        )
//        
//        return KBPopupLayoutResult(
//            popupFrame: popupFrame,
//            keyFrameInPopup: keyFrameInPopup,
//            candidateLayouts: candidateLayouts
//        )
//    }
    
    static func resolve(session: KBPopupSession) -> KBPopupLayoutResult {

        let measurer = KBCandidateWidthMeasurer(font: session.itemFont)
        let items = session.key.alternatives ?? []

        let contentWidth = measurer.totalWidth(
            items: items,
            itemSpacing: session.itemSpacing,
            contentInset: session.contentInset
        )

        // 1️⃣ popupFrame（keyboard 坐标）
        let popupHeight =
            session.keyRect.height * 2
            + session.contentInset.top
            + session.contentInset.bottom

        var popupX = session.keyRect.midX - contentWidth / 2
        popupX = max(8, min(
            popupX,
            session.keyboardBounds.width - contentWidth - 8
        ))

        let popupY = session.keyRect.maxY - popupHeight

        let popupFrame = CGRect(
            x: popupX,
            y: popupY,
            width: contentWidth,
            height: popupHeight
        )

        // 2️⃣ keyFrameInPopup（popup 坐标）
        let keyFrameInPopup = session.keyRect.offsetBy(
            dx: -popupFrame.minX,
            dy: -popupFrame.minY
        )

        // 3️⃣ candidateLayouts（popup 坐标）
        let candidateLayouts = layoutCandidates(
            items: items,
            measurer: measurer,
            keyFrameInPopup: keyFrameInPopup,
            popupBounds: popupFrame,
            session: session
        )

        return KBPopupLayoutResult(
            popupFrame: popupFrame,
            keyFrameInPopup: keyFrameInPopup,
            candidateLayouts: candidateLayouts
        )
    }
}

private extension KBPopupGeometryResolver {
    
    static func layoutCandidates(
        items: [CandidateItem],
        measurer: KBCandidateWidthMeasurer,
        keyFrameInPopup: CGRect,
        popupBounds: CGRect,
        session: KBPopupSession
    ) -> [CandidateLayoutItem] {
        
        guard !items.isEmpty else { return [] }
        
        let widths = items.map { measurer.width(for: $0.text) }
        
        let contentWidth =
            widths.reduce(0, +)
            + CGFloat(items.count - 1) * session.itemSpacing
        
        var x = contentStartX(
            keyFrame: keyFrameInPopup,
            contentWidth: contentWidth,
            popupBounds: popupBounds,
            position: session.position,
            contentInset: session.contentInset
        )
        
        let centerY = keyFrameInPopup.midY
        
        var result: [CandidateLayoutItem] = []
        
        for (item, width) in zip(items, widths) {
            let frame = CGRect(
                x: x,
                y: centerY - session.keyRect.height / 2,
                width: width,
                height: session.keyRect.height
            )
            
            result.append(
                CandidateLayoutItem(text: item.text, frame: frame)
            )
            
            x += width + session.itemSpacing
        }
        
        return result
    }
    
    static func contentStartX(
        keyFrame: CGRect,
        contentWidth: CGFloat,
        popupBounds: CGRect,
        position: KeyPosition,
        contentInset: UIEdgeInsets
    ) -> CGFloat {
        
        switch position {
            
        case .center:
            return keyFrame.midX - contentWidth / 2
            
        case .left:
            return max(
                keyFrame.minX + contentInset.left,
                keyFrame.midX - contentWidth * 0.6
            )
            
        case .right:
            return min(
                keyFrame.maxX - contentInset.right - contentWidth,
                keyFrame.midX - contentWidth * 0.4
            )
            
        case .leftEdge:
            return keyFrame.minX + contentInset.left
            
        case .rightEdge:
            return keyFrame.maxX - contentInset.right - contentWidth
        }
    }
}

//class KBPopupGeometryResolver: NSObject {
//    
//    public static func resolve(keyRect: CGRect, session: KBPopupSession, popupView: KeyPopupView, keyboardView: UIView) -> (popRect: CGRect, keyRect: CGRect, candidateLayouts: [CandidateLayoutItem]) {
//        guard let alts = session.key.alternatives else {
//            return (CGRect.zero, CGRect.zero, [])
//        }
//        
//        let measurer = KBCandidateWidthMeasurer(font: session.itemFont)
//        let contentWidth = measurer.totalWidth(items: alts, itemSpacing: session.itemSpacing, contentInset: session.contentInset)
//        // 计算 pop 的frame
//        let popupHeight = keyRect.height * 2 + session.contentInset.top + session.contentInset.bottom
//
//        var x = keyRect.midX - contentWidth / 2
//        x = max(8, min(x, keyboardView.bounds.width - contentWidth - 8))
//        let y = keyRect.maxY - popupHeight
//
//        let popRect = CGRect(x: x, y: y, width: contentWidth, height: popupHeight)
//        
//        // 转换坐标系
//        let kRect = keyboardView.convert(keyRect, to: popupView)
//        
//        // 计算每个候选词的宽度
//        let widths = alts.map { measurer.width(for: $0.text) }
//        let candidateLayouts = layoutCandidates(items: alts, contentWidth: contentWidth, itemWidths: widths, keyRect: kRect, session: session, verticalCenterY: popRect.midY)
//        return (popRect: popRect, keyRect: kRect, candidateLayouts: candidateLayouts)
//    }
//}
//
//private extension KBPopupGeometryResolver {
//    // MARK: - 候选词布局
//    static func layoutCandidates(
//        items: [CandidateItem],
//        contentWidth: CGFloat,
//        itemWidths: [CGFloat],
//        keyRect: CGRect,
//        session: KBPopupSession,
//        verticalCenterY: CGFloat
//    ) -> [CandidateLayoutItem] {
//
//        guard !items.isEmpty else { return [] }
//
//        // 1️⃣ 起始 X
//        var x = contentStartX(
//            headRect: keyRect,
//            contentWidth: contentWidth,
//            position: session.position,
//            contentInset: session.contentInset
//        )
//
//        // 2️⃣ 逐个布局
//        var result: [CandidateLayoutItem] = []
//
//        for (item, width) in zip(items, itemWidths) {
//            let frame = CGRect(
//                x: x,
//                y: verticalCenterY - 14,   // 字体高度一半，建议测
//                width: width,
//                height: 28
//            )
//
//            result.append(
//                CandidateLayoutItem(text: item.text, frame: frame)
//            )
//
//            x += width + session.itemSpacing
//        }
//
//        return result
//    }
//    
//    static func contentStartX(
//        headRect: CGRect,
//        contentWidth: CGFloat,
//        position: KeyPosition,
//        contentInset: UIEdgeInsets
//    ) -> CGFloat {
//
//        switch position {
//
//        case .center:
//            return headRect.midX - contentWidth / 2
//
//        case .left:
//            return max(
//                headRect.minX + contentInset.left,
//                headRect.midX - contentWidth * 0.6
//            )
//
//        case .right:
//            return min(
//                headRect.maxX - contentInset.right - contentWidth,
//                headRect.midX - contentWidth * 0.4
//            )
//
//        case .leftEdge:
//            return headRect.minX + contentInset.left
//
//        case .rightEdge:
//            return headRect.maxX - contentInset.right - contentWidth
//        }
//    }
//}
