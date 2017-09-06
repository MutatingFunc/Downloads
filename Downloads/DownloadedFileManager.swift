//
//  DownloadedFileManager.swift
//  Downloads
//
//  Created by James Froggatt on 13.06.2017.
//  Copyright © 2017 James Froggatt. All rights reserved.
//

import Foundation

import Additions

private let fileManager = FileManager.default
private let documents = try! fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)

protocol DownloadedFileView: ErrorView {
	func fileImported(at index: Int)
	func fileDeleted(at index: Int)
	func filesDeleted()
}

class DownloadedFileManager {
	private(set) var files: [URL] = (try? fileManager.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil))?.filter{¬$0.hasDirectoryPath} ?? []
	
	weak var view: DownloadedFileView?
	private init() {}
	static let shared = DownloadedFileManager()
}

extension DownloadedFileManager {
	func importFile(from url: URL, preferredFilename: String?, copyingSource: Bool = false) {
		guard ¬self.files.contains(url) else {return}
		
		func importFile(from url: URL, to target: URL) throws {
			if copyingSource {
				try fileManager.copyItem(at: url, to: target)
			} else {
				try fileManager.moveItem(at: url, to: target)
			}
			self.files.append(target)
			view?.fileImported(at: self.files.endIndex-1)
		}
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
				if (try? importFile(from: url, to: target)) ¬= nil {
					return
				}
			}
			view?.showError("File named \"\(target.lastPathComponent)\" already exists", title: "Import Error")
		}
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

extension DownloadedFileManager: DownloadCompletionHandler {
	func downloadCompleted(at _: Int, toTempPath tempPath: URL, preferredFilename: String) {
		self.importFile(from: tempPath, preferredFilename: preferredFilename)
	}
}
