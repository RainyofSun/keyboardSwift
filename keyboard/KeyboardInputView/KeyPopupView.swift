//
//  KeyPopupView.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/4.
//

import UIKit
// TODO 候选词绘制
public class KeyPopupView: UIView {

    open var currentSelection: String {
        return candidates[selectedIndex]
    }
    
    private var candidates: [String]
    var selectedIndex: Int = 0 {
        didSet { setNeedsDisplay() }
    }

    public var cornerRadius: CGFloat = 10
    public var contentInset: UIEdgeInsets = .init(top: 8, left: 8, bottom: 8, right: 8)
    public var itemSpacing: CGFloat = 8
    public var neckSpacing: CGFloat = 8 // 脖子的高度
    public var font: UIFont = .systemFont(ofSize: 20)
    
    private var itemFrames: [CGRect] = []   // 每个候选的绘制区域
    private var _key_position: KeyPosition = .center
    private var _t_rect: CGRect = .zero
    // 弹窗键帽与键盘键帽的高度比
    private var _height_scale: CGFloat = 1.0
    private let shapeLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()
    private let highlightMaskLayer = CAShapeLayer()
    private let highlightInset = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6) //高亮内缩参数
    private var dragOffsetX: CGFloat = 0   // 相对 keyRect.midX
    
    public init(candidates: [String], keyPosition position: KeyPosition) {
        self._key_position = position
        self.candidates = candidates
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        
        // 异形 layer
        shapeLayer.fillColor = UIColor.systemBackground.cgColor
        shapeLayer.shadowColor = UIColor.black.cgColor
        shapeLayer.shadowOpacity = 0.25
        shapeLayer.shadowRadius = 8
        shapeLayer.shadowOffset = CGSize(width: 0, height: 4)

        layer.addSublayer(shapeLayer)
        
        // 高亮 layer
        highlightLayer.fillColor = UIColor.systemGray4.cgColor
        highlightLayer.opacity = 0
        layer.addSublayer(highlightLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout popup position above/below key
    public func layout(pointingTo target: CGRect, in parent: UIView) {

        // 1️⃣ popup frame（仍然基于 parent / keyRect）
        let totalWidth = calculateTotalWidth()
        // 高度 = 按键高度 + 脖子高度 + 可选词键帽高度 + 可选词距离顶部space + 可选词距离底部space
        let popupHeight: CGFloat = target.height + target.height * _height_scale
            + contentInset.top + contentInset.bottom + neckSpacing

        var x = target.midX - totalWidth / 2
        x = max(8, min(x, parent.bounds.width - totalWidth - 8))

        let y = target.maxY - popupHeight

        frame = CGRect(x: x, y: y, width: totalWidth, height: popupHeight)

        // 2️⃣ 🔥 键帽 rect → popup 坐标系
        _t_rect = parent.convert(target, to: self)

        // 3️⃣ 更新 path（核心）
        updateShapePath()

        // 4️⃣ 子项布局
        layoutItemFrames()
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
    
    // MARK: - Calculate candidate widths
    private func calculateTotalWidth() -> CGFloat {
        let textWidths = candidates.map { ($0 as NSString).size(withAttributes: [.font: font]).width }
        let totalText = textWidths.reduce(0, +)
        let totalSpacing = CGFloat(candidates.count - 1) * itemSpacing
        return totalText + totalSpacing + contentInset.left + contentInset.right
    }

    private func layoutItemFrames() {
        itemFrames.removeAll()

        var x: CGFloat = contentInset.left
        let centerY = bounds.height / 2

        for c in candidates {
            let size = (c as NSString).size(withAttributes: [.font: font])
            let rect = CGRect(
                x: x,
                y: centerY - size.height / 2,
                width: size.width,
                height: size.height
            )
            itemFrames.append(rect)
            x += size.width + itemSpacing
        }
        
        /*
         let layouts = layoutCandidates(
             items: candidates,
             measurer: measurer,
             headRect: headRect,
             position: position,
             itemSpacing: 8,
             horizontalPadding: 12,
             verticalCenterY: headRect.midY
         )
         */
    }

    // MARK: - Drawing text
    public override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)
        
        // Draw text
        for (i, c) in candidates.enumerated() {
            let frame = itemFrames[i]
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.label
            ]
            (c as NSString).draw(in: frame, withAttributes: attrs)
        }
    }
    
    private func updateDragOffset(with localX: CGFloat) {

        let keyMidX = _t_rect.midX
        let rawOffset = localX - keyMidX

        // 最大允许偏移（系统级）
        let maxOffset: CGFloat = 24

        dragOffsetX = max(-maxOffset, min(rawOffset, maxOffset))
        // 边缘键的自动抑制(防抖)
        if _key_position == .leftEdge {
            dragOffsetX = max(0, dragOffsetX)
        }
        if _key_position == .rightEdge {
            dragOffsetX = min(0, dragOffsetX)
        }
        
        updateShapePath(animated: false)
    }

    private func highlightRect(for itemFrame: CGRect) -> CGRect {
        
        var rect = itemFrame.inset(by: highlightInset)

        // 🔥 吸附到 popup 内部（关键）
        let safeBounds = bounds.insetBy(dx: 4, dy: 4)
        rect = rect.intersection(safeBounds)

        return rect
    }
    
    private func updateHighlight(animated: Bool) {

        guard selectedIndex < itemFrames.count else { return }

        let targetRect = highlightRect(for: itemFrames[selectedIndex])
        let path = UIBezierPath(roundedRect: targetRect, cornerRadius: 6)

        if animated {
            animateHighlight(to: path)
        } else {
            highlightLayer.path = path.cgPath
            highlightLayer.opacity = 1
        }
    }
    
    private func animateHighlight(to path: UIBezierPath) {

        let anim = CABasicAnimation(keyPath: "path")
        anim.fromValue = highlightLayer.path
        anim.toValue = path.cgPath
        anim.duration = 0.12
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false

        highlightLayer.add(anim, forKey: "highlightPath")
        highlightLayer.path = path.cgPath
        highlightLayer.opacity = 1
    }
    
    // MARK: - Selection update
    public func updateSelection(for pointInParent: CGPoint) {
        let local = convert(pointInParent, to: self)
        
        for (i, frame) in itemFrames.enumerated() {
            if frame.contains(local) {
                selectedIndex = i
                updateHighlight(animated: true)
                return
            }
        }
        
        // Nearest by X if not inside any frame
        let xs = itemFrames.map { $0.midX }
        if let nearest = xs.enumerated().min(by: { abs($0.element - local.x) < abs($1.element - local.x) }) {
            selectedIndex = nearest.offset
        }
        
        // 🔥 新增：更新 path 跟随
        updateDragOffset(with: local.x)
        // 🔥 新增：更新 高亮 跟随
        updateHighlight(animated: false)
    }

    public func commitSelection() -> String? {
        guard candidates.indices.contains(selectedIndex) else { return nil }
        return candidates[selectedIndex]
    }
    
    // touchesEnded/Paned 调用
    public func endTracking() {
        dragOffsetX = 0
        updateShapePath(animated: true)
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
}
