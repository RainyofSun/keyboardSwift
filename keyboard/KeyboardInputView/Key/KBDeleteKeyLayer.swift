//
//  KBDeleteKeyLayer.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/16.
//

import UIKit
import AudioToolbox

class KBDeleteKeyLayer: KBBaseKeyLayer {

    private let symbolLayer = CAShapeLayer()

    var isEnabled: Bool = true {
        didSet { updateAppearance() }
    }

    override init(config: KBKeyLayerConfig) {
        super.init(config: config)
        setupIconLayer()
        updateAppearance()
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout

    override func layoutSublayers() {
        super.layoutSublayers()

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        symbolLayer.frame = bounds
        symbolLayer.path = deleteIconPath(in: bounds).cgPath

        CATransaction.commit()
    }
    
    override func applyStyle(animated: Bool) {
        super.applyStyle(animated: animated)

        let color = isDarkMode ? UIColor.white : UIColor.black
        symbolLayer.strokeColor = color.cgColor
        symbolLayer.fillColor = color.cgColor
    }
}

private extension KBDeleteKeyLayer {
    func setupIconLayer() {
        symbolLayer.contentsScale = UIScreen.main.scale
        symbolLayer.strokeColor = UIColor.label.cgColor
        symbolLayer.lineWidth = 1.8
        symbolLayer.lineCap = .round
        symbolLayer.lineJoin = .round

        addSublayer(symbolLayer)
    }
    
    func deleteIconPath(in rect: CGRect) -> UIBezierPath {

        let w = rect.width
        let h = rect.height

        // 整体高度（iOS 大约是 key 高度的 0.28）
        let iconHeight = h * 0.28
        let arrowWidth = iconHeight * 0.9
        let bodyWidth  = iconHeight * 1.4
        let corner: CGFloat = iconHeight * 0.22

        let center = CGPoint(x: w * 0.52, y: h * 0.5)

        let arrowLeftX = center.x - (arrowWidth + bodyWidth) * 0.5
        let bodyLeftX  = arrowLeftX + arrowWidth

        let topY = center.y - iconHeight * 0.5
        let bottomY = center.y + iconHeight * 0.5

        let path = UIBezierPath()

        // ───── 左侧三角箭头 ─────
        path.move(to: CGPoint(x: arrowLeftX, y: center.y))
        path.addLine(to: CGPoint(x: bodyLeftX, y: topY))
        path.addLine(to: CGPoint(x: bodyLeftX, y: bottomY))
        path.close()

        // ───── 右侧矩形 ─────
        let bodyRect = CGRect(
            x: bodyLeftX,
            y: topY,
            width: bodyWidth,
            height: iconHeight
        )

        path.append(UIBezierPath(
            roundedRect: bodyRect,
            cornerRadius: corner
        ))

        // ───── 中间的 X ─────
        let xInset = iconHeight * 0.28
        let xRect = bodyRect.insetBy(dx: xInset, dy: xInset)

        path.move(to: CGPoint(x: xRect.minX, y: xRect.minY))
        path.addLine(to: CGPoint(x: xRect.maxX, y: xRect.maxY))

        path.move(to: CGPoint(x: xRect.minX, y: xRect.maxY))
        path.addLine(to: CGPoint(x: xRect.maxX, y: xRect.minY))

        return path
    }
    
    func updateAppearance() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if isEnabled {
            backgroundColor = UIColor(white: 0.98, alpha: 1).cgColor
            symbolLayer.strokeColor = UIColor.label.cgColor
            opacity = 1.0
        } else {
            backgroundColor = UIColor(white: 0.9, alpha: 1).cgColor
            symbolLayer.strokeColor = UIColor.secondaryLabel.cgColor
            opacity = 0.55
        }

        CATransaction.commit()
    }
}

// MARK: - 删除键状态
enum DeleteKeyState {
    case idle
    case singleTap
    case longPress
    case acceleratedDelete
}

// MARK: - 删除键管理器
class DeleteKeyManager {
    static let shared = DeleteKeyManager()
    
    // MARK: - 配置参数
    private struct Configuration {
        // 删除时间间隔
        static let initialDelay: TimeInterval = 0.5          // 长按触发连续删除的初始延迟
        static let initialDeleteInterval: TimeInterval = 0.1 // 初始删除间隔
        static let acceleratedDeleteInterval: TimeInterval = 0.05 // 加速后删除间隔
        static let accelerationDelay: TimeInterval = 1.0     // 加速延迟时间
        
        // 删除声音
        static let enableDeleteSound: Bool = true
        static let deleteSoundID: SystemSoundID = 1155       // 标准键盘点击音
        
        // 触觉反馈
        static let enableHapticFeedback: Bool = true
    }
    
    // MARK: - 状态
    private var currentState: DeleteKeyState = .idle
    private var deleteTimer: Timer?
    private var lastDeleteTime: Date?
    private var longPressStartTime: Date?
    private var isAcceleratedMode: Bool = false
    
    // MARK: - 回调
    var onDeleteCharacter: (() -> Void)?
    var onDeleteWord: (() -> Void)?
    var onDeleteAll: (() -> Void)?
    
    // MARK: - 公共方法
    func handleTap() {
        // 立即删除一个字符
        deleteSingleCharacter()
        
        // 触觉反馈
        if Configuration.enableHapticFeedback {
            provideLightHapticFeedback()
        }
    }
    
    func handleLongPressBegan() {
        longPressStartTime = Date()
        currentState = .longPress
        
        // 延迟后开始连续删除
        DispatchQueue.main.asyncAfter(deadline: .now() + Configuration.initialDelay) { [weak self] in
            guard let self = self, self.currentState == .longPress else { return }
            self.startContinuousDeletion()
        }
    }
    
    func handleLongPressChanged(_ gesture: UILongPressGestureRecognizer) {
        // 可以在此处添加滑动删除单词的功能
        // 比如检测手势位置来判断是否要删除整个单词
    }
    
    func handleLongPressEnded() {
        stopContinuousDeletion()
        resetState()
    }
    
    func cancelAllOperations() {
        stopContinuousDeletion()
        resetState()
    }
    
    // MARK: - 私有方法
    private func deleteSingleCharacter() {
        // 播放删除音效
        if Configuration.enableDeleteSound {
            AudioServicesPlaySystemSound(Configuration.deleteSoundID)
        }
        
        // 执行删除回调
        onDeleteCharacter?()
        
        // 记录最后删除时间
        lastDeleteTime = Date()
    }
    
    private func startContinuousDeletion() {
        stopContinuousDeletion()
        
        // 先立即删除一个字符
        deleteSingleCharacter()
        
        // 启动定时器（初始速度）
        deleteTimer = Timer.scheduledTimer(withTimeInterval: Configuration.initialDeleteInterval,
                                          repeats: true) { [weak self] _ in
            self?.handleContinuousDeletion()
        }
        
        // 启动加速定时器
        DispatchQueue.main.asyncAfter(deadline: .now() + Configuration.accelerationDelay) { [weak self] in
            self?.enterAcceleratedMode()
        }
    }
    
    private func handleContinuousDeletion() {
        deleteSingleCharacter()
        
        // 检查是否需要进入加速模式
        if isAcceleratedMode && currentDeleteInterval() > Configuration.acceleratedDeleteInterval {
            restartTimerWithAcceleratedSpeed()
        }
    }
    
    private func enterAcceleratedMode() {
        guard currentState == .longPress else { return }
        
        isAcceleratedMode = true
        currentState = .acceleratedDelete
        
        // 触觉反馈表示进入加速模式
        if Configuration.enableHapticFeedback {
            provideMediumHapticFeedback()
        }
        
        restartTimerWithAcceleratedSpeed()
    }
    
    private func restartTimerWithAcceleratedSpeed() {
        deleteTimer?.invalidate()
        
        deleteTimer = Timer.scheduledTimer(withTimeInterval: Configuration.acceleratedDeleteInterval,
                                          repeats: true) { [weak self] _ in
            self?.deleteSingleCharacter()
        }
    }
    
    private func stopContinuousDeletion() {
        deleteTimer?.invalidate()
        deleteTimer = nil
        isAcceleratedMode = false
    }
    
    private func resetState() {
        currentState = .idle
        longPressStartTime = nil
        lastDeleteTime = nil
    }
    
    private func currentDeleteInterval() -> TimeInterval {
        if isAcceleratedMode {
            return Configuration.acceleratedDeleteInterval
        }
        return Configuration.initialDeleteInterval
    }
    
    // MARK: - 触觉反馈
    private func provideLightHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func provideMediumHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    deinit {
        deleteTimer?.invalidate()
    }
}
// MARK: - 智能文本删除
class SmartTextDeleter {
    
    // MARK: - 删除类型
    enum DeletionType {
        case character      // 删除一个字符
        case word          // 删除一个单词
        case line          // 删除一行
        case allToBeginning // 删除到开头
        case allToEnd      // 删除到结尾
    }
    
    // MARK: - 删除单个字符
    static func deleteCharacter(from text: String, at cursorPosition: Int) -> (newText: String, newCursorPosition: Int) {
        guard !text.isEmpty, cursorPosition > 0 else {
            return (text, cursorPosition)
        }
        
        var newText = text
        let startIndex = newText.index(newText.startIndex, offsetBy: cursorPosition - 1)
        let endIndex = newText.index(newText.startIndex, offsetBy: cursorPosition)
        newText.removeSubrange(startIndex..<endIndex)
        
        return (newText, cursorPosition - 1)
    }
    
    // MARK: - 删除单词（向前删除）
    static func deleteWord(from text: String, at cursorPosition: Int, language: String = "en") -> (newText: String, newCursorPosition: Int) {
        guard !text.isEmpty, cursorPosition > 0 else {
            return (text, cursorPosition)
        }
        
        var newText = text
        
        // 查找单词边界
        let textIndex = newText.index(newText.startIndex, offsetBy: cursorPosition - 1)
        let range = newText.startIndex..<textIndex
        
        // 向后查找单词起始位置
        let wordRange = findWordBoundary(in: newText, range: range, direction: .backward, language: language)
        
        // 删除单词
        newText.removeSubrange(wordRange)
        
        // 计算新的光标位置
        let newCursorPosition = newText.distance(from: newText.startIndex, to: wordRange.lowerBound)
        
        return (newText, newCursorPosition)
    }
    
    // MARK: - 删除单词（向后删除）
    static func deleteWordForward(from text: String, at cursorPosition: Int, language: String = "en") -> (newText: String, newCursorPosition: Int) {
        guard !text.isEmpty, cursorPosition < text.count else {
            return (text, cursorPosition)
        }
        
        var newText = text
        
        // 查找单词边界
        let textIndex = newText.index(newText.startIndex, offsetBy: cursorPosition)
        let range = textIndex..<newText.endIndex
        
        // 向前查找单词结束位置
        let wordRange = findWordBoundary(in: newText, range: range, direction: .forward, language: language)
        
        // 删除单词
        newText.removeSubrange(wordRange)
        
        // 光标位置不变（向前删除）
        return (newText, cursorPosition)
    }
    
    // MARK: - 删除到行首
    static func deleteToLineBeginning(from text: String, at cursorPosition: Int) -> (newText: String, newCursorPosition: Int) {
        guard !text.isEmpty, cursorPosition > 0 else {
            return (text, cursorPosition)
        }
        
        var newText = text
        
        // 查找最近的换行符
        let prefix = String(newText.prefix(cursorPosition))
        if let lastNewlineIndex = prefix.lastIndex(of: "\n") {
            let startIndex = newText.index(after: lastNewlineIndex)
            let endIndex = newText.index(newText.startIndex, offsetBy: cursorPosition)
            newText.removeSubrange(startIndex..<endIndex)
            
            let newCursorPosition = newText.distance(from: newText.startIndex, to: startIndex)
            return (newText, newCursorPosition)
        } else {
            // 没有换行符，删除到开头
            let startIndex = newText.startIndex
            let endIndex = newText.index(newText.startIndex, offsetBy: cursorPosition)
            newText.removeSubrange(startIndex..<endIndex)
            return (newText, 0)
        }
    }
    
    // MARK: - 删除到行尾
    static func deleteToLineEnd(from text: String, at cursorPosition: Int) -> (newText: String, newCursorPosition: Int) {
        guard !text.isEmpty, cursorPosition < text.count else {
            return (text, cursorPosition)
        }
        
        var newText = text
        
        // 查找下一个换行符
        let suffix = String(newText.suffix(from: newText.index(newText.startIndex, offsetBy: cursorPosition)))
        if let nextNewlineIndex = suffix.firstIndex(of: "\n") {
            let startIndex = newText.index(newText.startIndex, offsetBy: cursorPosition)
            let endIndex = newText.index(nextNewlineIndex, offsetBy: -text.count + cursorPosition)
            newText.removeSubrange(startIndex..<endIndex)
            return (newText, cursorPosition)
        } else {
            // 没有换行符，删除到结尾
            let startIndex = newText.index(newText.startIndex, offsetBy: cursorPosition)
            newText.removeSubrange(startIndex..<newText.endIndex)
            return (newText, cursorPosition)
        }
    }
    
    // MARK: - 查找单词边界
    private enum Direction {
        case forward
        case backward
    }
    
    private static func findWordBoundary(in text: String, range: Range<String.Index>,
                                        direction: Direction, language: String) -> Range<String.Index> {
        var currentIndex: String.Index
        
        switch direction {
        case .forward:
            currentIndex = range.lowerBound
            // 跳过空白字符
            while currentIndex < text.endIndex && text[currentIndex].isWhitespace {
                currentIndex = text.index(after: currentIndex)
            }
            
            // 找到单词结束位置
            while currentIndex < text.endIndex && !text[currentIndex].isWhitespace {
                currentIndex = text.index(after: currentIndex)
            }
            
            return range.lowerBound..<currentIndex
            
        case .backward:
            currentIndex = range.upperBound
            
            // 如果当前位置是空白，先跳过空白
            while currentIndex > text.startIndex {
                let prevIndex = text.index(before: currentIndex)
                if !text[prevIndex].isWhitespace {
                    break
                }
                currentIndex = prevIndex
            }
            
            // 找到单词开始位置
            while currentIndex > text.startIndex {
                let prevIndex = text.index(before: currentIndex)
                if text[prevIndex].isWhitespace {
                    break
                }
                currentIndex = prevIndex
            }
            
            return currentIndex..<range.upperBound
        }
    }
    
    // MARK: - 删除表情符号（特殊处理）
    static func deleteEmoji(from text: String, at cursorPosition: Int) -> (newText: String, newCursorPosition: Int) {
        guard !text.isEmpty, cursorPosition > 0 else {
            return (text, cursorPosition)
        }
        
        var newText = text
        let startIndex = newText.index(newText.startIndex, offsetBy: cursorPosition - 1)
        
        // 检查是否删除的是表情符号
        let char = newText[startIndex]
        
        // 简单判断：如果字符是emoji，可能需要删除多个字符
        if char.isEmoji {
            // 向前查找完整的emoji
            var emojiStartIndex = startIndex
            while emojiStartIndex > newText.startIndex {
                let prevIndex = newText.index(before: emojiStartIndex)
                if !newText[prevIndex].isEmoji {
                    break
                }
                emojiStartIndex = prevIndex
            }
            
            // 删除整个emoji
            newText.removeSubrange(emojiStartIndex...startIndex)
            let newCursorPosition = newText.distance(from: newText.startIndex, to: emojiStartIndex)
            return (newText, newCursorPosition)
        }
        
        // 不是emoji，正常删除一个字符
        return deleteCharacter(from: text, at: cursorPosition)
    }
}

// MARK: - Character扩展，用于检测Emoji
extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji
    }
}

// MARK: - 删除键视图
class DeleteKeyView: UIView {
    
    // MARK: - 属性
    private var deleteLayer: CAShapeLayer!
    var longPressGesture: UILongPressGestureRecognizer!
    var tapGesture: UITapGestureRecognizer!
    
    private let deleteIconSize: CGFloat = 22
    private let animationDuration: TimeInterval = 0.15
    
    var isEnabled: Bool = true {
        didSet {
            updateAppearance()
        }
    }
    
    var deleteAction: ((DeleteType) -> Void)?
    
    enum DeleteType {
        case character
        case word
        case all
    }
    
    // MARK: - 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func setup() {
        setupLayer()
        setupGestures()
        updateAppearance()
        
        // 配置删除管理器
        DeleteKeyManager.shared.onDeleteCharacter = { [weak self] in
            self?.handleDeleteCharacter()
        }
    }
    
    private func setupLayer() {
        // 背景层
        layer.cornerRadius = 5
        layer.masksToBounds = true
        
        // 删除图标层
        deleteLayer = CAShapeLayer()
        deleteLayer.frame = bounds
        deleteLayer.fillColor = UIColor.clear.cgColor
        deleteLayer.strokeColor = UIColor.black.cgColor
        deleteLayer.lineWidth = 2
        deleteLayer.lineCap = .round
        deleteLayer.lineJoin = .round
        
        let deletePath = createDeleteIconPath()
        deleteLayer.path = deletePath.cgPath
        
        layer.addSublayer(deleteLayer)
    }
    
    private func createDeleteIconPath() -> UIBezierPath {
        let path = UIBezierPath()
        
        // 绘制删除图标（左箭头 + X）
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let iconWidth = deleteIconSize
        let iconHeight = deleteIconSize
        
        // 箭头部分
        let arrowStart = CGPoint(x: center.x + iconWidth/3, y: center.y)
        let arrowEnd = CGPoint(x: center.x - iconWidth/3, y: center.y)
        let arrowControl = CGPoint(x: center.x - iconWidth/6, y: center.y - iconHeight/4)
        
        path.move(to: arrowStart)
        path.addQuadCurve(to: arrowEnd, controlPoint: arrowControl)
        
        // X的左侧
        let xLeftStart = CGPoint(x: center.x - iconWidth/4, y: center.y - iconHeight/6)
        let xLeftEnd = CGPoint(x: center.x - iconWidth/2, y: center.y - iconHeight/3)
        
        path.move(to: xLeftStart)
        path.addLine(to: xLeftEnd)
        
        // X的右侧
        let xRightStart = CGPoint(x: center.x - iconWidth/4, y: center.y - iconHeight/6)
        let xRightEnd = CGPoint(x: center.x, y: center.y - iconHeight/3)
        
        path.move(to: xRightStart)
        path.addLine(to: xRightEnd)
        
        return path
    }
    
    private func setupGestures() {
        // 轻击手势
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.numberOfTapsRequired = 1
        addGestureRecognizer(tapGesture)
        
        // 长按手势
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 0.1
        addGestureRecognizer(longPressGesture)
        
        // 防止冲突
        tapGesture.require(toFail: longPressGesture)
    }
    
    private func updateAppearance() {
        if isEnabled {
            backgroundColor = UIColor(white: 0.95, alpha: 1.0)
            deleteLayer.strokeColor = UIColor.black.cgColor
            alpha = 1.0
        } else {
            backgroundColor = UIColor(white: 0.85, alpha: 1.0)
            deleteLayer.strokeColor = UIColor.gray.cgColor
            alpha = 0.6
        }
    }
    
    // MARK: - 手势处理
    @objc private func handleTap() {
        guard isEnabled else { return }
        
        animateTap()
        DeleteKeyManager.shared.handleTap()
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard isEnabled else { return }
        
        switch gesture.state {
        case .began:
            animateLongPressBegan()
            DeleteKeyManager.shared.handleLongPressBegan()
            
        case .changed:
            DeleteKeyManager.shared.handleLongPressChanged(gesture)
            
        case .ended, .cancelled:
            animateLongPressEnded()
            DeleteKeyManager.shared.handleLongPressEnded()
            
        default:
            break
        }
    }
    
    // MARK: - 动画效果
    private func animateTap() {
        UIView.animate(withDuration: animationDuration * 0.5,
                      delay: 0,
                      options: [.curveEaseInOut],
                      animations: {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.backgroundColor = UIColor(white: 0.8, alpha: 1.0)
        }) { _ in
            UIView.animate(withDuration: self.animationDuration * 0.5,
                          delay: 0,
                          options: [.curveEaseInOut],
                          animations: {
                self.transform = .identity
                self.updateAppearance()
            })
        }
    }
    
    private func animateLongPressBegan() {
        UIView.animate(withDuration: animationDuration,
                      delay: 0,
                      options: [.curveEaseInOut],
                      animations: {
            self.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            self.backgroundColor = UIColor(white: 0.7, alpha: 1.0)
        })
        
        // 开始脉动动画
        startPulsingAnimation()
    }
    
    private func animateLongPressEnded() {
        stopPulsingAnimation()
        
        UIView.animate(withDuration: animationDuration,
                      delay: 0,
                      options: [.curveEaseInOut],
                      animations: {
            self.transform = .identity
            self.updateAppearance()
        })
    }
    
    private func startPulsingAnimation() {
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = 0.5
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 0.95
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        
        deleteLayer.add(pulseAnimation, forKey: "pulse")
    }
    
    private func stopPulsingAnimation() {
        deleteLayer.removeAnimation(forKey: "pulse")
    }
    
    // MARK: - 删除处理
    func handleDeleteCharacter() {
        deleteAction?(.character)
    }
    
    func handleDeleteWord() {
        deleteAction?(.word)
    }
    
    func handleDeleteAll() {
        deleteAction?(.all)
    }
    
    // MARK: - 布局
    override func layoutSubviews() {
        super.layoutSubviews()
        deleteLayer.frame = bounds
        
        // 更新删除图标路径
        let deletePath = createDeleteIconPath()
        deleteLayer.path = deletePath.cgPath
    }
}

// MARK: - 滑动删除单词手势
class SwipeDeleteGestureRecognizer: UIPanGestureRecognizer {
    
    enum SwipeDirection {
        case left
        case right
    }
    
    var swipeDirection: SwipeDirection = .left
    var minimumSwipeDistance: CGFloat = 50
    private var startLocation: CGPoint = .zero
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let touch = touches.first {
            startLocation = touch.location(in: view)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        guard let touch = touches.first else { return }
        let currentLocation = touch.location(in: view)
        
        let deltaX = currentLocation.x - startLocation.x
        let deltaY = currentLocation.y - startLocation.y
        
        // 只检测水平滑动，垂直移动不超过阈值
        if abs(deltaY) < 30 {
            if deltaX < -minimumSwipeDistance {
                swipeDirection = .left
                state = .ended
            } else if deltaX > minimumSwipeDistance {
                swipeDirection = .right
                state = .ended
            }
        }
    }
}

// MARK: - 增强版删除键视图（支持滑动删除单词）
class EnhancedDeleteKeyView: DeleteKeyView {
    
    private var swipeGesture: SwipeDeleteGestureRecognizer!
    private var swipeIndicator: UIView!
    
    override func setup() {
        super.setup()
        setupSwipeGesture()
        setupSwipeIndicator()
    }
    
    private func setupSwipeGesture() {
        swipeGesture = SwipeDeleteGestureRecognizer(target: self, action: #selector(handleSwipe))
        swipeGesture.minimumSwipeDistance = 60
        addGestureRecognizer(swipeGesture)
        
        // 设置手势依赖关系
        tapGesture.require(toFail: swipeGesture)
        longPressGesture.require(toFail: swipeGesture)
    }
    
    private func setupSwipeIndicator() {
        swipeIndicator = UIView()
        swipeIndicator.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        swipeIndicator.layer.cornerRadius = 15
        swipeIndicator.isHidden = true
        addSubview(swipeIndicator)
    }
    
    @objc private func handleSwipe(_ gesture: SwipeDeleteGestureRecognizer) {
        guard isEnabled else { return }
        
        switch gesture.state {
        case .began:
            showSwipeIndicator()
            
        case .changed:
            updateSwipeIndicator(with: gesture)
            
        case .ended:
            hideSwipeIndicator()
            handleSwipeCompleted(gesture.swipeDirection)
            
        case .cancelled, .failed:
            hideSwipeIndicator()
            
        default:
            break
        }
    }
    
    private func showSwipeIndicator() {
        swipeIndicator.isHidden = false
        swipeIndicator.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        swipeIndicator.alpha = 0
        
        UIView.animate(withDuration: 0.2,
                      delay: 0,
                      options: [.curveEaseOut],
                      animations: {
            self.swipeIndicator.transform = .identity
            self.swipeIndicator.alpha = 1
        })
    }
    
    private func updateSwipeIndicator(with gesture: SwipeDeleteGestureRecognizer) {
        let translation = gesture.translation(in: self)
        
        // 计算指示器位置和大小
        let swipeDistance = abs(translation.x)
        let maxDistance: CGFloat = 120
        
        // 限制最大距离
        let normalizedDistance = min(swipeDistance, maxDistance)
        let scale = 1.0 + (normalizedDistance / maxDistance) * 0.5
        
        // 更新指示器
        swipeIndicator.bounds = CGRect(x: 0, y: 0, width: 30 * scale, height: 30 * scale)
        swipeIndicator.center = CGPoint(x: bounds.midX + translation.x * 0.7,
                                      y: bounds.midY)
        
        // 更新透明度
        let alpha = 0.3 + (normalizedDistance / maxDistance) * 0.7
        swipeIndicator.alpha = alpha
        
        // 更新颜色（根据方向）
        if translation.x < 0 {
            swipeIndicator.backgroundColor = UIColor.systemRed.withAlphaComponent(alpha)
        } else {
            swipeIndicator.backgroundColor = UIColor.systemBlue.withAlphaComponent(alpha)
        }
    }
    
    private func hideSwipeIndicator() {
        UIView.animate(withDuration: 0.2,
                      delay: 0,
                      options: [.curveEaseIn],
                      animations: {
            self.swipeIndicator.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.swipeIndicator.alpha = 0
        }) { _ in
            self.swipeIndicator.isHidden = true
        }
    }
    
    private func handleSwipeCompleted(_ direction: SwipeDeleteGestureRecognizer.SwipeDirection) {
        switch direction {
        case .left:
            // 向左滑动：删除单词
            handleDeleteWord()
//            provideHapticFeedback(for: .wordDeletion)
            
        case .right:
            // 向右滑动：删除到行首（或根据需求定义）
            handleDeleteAll()
//            provideHapticFeedback(for: .allDeletion)
        }
    }
    
    private func provideHapticFeedback(for action: DeleteType) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 更新滑动指示器位置
        swipeIndicator.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
}
