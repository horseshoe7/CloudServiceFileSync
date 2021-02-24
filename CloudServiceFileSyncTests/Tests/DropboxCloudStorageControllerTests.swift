//
//  DropboxCloudStorageController.swift
//  CloudSyncSandboxTests
//
//  Created by Stephen O'Connor on 22.02.21.
//

import XCTest
@testable import CloudServiceFileSync
import SwiftyDropbox

class DropboxCloudStorageControllerTests: AppleCloudStorageControllerTests {

    static let dropboxConfig = DropboxConfig.application()
    
    class override func setUp() {
        super.setUp()
        //DropboxClientsManager.setupWithAppKey(dropboxConfig.appKey)
    }
    
    override func setUpWithError() throws {
        
        cloudStorage = DropboxCloudStorageController(config: Self.dropboxConfig, presentingViewController: nil)
    }

    override func tearDownWithError() throws {
        
        //DropboxClientsManager.unlinkClients()
    }

}
