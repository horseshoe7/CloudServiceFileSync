//
//  AppleCloudConfig.swift
//  CloudSyncSandbox
//
//  Created by Stephen O'Connor on 11.02.21.
//

import Foundation

public struct AppleCloudConfig {
    
    public init() { }
    
    public var containerUrl: URL? {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        return containerURL.appendingPathComponent("Documents")
    }
    
    public func initialize() {
        // check for container existence
        if let url = self.containerUrl, !FileManager.default.fileExists(atPath: url.path, isDirectory: nil) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            }
            catch {
                print(error.localizedDescription)
            }
        }
    }
}
