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

        let items = session.key.alternatives ?? []
        let count = items.count

        let candidateWidth = candidateWidth(session: session)

        let contentWidth =
            CGFloat(count) * candidateWidth
            + CGFloat(max(0, count - 1)) * session.itemSpacing
            + session.contentInset.left
            + session.contentInset.right

        // 1️⃣ popupFrame（keyboard 坐标）
        let popupHeight =
            session.keyRect.height * 2
            + session.contentInset.top
            + session.contentInset.bottom

        var popupX = session.keyRect.midX - contentWidth / 2
        popupX = max(8,
            min(
                popupX,
                session.keyboardBounds.width - contentWidth - 8
            )
        )

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
            keyFrameInPopup: keyFrameInPopup,
            popupBounds: popupFrame,
            candidateWidth: candidateWidth,
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
    
    static func candidateWidth(session: KBPopupSession) -> CGFloat {

        let baseKeyWidth = session.keyRect.width

        return min(
            max(
                baseKeyWidth * session.candidateWidthScale,
                session.minCandidateWidth
            ),
            session.maxCandidateWidth
        )
    }
    
    static func layoutCandidates(
        items: [CandidateItem],
        keyFrameInPopup: CGRect,
        popupBounds: CGRect,
        candidateWidth: CGFloat,
        session: KBPopupSession
    ) -> [CandidateLayoutItem] {

        guard !items.isEmpty else { return [] }

        var x = contentStartX(
            keyFrame: keyFrameInPopup,
            popupBounds: popupBounds,
            position: session.position,
            contentInset: session.contentInset
        )

        var result: [CandidateLayoutItem] = []

        for item in items {
            let frame = CGRect(
                x: x,
                y: session.contentInset.top,
                width: candidateWidth,
                height: session.keyRect.height
            )

            result.append(
                CandidateLayoutItem(
                    text: item.text,
                    frame: frame
                )
            )

            x += candidateWidth + session.itemSpacing
        }

        return result
    }
    
    static func contentStartX(
        keyFrame: CGRect,
        popupBounds: CGRect,
        position: KeyPosition,
        contentInset: UIEdgeInsets
    ) -> CGFloat {
        
        let contentWidth = popupBounds.width
        
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
