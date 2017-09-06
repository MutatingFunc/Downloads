//
//  DownloadManager.swift
//  Downloads
//
//  Created by James Froggatt on 08.06.2017.
//  Copyright © 2017 James Froggatt. All rights reserved.
//

import Foundation

import Additions

protocol DownloadCompletionHandler: AnyObject {
	func downloadCompleted(at index: Int, toTempPath tempPath: URL, preferredFilename: String)
}
protocol DownloadProgressView: ErrorView, DownloadCompletionHandler {
	func downloadBegan(at index: Int)
	func downloadPaused(at index: Int)
	func downloadResumed(at index: Int)
	func download(at index: Int, gotProgress progress: Double)
	func downloadCancelled(at index: Int)
	func downloadsCancelled()
}

class DownloadManager {
	private lazy var sessionDelegate: SessionDelegate = SessionDelegate(manager: self)
	private lazy var session: URLSession = URLSession(configuration: .background(withIdentifier: "Downloads"), delegate: self.sessionDelegate, delegateQueue: .current)
	
	private(set) var downloads: OrderedDictionary<URL, DownloadState> = [:]
	
	var backgroundEventCompletionHandler: (() -> ())?
	weak var completionHandler: DownloadCompletionHandler? = DownloadedFileManager.shared
	var view: DownloadProgressView? {
		get {return completionHandler as? DownloadProgressView}
		set {completionHandler = newValue}
	}
	private init() {
		//creates the session (which is lazy for self-referencing),
		//allowing handling of background tasks as soon as the shared instance is accessed;
		//also restores any ongoing downloads
		self.session.getTasksWithCompletionHandler {_, _, downloadTasks in
			DispatchQueue.main.async {
				for task in downloadTasks {
					if let url = task.originalRequest?.url, ¬self.downloads.keys.contains(url) {
						task.resume()
						self.downloads[url] = .active(task)
						self.view?.downloadBegan(at: self.downloads.endIndex-1)
					}
				}
			}
		}
	}
	static let shared = DownloadManager()
}

extension DownloadManager {
	@discardableResult func beginDownload(from urlString: String) -> Bool {
		let error = {_ = self.view?.showError($0, title: "Invalid URL")}
		guard ¬urlString.isEmpty else {error(""); return false}
		let urlString = urlString.contains("://")
			? urlString
			: "http://" + urlString
		guard let url = URL(string: urlString), ¬url.isFileURL && url.host ¬= nil else {error(urlString); return false}
		beginDownload(from: url)
		return true
	}
	func beginDownload(from url: URL) {
		guard ¬downloads.keys.contains(url) else {return}
		let task = session.downloadTask(with: url)
		downloads[url] = .active(task)
		task.resume()
		view?.downloadBegan(at: downloads.endIndex-1)
	}
	func pauseDownload(from url: URL) {
		guard let index = downloads.keys.index(of: url), let task = downloads[url]?.task else {return}
		downloads[url] = .suspending
		task.cancel(byProducingResumeData: {data in
			self.downloads[url] = .suspended(data)
		})
		view?.downloadPaused(at: index)
	}
	func resumeDownload(from url: URL) {
		guard let index = downloads.keys.index(of: url), case .suspended(let data)? = downloads[url] else {return}
		let task = data.map(session.downloadTask) ?? session.downloadTask(with: url)
		downloads[url] = .active(task)
		task.resume()
		view?.downloadResumed(at: index)
	}
	func cancelDownload(from url: URL) {
		guard let (index, download) = downloads.removeValue(forKey: url) else {return}
		download.task?.cancel()
		view?.downloadCancelled(at: index)
	}
	func cancelAll() {
		for (_, state) in self.downloads {state.task?.cancel()}
		self.downloads = [:]
		view?.downloadsCancelled()
	}
}

private extension DownloadManager {
	func downloadProgressed(task: URLSessionDownloadTask) {
		guard let index = downloads.index(where: {$0.value.task == task}) else {return}
		view?.download(at: index, gotProgress: task.fractionCompleted)
	}
	
	func downloadFailed(task: URLSessionTask, reason: String) {
		guard let index = downloads.index(where: {$0.value.task == task}) else {return}
		let url = downloads.keys[index]
		cancelDownload(from: url)
		view?.showError(url.absoluteString, title: "Download Failed - " + reason)
	}
	func downloadCompleted(task: URLSessionDownloadTask, tempPath: URL) {
		guard let index = downloads.index(where: {$0.value.task == task}) else {return}
		downloads.remove(at: index)
		let preferredFilename = Downloads.preferredFilename(for: task.response!)
		completionHandler?.downloadCompleted(at: index, toTempPath: tempPath, preferredFilename: preferredFilename)
	}
}

private class SessionDelegate: NSObject, URLSessionDownloadDelegate {
	unowned let manager: DownloadManager
	init(manager: DownloadManager) {
		self.manager = manager
	}
	
	var view: DownloadProgressView? {return manager.view}
	
	func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
		manager.downloadFailed(task: task, reason: "No Connection")
	}
	func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
		view?.showError(request.url?.absoluteString ?? "Unknown URL", title: "Redirected")
		completionHandler(request)
	}
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
		manager.downloadProgressed(task: downloadTask)
	}
	
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
		manager.downloadProgressed(task: downloadTask)
	}
	
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		manager.downloadCompleted(task: downloadTask, tempPath: location)
	}
	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		incrementBadge()
		if let error = error, ¬((error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled) {
			view?.showError(error, title: "Task Error")
		}
	}
	
	func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
		manager.backgroundEventCompletionHandler?()
		manager.backgroundEventCompletionHandler = nil
	}
	func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
		view?.showError(error, title: "Session Error")
	}
}
