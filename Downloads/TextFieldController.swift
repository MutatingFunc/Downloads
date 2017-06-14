//
//  TextFieldController.swift
//  Downloads
//
//  Created by James Froggatt on 14.06.2017.
//  Copyright © 2017 James Froggatt. All rights reserved.
//

import UIKit

class TextFieldController: UIViewController {
	@IBOutlet private var promptLabel: UILabel!
	@IBOutlet private var textField: UITextField!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.presentationController?.containerView?.backgroundColor = .clear
		self.preferredContentSize =
			CGSize(width: 320, height: view.systemLayoutSizeFitting(.zero).height)
		textField.delegate = self
		textField.becomeFirstResponder()
	}
	
 var onReturn: (String) -> () = {_ in}
}

extension TextFieldController: UITextFieldDelegate {
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		onReturn(textField.text ?? "")
		self.dismiss(animated: true)
		return false
	}
}

extension TextFieldController: UIPopoverPresentationControllerDelegate {
	func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
		return .popover
	}
}
