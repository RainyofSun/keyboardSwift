//
//  KBDebugOverlayContainerView.swift
//  keyboard
//
//  Created by Yu Chen  on 2025/12/28.
//

import UIKit

class KBDebugOverlayContainerView: UIView {

    private var popupOverlay: KBPopupDebugOverlayView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func addPopupDebugOverlayView() {
        let popupOverlay = KBPopupDebugOverlayView(frame: self.bounds)
        popupOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.addSubview(popupOverlay)
        self.popupOverlay = popupOverlay
    }
    
    public func updateSnapshot(snaps: KBPopupDebugSnapshot) {
        self.popupOverlay?.update(snapshot: snaps)
    }
}
