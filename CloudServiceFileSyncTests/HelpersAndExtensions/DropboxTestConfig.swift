//
//  DropboxTestConfig.swift
//  CloudSyncSandboxTests
//
//  Created by Stephen O'Connor on 23.02.21.
//

import Foundation
import SwiftyDropbox

struct DropboxTestConfig {
    
    static var client: DropboxClient {
        // If you get a compiler error it's because you need to declare these in a file that is not committed to source.
        let client = DropboxClient(accessToken: myAccountAccessToken, selectUser: myAccountUserEmail)
        return client
    }
}
