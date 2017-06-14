//
//  DownloadedFileManager.swift
//  Downloads
//
//  Created by James Froggatt on 13.06.2017.
//  Copyright © 2017 James Froggatt. All rights reserved.
//

import Foundation

private let fileManager = FileManager.default
private let documents = try! fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)

protocol DownloadedFileView: ErrorView {
	func fileImported(at index: Int)
	func fileDeleted(at index: Int)
	func filesDeleted()
}

class DownloadedFileManager {
	private(set) var files: [URL] = (try? fileManager.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil)) ?? []
	
	weak var view: DownloadedFileView?
	init(view: DownloadedFileView) {
		self.view = view
	}
	
	func importFile(from url: URL, preferredFilename: String?) {
		guard !self.files.contains(url) else {return}
		let target = documents.appendingPathComponent(preferredFilename ?? url.lastPathComponent)
		do {
			try importFile(from: url, to: target)
		} catch {
			guard (error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == NSFileWriteFileExistsError else {
				view?.showError(error, title: "Import Error")
				return
			}
			let title = target.deletingPathExtension().lastPathComponent
			let ext = target.pathExtension
			for num in 2...99 {
				let target = documents.appendingPathComponent("\(title) \(num).\(ext)")
				if (try? importFile(from: url, to: target)) != nil {
					return
				}
			}
			view?.showError("File named \"\(target.lastPathComponent)\" already exists", title: "Import Error")
		}
	}
	private func importFile(from url: URL, to target: URL) throws {
		try fileManager.copyItem(at: url, to: target)
		self.files.append(target)
		view?.fileImported(at: self.files.endIndex-1)
	}
	func deleteFile(at url: URL) {
		guard let index = files.index(of: url) else {return}
		do {
			try fileManager.removeItem(at: url)
			files.remove(at: index)
			view?.fileDeleted(at: index)
		} catch {
			view?.showError(error, title: "Deletion Error")
		}
	}
	func deleteAll() {
		do {
			while let url = files.last {
				try fileManager.removeItem(at: url)
				files.removeLast()
			}
		} catch {
			view?.showError(error, title: "Deletion error")
		}
		view?.filesDeleted()
	}
}
