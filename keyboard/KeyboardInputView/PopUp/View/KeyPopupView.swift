//
//  KeyPopupView.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/4.
//

import UIKit

struct PopupGeometry {

    let path: CGPath
    let blurAlpha: CGFloat
    let highlightOpacity: Float
    let headOffsetX: CGFloat
}

final class KeyPopupView: UIView {

    func apply(geometry: PopupGeometry) {
        shapeLayer.path = geometry.path
        blurView.alpha = geometry.blurAlpha
        highlightLayer.opacity = geometry.highlightOpacity
        shapeLayer.setAffineTransform(
            CGAffineTransform(translationX: geometry.headOffsetX, y: 0)
        )
    }
}

public class KeyPopupView: UIView {

    // MARK: - Public
    public var cornerRadius: CGFloat = 10
    public var contentInset: UIEdgeInsets = .init(top: 8, left: 12, bottom: 8, right: 12)
    public var itemSpacing: CGFloat = 8
    public var neckSpacing: CGFloat = 8
    public var font: UIFont = .systemFont(ofSize: 20)

    public var selectedIndex: Int = 0

    public var currentSelection: String {
        layoutItems[selectedIndex].text
    }

    // MARK: - Private
    private let candidates: [CandidateItem]
    private let keyPosition: KeyPosition

    private var layoutItems: [CandidateLayoutItem] = []
    private var textLayers: [CATextLayer] = []

    private let shapeLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()
    private let highlightMaskLayer = CAShapeLayer()

    private let highlightInset = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)

    private var keyRect: CGRect = .zero
    private var dragOffsetX: CGFloat = 0
    private var heightScale: CGFloat = 1.0
    
    // MARK: - Init
    init(candidates: [CandidateItem], keyPosition: KeyPosition) {
        self.candidates = candidates
        self.keyPosition = keyPosition
        super.init(frame: .zero)

        isOpaque = false
        backgroundColor = .white

        shapeLayer.fillColor = UIColor.systemBackground.cgColor
        shapeLayer.shadowColor = UIColor.black.cgColor
        shapeLayer.shadowOpacity = 0.25
        shapeLayer.shadowRadius = 8
        shapeLayer.shadowOffset = CGSize(width: 0, height: 4)

        layer.addSublayer(shapeLayer)

        highlightLayer.fillColor = UIColor.systemGray4.cgColor
        highlightLayer.opacity = 0
        layer.addSublayer(highlightLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout
    public func layout(pointingTo target: CGRect, in parent: UIView) {

        keyRect = parent.convert(target, to: self)

        let contentWidth = calculateContentWidth()
        let popupHeight =
            target.height
            + target.height * heightScale
            + contentInset.top
            + contentInset.bottom
            + neckSpacing

        var x = target.midX - contentWidth / 2
        x = max(8, min(x, parent.bounds.width - contentWidth - 8))

        let y = target.maxY - popupHeight

        frame = CGRect(x: x, y: y, width: contentWidth, height: popupHeight)

        layoutCandidates()
        layoutTextLayers()
        updateHighlight(animated: false)
        updateShapePath(animated: false)
    }

    // MARK: - Candidate Layout
    private func layoutCandidates() {

        layoutItems = layoutCandidates(
            items: candidates,
            measurer: measurer,
            headRect: keyRect,
            position: keyPosition,
            itemSpacing: itemSpacing,
            horizontalPadding: contentInset.left,
            verticalCenterY: bounds.midY
        )
    }

    private func calculateContentWidth() -> CGFloat {
        let widths = candidates.map { measurer.width(for: $0.text) }
        return widths.reduce(0, +)
            + CGFloat(candidates.count - 1) * itemSpacing
            + contentInset.left
            + contentInset.right
    }

    // MARK: - Text Layers
    private func layoutTextLayers() {

        if textLayers.count != layoutItems.count {
            textLayers.forEach { $0.removeFromSuperlayer() }
            textLayers = layoutItems.map { _ in CATextLayer() }

            for layer in textLayers {
                layer.contentsScale = UIScreen.main.scale
                layer.alignmentMode = .center
                layer.foregroundColor = UIColor.label.cgColor
                layer.font = font
                layer.fontSize = font.pointSize
                self.layer.addSublayer(layer)
            }
        }

        for (layer, item) in zip(textLayers, layoutItems) {
            layer.string = item.text
            layer.frame = item.frame
        }
    }

    // MARK: - Highlight
    private func updateHighlight(animated: Bool) {

        guard layoutItems.indices.contains(selectedIndex) else { return }

        let rect = layoutItems[selectedIndex]
            .frame
            .inset(by: highlightInset)

        let path = UIBezierPath(roundedRect: rect, cornerRadius: 6)

        if animated {
            let anim = CABasicAnimation(keyPath: "path")
            anim.fromValue = highlightLayer.path
            anim.toValue = path.cgPath
            anim.duration = 0.12
            anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            anim.fillMode = .forwards
            anim.isRemovedOnCompletion = false
            highlightLayer.add(anim, forKey: "highlight")
        }

        highlightLayer.path = path.cgPath
        highlightLayer.opacity = 1
    }
    
    // MARK: - Selection
    public func updateSelection(for pointInParent: CGPoint) {

        let local = convert(pointInParent, to: self)

        if let index = layoutItems.firstIndex(where: { $0.frame.contains(local) }) {
            selectedIndex = index
        } else {
            selectedIndex = layoutItems
                .enumerated()
                .min(by: { abs($0.element.frame.midX - local.x) <
                            abs($1.element.frame.midX - local.x) })?
                .offset ?? selectedIndex
        }

        updateHighlight(animated: true)
        updateDragOffset(with: local.x)
    }

    // touchesEnded/Paned 调用
    public func endTracking() {
        dragOffsetX = 0
        updateShapePath(animated: true)
    }
    
    // MARK: - Shape
    private func updateDragOffset(with localX: CGFloat) {

        let raw = localX - keyRect.midX
        let maxOffset: CGFloat = 24

        dragOffsetX = max(-maxOffset, min(raw, maxOffset))

        if keyPosition == .leftEdge { dragOffsetX = max(0, dragOffsetX) }
        if keyPosition == .rightEdge { dragOffsetX = min(0, dragOffsetX) }

        updateShapePath(animated: false)
    }
    
    private func updateShapePath(animated: Bool = false) {
//        let path = _key_position.continuousPopupPath(
//            baseRect: bounds,
//            keyRect: _t_rect,
//            keyHeight: self._t_rect.height * _height_scale,
//            headOffsetX: dragOffsetX
//        )
        
//        let path = _key_position.buildPopupPath(
//            baseRect: bounds,
//            keyRect: _t_rect,
//        )

//        if animated {
//            animatePath(to: path)
//        } else {
//            shapeLayer.path = path.cgPath
//            shapeLayer.shadowPath = path.cgPath
//            highlightMaskLayer.path = shapeLayer.path
//            highlightLayer.mask = highlightMaskLayer
//        }
    }
    
    private func animatePath(
        to newPath: UIBezierPath,
        duration: CFTimeInterval = 0.18,
        timing: CAMediaTimingFunction = .init(name: .easeOut)
    ) {

        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = shapeLayer.path
        animation.toValue = newPath.cgPath
        animation.duration = duration
        animation.timingFunction = timing
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        shapeLayer.add(animation, forKey: "path")

        shapeLayer.path = newPath.cgPath
        shapeLayer.shadowPath = newPath.cgPath
    }

    private func highlightRect(for itemFrame: CGRect) -> CGRect {
        
        var rect = itemFrame.inset(by: highlightInset)

        // 🔥 吸附到 popup 内部（关键）
        let safeBounds = bounds.insetBy(dx: 4, dy: 4)
        rect = rect.intersection(safeBounds)

        return rect
    }

    func commitSelection() -> CandidateItem? {
        guard candidates.indices.contains(selectedIndex) else { return nil }
        return candidates[selectedIndex]
    }
    
    // popUp 弹出动画
    public func animateAppear() {
        transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        alpha = 0

        UIView.animate(
            withDuration: 0.15,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            self.transform = .identity
            self.alpha = 1
        }
    }
    
    // 候选词布局 ------
    func layoutCandidates(
        items: [CandidateItem],
        measurer: KBCandidateWidthMeasurer,
        headRect: CGRect,
        position: KeyPosition,
        itemSpacing: CGFloat,
        horizontalPadding: CGFloat,
        verticalCenterY: CGFloat
    ) -> [CandidateLayoutItem] {

        guard !items.isEmpty else { return [] }

        // 1️⃣ 算总宽度
        let widths = items.map { measurer.width(for: $0.text) }
        let contentWidth =
            widths.reduce(0, +)
            + CGFloat(items.count - 1) * itemSpacing

        // 2️⃣ 起始 X
        var x = contentStartX(
            headRect: headRect,
            contentWidth: contentWidth,
            position: position,
            horizontalPadding: horizontalPadding
        )

        // 3️⃣ 逐个布局
        var result: [CandidateLayoutItem] = []

        for (item, width) in zip(items, widths) {
            let frame = CGRect(
                x: x,
                y: verticalCenterY - 14,   // 字体高度一半，建议测
                width: width,
                height: 28
            )

            result.append(
                CandidateLayoutItem(text: item.text, frame: frame)
            )

            x += width + itemSpacing
        }

        return result
    }
    
    func contentStartX(
        headRect: CGRect,
        contentWidth: CGFloat,
        position: KeyPosition,
        horizontalPadding: CGFloat
    ) -> CGFloat {

        switch position {

        case .center:
            return headRect.midX - contentWidth / 2

        case .left:
            return max(
                headRect.minX + horizontalPadding,
                headRect.midX - contentWidth * 0.6
            )

        case .right:
            return min(
                headRect.maxX - horizontalPadding - contentWidth,
                headRect.midX - contentWidth * 0.4
            )

        case .leftEdge:
            return headRect.minX + horizontalPadding

        case .rightEdge:
            return headRect.maxX - horizontalPadding - contentWidth
        }
    }
    
    func resolvedAlternatives(for key: KBKey, shiftState: ShiftState) -> [String] {
        guard let alts = key.alternatives else { return [] }

        switch shiftState {
        case .lowercase:
            return alts.map { $0.text.lowercased() }

        case .uppercase:
            return alts.map {
                $0.text.prefix(1).uppercased() + $0.text.dropFirst().lowercased()
            }

        case .locked:
            return alts.map { $0.text.uppercased() }
        }
    }
}
