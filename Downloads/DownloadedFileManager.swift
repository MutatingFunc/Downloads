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
	static func getFiles() -> [URL]? {
		return (try? fileManager.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil))?.filter{!$0.hasDirectoryPath}
	}
	private(set) var files: [URL] = getFiles() ?? []
	
	private func makeTimer() -> Timer? {
		if #available(iOS 10.0, *) {
			//only needs to run from iOS 11 onwards anyway, where the Files app is likely to change stuff
			return Timer.scheduledTimer(withTimeInterval: 3, repeats: true) {[weak self] _ in
				self?.updateFiles()
			}
		} else {return nil}
	}
	private var timer: Timer? {
		didSet {oldValue?.invalidate()}
	}
	var autoUpdates = false {
		didSet {timer = autoUpdates ? self.makeTimer() : nil}
	}
	weak var view: DownloadedFileView?
	private init() {}
	static let shared = DownloadedFileManager()
}

extension DownloadedFileManager {
	func importFile(from url: URL, preferredFilename: String?, copyingSource: Bool = false) {
		guard !self.files.contains(url) else {return}
		
		func importFile(from url: URL, to target: URL) throws {
			if copyingSource {
				try fileManager.copyItem(at: url, to: target)
			} else {
				try fileManager.moveItem(at: url, to: target)
			}
			self.files.append(target)
			view?.fileImported(at: self.files.endIndex-1)
		}
		let initialTarget = documents.appendingPathComponent(preferredFilename ?? url.lastPathComponent)
		let title = initialTarget.deletingPathExtension().lastPathComponent
		var target = initialTarget
		for num in 2...100 {
			do {
				try importFile(from: url, to: target)
				return
			} catch {
				guard (error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == NSFileWriteFileExistsError else {
					view?.showError(error, title: "Import Error")
					return
				}
				let ext = target.pathExtension
				target = documents.appendingPathComponent("\(title) \(num).\(ext)")
			}
		}
		view?.showError("File named \"\(initialTarget.lastPathComponent)\" already exists", title: "Import Error")
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
	
	func updateFiles() {
		guard let newFiles = DownloadedFileManager.getFiles().map(Set.init) else {return}
		let oldFiles = Set(self.files)
		for removed in oldFiles.subtracting(newFiles) {
			let index = files.index(of: removed)!
			self.files.remove(at: index)
			view?.fileDeleted(at: index)
		}
		for added in newFiles.subtracting(oldFiles) {
			let index = self.files.endIndex
			self.files.append(added)
			view?.fileImported(at: index)
		}
	}
}

extension DownloadedFileManager: DownloadCompletionHandler {
	func downloadCompleted(at _: Int, toTempPath tempPath: URL, preferredFilename: String) {
		self.importFile(from: tempPath, preferredFilename: preferredFilename)
	}
}
