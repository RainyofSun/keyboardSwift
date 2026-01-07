//
//  KBCenteredTextLayer.swift
//  keyboard
//
//  Created by Yu Chen  on 2026/1/8.
//

import UIKit

struct KBCenteredTextDebugInfo {
    let containerBounds: CGRect
    let textFrame: CGRect
    let baselineY: CGFloat
    let ascenderY: CGFloat
    let descenderY: CGFloat
}

final class KBCenteredTextLayer: CALayer {

    // MARK: - Public API
    var text: String? {
        didSet { textLayer.string = text }
    }

    var font: UIFont = .systemFont(ofSize: 17) {
        didSet { updateFont() }
    }

    var textColor: UIColor = .label {
        didSet { textLayer.foregroundColor = textColor.cgColor }
    }

    var alignment: CATextLayerAlignmentMode = .center {
        didSet { textLayer.alignmentMode = alignment }
    }

    // MARK: - Private
    private let textLayer = CATextLayer()
    
    override init() {
        super.init()
        setup()
    }

    override init(layer: Any) {
        super.init(layer: layer)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        contentsScale = UIScreen.main.scale

        textLayer.contentsScale = UIScreen.main.scale
        textLayer.alignmentMode = .center
        textLayer.foregroundColor = UIColor.label.cgColor

        addSublayer(textLayer)
    }
    
    override func layoutSublayers() {
        super.layoutSublayers()
        layoutTextLayer()
    }

    private func layoutTextLayer() {
        let bounds = self.bounds

        let ascender = font.ascender
        let descender = font.descender
        let textHeight = ascender - descender

        let y = (bounds.height - textHeight) / 2 - descender

        textLayer.frame = CGRect(
            x: 0,
            y: y.rounded(.down),
            width: bounds.width,
            height: textHeight
        )
    }
    
    private func updateFont() {
        textLayer.font = font
        textLayer.fontSize = font.pointSize
        setNeedsLayout()
    }
}

extension KBCenteredTextLayer {

    var debugInfo: KBCenteredTextDebugInfo {
        let ascender = font.ascender
        let descender = font.descender
        let textHeight = ascender - descender

        let y = (bounds.height - textHeight) / 2 - descender

        let textFrame = CGRect(
            x: 0,
            y: y,
            width: bounds.width,
            height: textHeight
        )

        return KBCenteredTextDebugInfo(
            containerBounds: bounds,
            textFrame: textFrame,
            baselineY: y + ascender,
            ascenderY: y,
            descenderY: y + textHeight
        )
    }
}
