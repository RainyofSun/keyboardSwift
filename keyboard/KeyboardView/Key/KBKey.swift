//
//  KBKey.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/4.
//

import UIKit

public enum KeyType {
    case character
    case backspace
    case shift
    case returnKey
    case space
    case special
}

public enum KeyPosition {
    case leftEdge
    case left
    case center
    case right
    case rightEdge
}

struct KBKey {
    /// 键 Id
    var keyId: String
    /// 键的区域
    var frame: CGRect = .zero
    /// 键的文字
    var keyLabel: String
    /// 长按候选
    var alternatives: [CandidateItem]?
    /// key类型
    var keyType: KeyType = .character
    /// key 的位置
    var keyLocation: KeyPosition = .center
    
    init(keyId: String, frame: CGRect = .zero, keyLabel: String, alternatives: [String]? = [], keyType: KeyType = .character, keyLocation location: KeyPosition = .center) {
        self.keyId = keyId
        self.frame = frame
        self.keyLabel = keyLabel
        self.alternatives = []
        alternatives?.forEach { (element: String) in
            self.alternatives?.append(CandidateItem(text: element))
        }
        self.keyType = keyType
        self.keyLocation = location
    }
}

struct KBKeyRow {
    /// 一行的键
    var keys: [KBKey] = []
    //---------- inset 永远是「keyWidth 的倍数」引擎负责把它转换成像素
    /// 左右同时缩进（推荐）
    var horizontalInset: CGFloat = 0
    /// 兼容特殊情况（可选）
    var leadingInset: CGFloat? = nil
    var trailingInset: CGFloat? = nil
    //---------- 
    /// 覆盖某些键的宽度
    var customWidthMultipliers: [String: CGFloat] = [:]
    
    init(keys: [KBKey], horizontalInset: CGFloat = 0, leadingInset: CGFloat? = nil, trailingInset: CGFloat? = nil, customWidthMultipliers: [String : CGFloat] = [:]) {
        self.keys = keys
        self.horizontalInset = horizontalInset
        self.leadingInset = leadingInset
        self.trailingInset = trailingInset
        self.customWidthMultipliers = customWidthMultipliers
    }
}

// 候选词模型
struct CandidateItem {
    let text: String
}

// 候选词布局模型
public struct CandidateLayoutItem {
    let text: String
    let frame: CGRect
}

struct KBSystemKeyColors {

    static let character = UIColor(white: 0.98, alpha: 1.0)
    static let function  = UIColor(white: 0.86, alpha: 1.0)

    static let characterPressed = UIColor(white: 0.75, alpha: 1.0)
    static let functionPressed  = UIColor(white: 0.70, alpha: 1.0)

    static let characterDark = UIColor(white: 0.18, alpha: 1.0)
    static let functionDark  = UIColor(white: 0.28, alpha: 1.0)
}
