//
//  DropboxCredentials.swift
//  CloudSyncSandbox
//
//  Created by Stephen O'Connor on 22.02.21.
//

import Foundation
import SwiftyDropbox

public struct DropboxConfig {
    public let appKey: String
    public let secret: String
    
    public init(appKey: String, secret: String) {
        self.appKey = appKey
        self.secret = secret
    }
}

public extension DropboxConfig {
    func initialize() {
        DropboxClientsManager.setupWithAppKey(self.appKey)
    }
}



