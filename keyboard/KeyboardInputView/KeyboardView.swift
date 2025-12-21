//
//  KeyboardView.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/4.
//

import UIKit



class KeyboardView: UIView {

    weak open var keyboardDelegate: KeyboardViewProtocol?
    
    private var layoutEngine: KBKeyLayoutEngine!
    private var rows: [KBKeyRow] = []
    private var keyboardType: KeyboardType = .letters
    var activeKey: KBKey?
    var activeTouchStartTime: CFTimeInterval?
    var longPressTimer: Timer?
    var isShowingPopup: Bool = false
    var popupPresenter: DefaultPopupPresenter = DefaultPopupPresenter()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .orange
        commonInit()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func commonInit() {
        popupPresenter.selectedCallback = {(text: String?) in
            print(text ?? "")
        }
        
        let provider = KBDefaultKeyboardProvider()
        layoutEngine = KBKeyLayoutEngine(keyboardWidth: bounds.width, keyboardHeight: bounds.height, rowHeight: 52, keySpacing: 6, sidePadding: 6, topPadding: 8, bottomPadding: 8, maxKeyWidth: 120, provider: provider as KeyboardLayoutProviding)
        reloadLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutEngine.keyboardWidth = bounds.width
        layoutEngine.keyboardHeight = bounds.height
        reloadLayout()
    }

    private func reloadLayout() {
        rows = layoutEngine.layout(for: keyboardType)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        for row in rows {
            for key in row.keys {
                // draw background
                let path = UIBezierPath(roundedRect: key.frame.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 6)
                UIColor(white: 0.95, alpha: 1).setFill()
                path.fill()
    
                // draw label
                let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 18), .foregroundColor:    UIColor.label]
                let size = key.keyLabel.size(withAttributes: attributes)
                let origin = CGPoint(x: key.frame.midX - size.width/2, y: key.frame.midY - size.height/2)
                key.keyLabel.draw(at: origin, withAttributes: attributes)
            }
        }
    }

    // touch handling: convert touch point to key by scanning rows
    private func key(at point: CGPoint) -> KBKey? {
        for row in rows {
            if let key = row.keys.first(where: { $0.frame.contains(point) }) {
                return key
            }
        }
        return nil
    }
}

extension KeyboardView {
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        guard let key = key(at: point) else { return }
        
        activeKey = key
        activeTouchStartTime = CACurrentMediaTime()
        
        // Schedule long press
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false, block: { [weak self] _ in
            self?.triggerLongPress()
        })
        
        setNeedsDisplay()
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        
        if isShowingPopup {
            popupPresenter.update(at: point)
            return
        }
        
        // Normal move: highlight whichever key finger is on
        if let newKey = key(at: point) {
            activeKey = newKey
        } else {
            activeKey = nil
        }
        setNeedsDisplay()
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate()
        
        guard let point = touches.first?.location(in: self) else {
            cleanupTouch()
            return
        }
        
        if isShowingPopup {
            popupPresenter.update(at: point)
            popupPresenter.hide()
            isShowingPopup = false
            popupPresenter.commit()
            cleanupTouch()
            return
        }
        
        // Normal tap
        if let key = key(at: point) {
            self.keyboardDelegate?.didSelectedKeyCap(capText: key.keyLabel)
        }
        
        cleanupTouch()
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cleanupTouch()
    }
    
    private func cleanupTouch() {
        activeKey = nil
        longPressTimer?.invalidate()
        longPressTimer = nil
        setNeedsDisplay()
    }
    
    private func triggerLongPress() {
        guard var key = activeKey else { return }
        key.alternatives = [CandidateItem(text: "1"), CandidateItem(text: "2")]
        guard key.alternatives?.isEmpty == false else {
            return
        }
        
        isShowingPopup = true
        popupPresenter.show(for: key, from: key.frame, in: self)
    }
}
