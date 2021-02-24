//
//  AppDelegate.swift
//  CloudSyncSandbox
//
//  Created by Stephen O'Connor on 11.02.21.
//

import UIKit
import SwiftyDropbox
import CloudServiceFileSync



@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
            
        let config = DropboxConfig.forApplication()
        config.initialize()
        

        return true
    }
    
    // MARK: - App Redirects
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        // IS IT A DROPBOX AUTHENTICATION REDIRECT??
        if url.absoluteString.hasPrefix("db-") {
            
            let oauthCompletion: DropboxOAuthCompletion = {
                if let authResult = $0 {
                    switch authResult {
                    case .success:
                        print("Success! User is logged into DropboxClientsManager.")
                    case .cancel:
                        print("Authorization flow was manually canceled by user!")
                    case .error(_, let description):
                        print("Error: \(String(describing: description))")
                    }
                }
            }
            let canHandleUrl = DropboxClientsManager.handleRedirectURL(url, completion: oauthCompletion)
            return canHandleUrl
            
        } else {
            //return AppDelegate.controller.importData(from: url)
            return false
        }
    }
}

