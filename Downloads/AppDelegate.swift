//
//  AppDelegate.swift
//  Downloads
//
//  Created by James Froggatt on 07.06.2017.
//  Copyright © 2017 James Froggatt. All rights reserved.
//

import UIKit

let notificationCategory = "Downloads"
let notificationMessage = "All Downloads complete"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?
	
	func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
		DownloadManager.shared.backgroundEventCompletionHandler = completionHandler
		let notification = UILocalNotification()
		if let settings = application.currentUserNotificationSettings?.types {
			notification.category = notificationCategory
			notification.alertBody = settings.contains(.alert) ? "Finished downloading" : nil
			notification.soundName = settings.contains(.sound) ? UILocalNotificationDefaultSoundName : nil
		}
		application.presentLocalNotificationNow(notification)
		completionHandler()
	}
	
	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
		var urlString = url.absoluteString
		if urlString.hasPrefix("dl") {
			urlString.removeFirst(2)
		}
		return DownloadManager.shared.beginDownload(from: urlString)
	}
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		let category = UIMutableUserNotificationCategory()
		category.identifier = notificationCategory
		let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: [category])
		application.registerUserNotificationSettings(settings)
		return true
	}

	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		DownloadedFileManager.shared.autoUpdates = false
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		DownloadedFileManager.shared.updateFiles()
		DownloadedFileManager.shared.autoUpdates = true
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		application.applicationIconBadgeNumber = 0
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}
}

