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
    case delete
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
    var alternatives: [String]?
    /// key类型
    var keyType: KeyType = .character
    /// key 的位置
    var keyLocation: KeyPosition = .center
    
    init(keyId: String, frame: CGRect = .zero, keyLabel: String, alternatives: [String]? = [], keyType: KeyType = .character, keyLocation location: KeyPosition = .center) {
        self.keyId = keyId
        self.frame = frame
        self.keyLabel = keyLabel
        self.alternatives = alternatives
        self.keyType = keyType
        self.keyLocation = location
    }
}

struct KBKeyRow {
    /// 一行的键
    var keys: [KBKey] = []
    /// 可选的整行缩进
    var indent: CGFloat = 0
    /// 覆盖某些键的宽度
    var customWidthMultipliers: [String: CGFloat] = [:]
    
    init(keys: [KBKey], indent: CGFloat = 0, customWidthMultipliers: [String : CGFloat] = [:]) {
        self.keys = keys
        self.indent = indent
        self.customWidthMultipliers = customWidthMultipliers
    }
}

// 候选词模型
struct CandidateItem {
    let text: String
}

// 候选词布局模型
struct CandidateLayoutItem {
    let text: String
    let frame: CGRect
}
