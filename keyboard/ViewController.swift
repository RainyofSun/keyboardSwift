//
//  ViewController.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/4.
//

import UIKit

class ViewController: UIViewController {

    private lazy var textFiled = UITextField(frame: CGRect(origin: CGPointMake(30, 300), size: CGSizeMake(UIScreen.main.bounds.width - 60, 45)))
    private lazy var keyboardInputView = KBKeyboardViewFull(frame: CGRect(origin: CGPointZero, size: CGSizeMake(UIScreen.main.bounds.width, 250)))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.textFiled.borderStyle = .roundedRect
        self.view.addSubview(textFiled)
        self.textFiled.inputView = self.keyboardInputView
        self.keyboardInputView.keyboardDelegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.textFiled.resignFirstResponder()
    }
}

extension ViewController: KeyboardViewProtocol {
    func didSelectedKeyCap(capText: String) {
        if let _t = self.textFiled.text {
            self.textFiled.text = _t + capText
        } else {
            self.textFiled.text = capText
        }
    }
    
    func deleteText() {
        
    }
}
