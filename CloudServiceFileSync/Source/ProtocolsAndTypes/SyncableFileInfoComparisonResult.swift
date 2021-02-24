//
//  SyncableFileInfo.swift
//  CloudSyncSandbox
//
//  Created by Stephen O'Connor on 17.02.21.
//

import Foundation

/// This struct represents the result of when you compare a remote file list with a local one
struct SyncableFileInfoComparisonResult {
    
    /// Files that haven't changed
    let filesUnchanged: [SyncableFileInfo]
    
    /// files that are newer than the remote and so need to be uploaded.
    let filesToUpload: [SyncableFileInfo] // FIXME: Make sure these get a localDataURL
    
    /// File infos that can be used to download remote data
    let filesToDownload: [SyncableFileInfo]
    
    /// Files that need to be removed locally
    let filesToDeleteLocally: [SyncableFileInfo] // FIXME: Make sure these get a localDataURL
    
    /// Files that need to be removed in the cloud
    let filesToDeleteOnRemote: [SyncableFileInfo]
    
    /// i.e. for your application, these are files present in the remote that have no relevance and should be ignored
    let invalidFiles: [SyncableFileInfo]
}

extension SyncableFileInfoComparisonResult {
    static var null: SyncableFileInfoComparisonResult {
        return SyncableFileInfoComparisonResult(filesUnchanged: [],
                                                filesToUpload: [],
                                                filesToDownload: [],
                                                filesToDeleteLocally: [],
                                                filesToDeleteOnRemote: [],
                                                invalidFiles: [])
    }
    
    var isNull: Bool {
        self.filesUnchanged.count == 0 &&
        self.filesToUpload.count == 0 &&
        self.filesToDownload.count == 0 &&
        self.filesToDeleteLocally.count == 0 &&
        self.filesToDeleteOnRemote.count == 0 &&
        self.invalidFiles.count == 0
    }
}
