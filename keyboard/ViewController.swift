//
//  ViewController.swift
//  keyboard
//
//  Created by 一刻 on 2025/12/4.
//

import UIKit

class ViewController: UIViewController {

    private lazy var textFiled = UITextField(frame: CGRect(origin: CGPointMake(30, 300), size: CGSizeMake(UIScreen.main.bounds.width - 60, 45)))
    private lazy var keyboardInputView = KBKeyboardView(frame: CGRectZero)
    
    private lazy var capView: UIView = UIView(frame: CGRect(x: 30, y: 500, width: 40, height: 45))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.textFiled.borderStyle = .roundedRect
        self.view.addSubview(textFiled)
        self.view.addSubview(self.capView)
        self.capView.layer.cornerRadius = 4
        self.capView.clipsToBounds = true
        self.capView.backgroundColor = UIColor.red
        
        self.textFiled.inputView = self.keyboardInputView
        self.textFiled.delegate = self
        self.keyboardInputView.keyboardDelegate = self
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
            self.textFiled.becomeFirstResponder()
        })
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.textFiled.resignFirstResponder()
    }
}

extension ViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.keyboardInputView.keyboardDidAppear()
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.keyboardInputView.keyboardDidDisappear()
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
