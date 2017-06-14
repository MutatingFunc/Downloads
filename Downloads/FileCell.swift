//
//  FileCell.swift
//  Downloads
//
//  Created by James Froggatt on 09.06.2017.
//  Copyright © 2017 James Froggatt. All rights reserved.
//

import UIKit
import AVKit

import Additions

typealias File = (title: String, url: URL)

protocol ShareDelegate: AnyObject {
	func shareFile(at url: URL, from view: UIView, keepingOriginal: Bool)
}
class FileCell: UICollectionViewCell, ReuseIdentifiable {
	@IBOutlet private(set) var imageView: UIImageView!
	@IBOutlet private var titleLabel: UILabel!
	
	var shareDelegate: ShareDelegate?
	
	var file: File? {
		didSet {
			imageView.image =
				file.flatMap{imagePreview(url: $0.url)}
				?? file.flatMap{videoPreview(url: $0.url)}
				?? #imageLiteral(resourceName: "Unknown file")
			titleLabel.text = file?.title ?? "Loading…"
		}
	}
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setup()
	}
	private func setup() {
		self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(share)))
	}
	
	@IBAction private func share() {
		guard let file = file else {return}
		shareDelegate?.shareFile(at: file.url, from: self, keepingOriginal: true)
	}
}

private func imagePreview(url: URL) -> UIImage? {
	return (try? Data(contentsOf: url)).flatMap(UIImage.init)
}
private func videoPreview(url: URL) -> UIImage? {
	let generator = AVAssetImageGenerator(asset: AVAsset(url: url))
	generator.appliesPreferredTrackTransform = true
	if let image = try? generator.copyCGImage(at: CMTime(value: 1, timescale: 60), actualTime: nil) {
		return UIImage(cgImage: image)
	}
	return nil
}
