//
//  Reusables.swift
//  Downloads
//
//  Created by James Froggatt on 14.06.2017.
//  Copyright © 2017 James Froggatt. All rights reserved.
//

import MobileCoreServices
import UIKit

enum Segue: String {case textEdit}

extension URLSessionTask {
	var fractionCompleted: Double {
		if #available(iOS 11, *) {
			return progress.fractionCompleted
		} else {
			return Double(countOfBytesReceived) / Double(countOfBytesExpectedToReceive)
		}
	}
}

protocol ErrorView: AnyObject {
	func showError(_ error: String, title: String)
}
extension ErrorView where Self: UIViewController {
	func showError(_ error: String, title: String) {
		UIAlertController(title: title, message: error, preferredStyle: .alert)
			.addAction("Dismiss", style: .cancel, handler: {_ in self.dismiss(animated: true, completion: nil)})
			.present(in: self, animated: true)
	}
}
extension ErrorView {
	func showError(_ error: Error?, title: String) {
		self.showError(error?.localizedDescription ?? "Unknown error", title: title)
	}
}

enum DownloadState {
	case active(URLSessionDownloadTask)
	case suspending
	case suspended(Data?)
	
	var task: URLSessionDownloadTask? {
		if case .active(let task) = self {return task}
		else {return nil}
	}
	var isActive: Bool {
		if case .active = self {return true}
		else {return false}
	}
}

func incrementBadge() {
	let app = UIApplication.shared
	if app.applicationState != .active {
		app.applicationIconBadgeNumber += 1
	}
}

func preferredFilename(for response: URLResponse) -> String {
	let queryInfo = response.url?.query.map(fileName(forQuery:))
	let title =
		queryInfo?.title
			?? response.suggestedFilename
			?? response.url?.lastPathComponent
			?? "file"
	return queryInfo?.ext.map{title + "." + $0} ?? title
}
private func fileName(forQuery query: String) -> (title: String?, ext: String?)  {
	let params = query.components(separatedBy: "&")
	var title: String?, ext: String?
	for param in params {
		if param.hasPrefix("title") || param.hasPrefix("name") {
			title = param.components(separatedBy: "=").last!.replacingOccurrences(of: "+", with: " ")
		} else if param.hasPrefix("mime") {
			var mime = param.components(separatedBy: "=").last!
			mime = mime.removingPercentEncoding ?? mime
			if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mime as CFString, nil)?.takeRetainedValue(),
				let preferredExt = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension)?.takeRetainedValue() {
				ext = preferredExt as String
			}
		}
	}
	return (title, ext)
}
