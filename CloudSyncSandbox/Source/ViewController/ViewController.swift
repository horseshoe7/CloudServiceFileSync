//
//  ViewController.swift
//  CloudSyncSandbox
//
//  Created by Stephen O'Connor on 11.02.21.
//

import UIKit
import SwiftyDropbox
import CloudServiceFileSync

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if DropboxClientsManager.authorizedClient == nil {
            let scopeRequest = ScopeRequest(scopeType: .user, scopes: ["account_info.read"], includeGrantedScopes: true)
            DropboxClientsManager.authorizeFromControllerV2(
                UIApplication.shared,
                controller: self,
                loadingStatusDelegate: nil,
                openURL: { (url: URL) -> Void in UIApplication.shared.open(url) },
                scopeRequest: scopeRequest
            )
        }
        
        let appleConfig = AppleCloudConfig()
        appleConfig.initialize()
        
    }

    @IBAction
    private func pressedPickerButton(_ sender: Any?) {
        
    }

}

