//
//  AppleCloudStorageExtensions.swift
//  CloudSyncSandboxTests
//
//  Created by Stephen O'Connor on 18.02.21.
//

import Foundation
@testable import CloudServiceFileSync


extension AppleCloudStorageController {
    
    func removeAllFilesInCloudFolder() {
        guard let rootURL = config.containerUrl else {
            return
        }
        
        let fm = FileManager.default
        if let filenames = try? fm.contentsOfDirectory(atPath: rootURL.path) {
            for filename in filenames {
                if (filename as NSString).pathExtension == "txt" {
                    let url = rootURL.appendingPathComponent(filename, isDirectory: false)
                    try? fm.removeItem(at: url)
                }
            }
        }
    }
}
