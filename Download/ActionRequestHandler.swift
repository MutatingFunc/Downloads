//
//  ActionRequestHandler.swift
//  Download
//
//  Created by James Froggatt on 16.06.2017.
//  Copyright © 2017 James Froggatt. All rights reserved.
//

import UIKit
import MobileCoreServices

class ActionRequestHandler: NSObject, NSExtensionRequestHandling {
	
	var extensionContext: NSExtensionContext?
	
	func beginRequest(with context: NSExtensionContext) {
		self.extensionContext = context
		
		let itemProvider = context.inputItems.lazy
			.flatMap{($0 as? NSExtensionItem)?.attachments ?? []}
			.flatMap{$0 as? NSItemProvider}
			.first{$0.hasItemConformingToTypeIdentifier(String(kUTTypePropertyList))}
		
		if let itemProvider = itemProvider {
			itemProvider.loadItem(forTypeIdentifier: String(kUTTypePropertyList), options: nil, completionHandler: {dict, error in
				OperationQueue.main.addOperation {
					if let data = (dict as! [String: Any])[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any] {
						self.gotData(data)
					} else {
						self.done(url: nil)
					}
				}
			})
		} else {
			self.done(url: nil)
		}
	}
	
	func gotData(_ data: [String: Any]) {
		guard
			let source = data["URL"] as? String,
			(["http", "https"] as Set).contains(where: source.hasPrefix),
			let url = URL(string: "dl" + source)
		else {return done(url: nil)}
		done(url: url)
	}
	
	func done(url: URL?) {
		if let url = url {
			let resultsProvider = NSItemProvider(item: [NSExtensionJavaScriptFinalizeArgumentKey: ["URL": url.absoluteString]] as NSDictionary, typeIdentifier: String(kUTTypePropertyList))
			let resultsItem = NSExtensionItem()
			resultsItem.attachments = [resultsProvider]
			self.extensionContext!.completeRequest(returningItems: [resultsItem], completionHandler: nil)
		} else {
			self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
		}
		self.extensionContext = nil
	}
	
}

