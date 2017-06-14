//
//  DownloadManager.swift
//  Downloads
//
//  Created by James Froggatt on 08.06.2017.
//  Copyright © 2017 James Froggatt. All rights reserved.
//

import Foundation

import Additions

protocol DownloadProgressView: ErrorView {
	func downloadBegan(at index: Int)
	func downloadPaused(at index: Int)
	func downloadResumed(at index: Int)
	func download(at index: Int, gotProgress progress: Double)
	func downloadCancelled(at index: Int)
	func downloadCompleted(at index: Int, toTempPath tempPath: URL, preferredFilename: String)
	func downloadsCancelled()
}

class DownloadManager {
	private lazy var sessionDelegate: SessionDelegate = SessionDelegate(manager: self)
	private lazy var session: URLSession = self.newSession()
	
	private(set) var downloads: OrderedDictionary<URL, DownloadState> = [:]
	
	weak var view: DownloadProgressView?
	init(view: DownloadProgressView) {
		self.view = view
	}
	
	func newSession() -> URLSession {
		return URLSession(configuration: .background(withIdentifier: "Downloads"), delegate: self.sessionDelegate, delegateQueue: .current)
	}
}

extension DownloadManager {
	func beginDownload(from urlString: String) {
		let error = {_ = self.view?.showError($0, title: "Invalid URL")}
		guard !urlString.isEmpty else {return error("")}
		let urlString = urlString.contains("://")
			? urlString
			: "http://" + urlString
		guard let url = URL(string: urlString) else {return error(urlString)}
		beginDownload(from: url)
	}
	func beginDownload(from url: URL) {
		guard !downloads.keys.contains(url) else {return}
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
		view?.downloadCompleted(at: index, toTempPath: tempPath, preferredFilename: preferredFilename)
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
		if let error = error, !((error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled) {
			view?.showError(error, title: "Task Error")
		}
	}
	func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
		view?.showError(error, title: "Session Error")
	}
}
