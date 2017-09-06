//
//  DownloadCell.swift
//  Downloads
//
//  Created by James Froggatt on 08.06.2017.
//  Copyright © 2017 James Froggatt. All rights reserved.
//

import UIKit

import Additions

typealias Download = (title: String, url: URL)

protocol DownloadControlDelegate: AnyObject {
	func setPaused(_ paused: Bool, forDownloadFrom url: URL)
}

class DownloadCell: UICollectionViewCell, ReuseIdentifiable {
	@IBOutlet private var titleLabel: UILabel!
	@IBOutlet private var urlLabel: UILabel!
	@IBOutlet private var pauseButton: UIButton!
	@IBOutlet private var progressView: UIProgressView!
	
	weak var downloadDelegate: DownloadControlDelegate?
	
	var download: Download? {
		didSet {
			titleLabel.text = download?.title
			urlLabel.text = download?.url.absoluteString
			self.progress = nil
		}
	}
	
	var progress: Float? {
		get {
			return progressView.isHidden ? nil : progressView.progress
		}
		set {
			let newValue = download == nil ? nil : newValue
			progressView.isHidden = newValue == nil
			progressView.progress = newValue ?? 0
			pauseButton.setImage(newValue == nil ? #imageLiteral(resourceName: "Resume") : #imageLiteral(resourceName: "Pause"), for: [])
		}
	}
	
	@IBAction private func togglePaused() {
		guard let download = download else {return}
		downloadDelegate?.setPaused(progress ¬= nil, forDownloadFrom: download.url)
	}
}
