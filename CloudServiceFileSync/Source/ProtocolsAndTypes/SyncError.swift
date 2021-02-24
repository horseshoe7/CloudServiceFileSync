//
//  SyncError.swift
//  CloudSyncSandbox
//
//  Created by Stephen O'Connor on 15.02.21.
//

import Foundation

public enum SyncError: Error {
    
    /// if for example the pre-conditions for Cloud Sync to work are not met, this could be the result.
    /// actual use cases would be for example if you're not signed into iCloud.
    case initializationFailed(details: String)
    
    /// Likely will only happen if you haven't authenticated with the service yet.
    case notAuthenticated
    
    /// if you are performing an operation that expects there to be no file at a specific location but there is.
    case fileAlreadyExists(filename: String)
    
    /// You can't rename a file of one type to another.  This will only happen when trying to rename
    case differentFileTypes
    
    /// if you try to upload a file with no data, or the file doesn't exist in remote
    case noContent(filename: String)
    
    /// wraps an error thrown from FileManager APIs
    case fileManager(error: Error)
    
    /// to wrap error types specific to your cloud service
    case cloudService(error: Error)
    
    /// Just for situations that are unlikely to happen.
    case unexpected(details: String)
}
