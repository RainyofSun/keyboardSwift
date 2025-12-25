//
//  KeyPopupView.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/4.
//

import UIKit

public struct PopupGeometry {
    let path: CGPath
    let blurAlpha: CGFloat
    let highlightOpacity: Float
    let headOffsetX: CGFloat
}

public class KeyPopupView: UIView {

    // MARK: - Public
    public var selectedIndex: Int = 0
    
    public var currentSelection: String {
        layoutItems[selectedIndex].text
    }

    // MARK: - Private
    private var font: UIFont = .systemFont(ofSize: 20)
    private let candidates: [CandidateItem]
    private let keyPosition: KeyPosition

    private var layoutItems: [CandidateLayoutItem] = []
    private var textLayers: [CATextLayer] = []

    private let shapeLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()

    private let highlightInset = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)

    private var keyRect: CGRect = .zero
    
    // MARK: - Init
    init(candidates: [CandidateItem], keyPosition: KeyPosition, itemFont font: UIFont) {
        self.candidates = candidates
        self.keyPosition = keyPosition
        
        super.init(frame: .zero)
        self.font = font
        
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
    public func layout(pointingTo target: CGRect, popRect pRect: CGRect, candidateLayouts: [CandidateLayoutItem], in parent: UIView) {

        keyRect = target
        frame = pRect
        layoutItems.removeAll()
        layoutItems.append(contentsOf: candidateLayouts)
        
        layoutTextLayers()
        updateHighlight(animated: false)
    }

    public func apply(geometry: PopupGeometry) {
        shapeLayer.path = geometry.path
        shapeLayer.shadowPath = geometry.path
        self.alpha = geometry.blurAlpha
        highlightLayer.opacity = geometry.highlightOpacity
        shapeLayer.setAffineTransform(
            CGAffineTransform(translationX: geometry.headOffsetX, y: 0)
        )
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
}

private extension KeyPopupView {
    // MARK: - Text Layers
    func layoutTextLayers() {

        if textLayers.count != layoutItems.count {
            textLayers.forEach { $0.removeFromSuperlayer() }
            textLayers.removeAll()
        }
        
        layoutItems.forEach { (element: CandidateLayoutItem) in
            let layer = CATextLayer()
            layer.contentsScale = UIScreen.main.scale
            layer.alignmentMode = .center
            layer.foregroundColor = UIColor.label.cgColor
            layer.font = font
            layer.fontSize = font.pointSize
            layer.string = element.text
            layer.frame = element.frame
            self.layer.addSublayer(layer)
            textLayers.append(layer)
        }
    }
}

// MARK: - Animation
private extension KeyPopupView {
    func updateHighlight(animated: Bool) {

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
    
    func animatePath(
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
}
