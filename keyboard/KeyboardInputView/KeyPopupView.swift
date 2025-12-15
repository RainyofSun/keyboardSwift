//
//  KeyPopupView.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/4.
//

import UIKit

public class KeyPopupView: UIView {

    open var currentSelection: String {
        return candidates[selectedIndex]
    }
    
    private var candidates: [String]
    var selectedIndex: Int = 0 {
        didSet { setNeedsDisplay() }
    }

    public var cornerRadius: CGFloat = 10
    public var arrowHeight: CGFloat = 10
    public var arrowWidth: CGFloat = 20
    public var contentInset: UIEdgeInsets = .init(top: 8, left: 8, bottom: 8, right: 8)
    public var itemSpacing: CGFloat = 8
    public var font: UIFont = .systemFont(ofSize: 20)
    
    private var itemFrames: [CGRect] = []   // 每个候选的绘制区域
    
    public init(candidates: [String]) {
        self.candidates = candidates
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout popup position above/below key
    public func layout(pointingTo target: CGRect, in parent: UIView) {
        let totalWidth = calculateTotalWidth()
        let popupHeight: CGFloat = 44 + contentInset.top + contentInset.bottom + arrowHeight

        var x = target.midX - totalWidth / 2
        x = max(8, min(x, parent.bounds.width - totalWidth - 8))

        var y = target.minY - popupHeight - 6
        var placedAbove = true
        if y < parent.safeAreaInsets.top + 4 {
            y = target.maxY + 6
            placedAbove = false
        }

        frame = CGRect(x: x, y: y, width: totalWidth, height: popupHeight)
        setNeedsDisplay()

        let arrowCenterX = min(max(target.midX - frame.minX, arrowWidth/2 + 6),
                               frame.width - arrowWidth/2 - 6)

        layer.setValue(arrowCenterX, forKey: "arrowCenterX")
        layer.setValue(placedAbove, forKey: "placedAbove")

        layoutItemFrames()
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
        let centerY = (bounds.height - arrowHeight) / 2

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
    }

    // MARK: - Drawing bubble + arrow + text
    public override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)

        let placedAbove = (layer.value(forKey: "placedAbove") as? Bool) ?? true
        let arrowCenterX = (layer.value(forKey: "arrowCenterX") as? CGFloat) ?? rect.width/2

        let bubbleRect = CGRect(x: 0, y: placedAbove ? 0 : arrowHeight,
                                width: rect.width,
                                height: rect.height - arrowHeight)

        let path = UIBezierPath(roundedRect: bubbleRect, cornerRadius: cornerRadius)

        // arrow shape
        let arrowPath = UIBezierPath()
        if placedAbove {
            arrowPath.move(to: CGPoint(x: arrowCenterX - arrowWidth/2, y: bubbleRect.maxY))
            arrowPath.addLine(to: CGPoint(x: arrowCenterX, y: bubbleRect.maxY + arrowHeight))
            arrowPath.addLine(to: CGPoint(x: arrowCenterX + arrowWidth/2, y: bubbleRect.maxY))
        } else {
            arrowPath.move(to: CGPoint(x: arrowCenterX - arrowWidth/2, y: bubbleRect.minY))
            arrowPath.addLine(to: CGPoint(x: arrowCenterX, y: bubbleRect.minY - arrowHeight))
            arrowPath.addLine(to: CGPoint(x: arrowCenterX + arrowWidth/2, y: bubbleRect.minY))
        }

        path.append(arrowPath)

        UIColor.systemBackground.setFill()
        path.fill()

        // Draw highlight
        if selectedIndex < itemFrames.count {
            let selected = itemFrames[selectedIndex]
            let highlightRect = selected.insetBy(dx: -6, dy: -4)
            let highlightPath = UIBezierPath(roundedRect: highlightRect, cornerRadius: 6)
            UIColor.systemGray4.setFill()
            highlightPath.fill()
        }

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

    // MARK: - Selection update
    public func updateSelection(for pointInParent: CGPoint) {
        let local = convert(pointInParent, to: self)
        
        for (i, frame) in itemFrames.enumerated() {
            if frame.contains(local) {
                selectedIndex = i
                return
            }
        }
        
        // Nearest by X if not inside any frame
        let xs = itemFrames.map { $0.midX }
        if let nearest = xs.enumerated().min(by: { abs($0.element - local.x) < abs($1.element - local.x) }) {
            selectedIndex = nearest.offset
        }
    }

    public func commitSelection() -> String? {
        guard candidates.indices.contains(selectedIndex) else { return nil }
        return candidates[selectedIndex]
    }
}
