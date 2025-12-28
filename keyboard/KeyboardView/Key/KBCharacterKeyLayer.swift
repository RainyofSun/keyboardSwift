//
//  KBCharacterKeyLayer.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/16.
//

import UIKit

class KBCharacterKeyLayer: KBBaseKeyLayer {

    func updateDisplayedText(_ text: String) {
        textLayer?.string = text
    }
}
