//
//  CloudServiceController.swift
//  CloudSyncSandbox
//
//  Created by Stephen O'Connor on 18.02.21.
//

import Foundation

// MARK: - Cloud Service Controller

public final class CloudServiceController: CloudServiceControllable {
    
    public let storageController: CloudStorageControlling
    public let fileHandler: AppFileHandling
    
    let worker = DispatchQueue(label: "com.hometeam.cloud.service")
    
    public required init(fileHandler: AppFileHandling, storageController: CloudStorageControlling) {
        self.storageController = storageController
        self.fileHandler = fileHandler
    }
    
    internal(set) public var isSyncing: Bool = false
    
    public func shouldBeginFullSync() -> Bool {
        return storageController.isReadyForSyncing
    }
    
    private func notify(progress: SyncProgressBlock?, status: String, details: String?, numExpected: Int, numComplete: Int) {
        guard let progress = progress else {
            return // nothing to do
        }
        
        DispatchQueue.main.async {
            progress(status, details, numExpected, numComplete)
        }
    }
    
    public func beginFullSync(progress: SyncProgressBlock?, completion: SyncCompletionBlock?) {
        
        notify(progress: progress, status: L10n.CloudServiceController.Sync.preparing, details: nil, numExpected: 0, numComplete: 0)
        
        let localFileInfos = self.fileHandler.knownFileInfos()
        self.syncCloudFolder(localFileInfos: localFileInfos, progress: progress, completion: completion)
    }
    
    /// The Core method of a sync with your cloud folder.  Here you provide the local file infos you are interested in syncing; for a full sync this would be for all of your data
    ///  but you have the opportunity to sync a subset of files, optionally providing 'identifier filters' that will only involve files on the remote that would correspond to the given filter strings.
    ///   This is relevant if you have multiple files representing your data type: perhaps a new file appeared on the remote that belongs to an object you are 'syncing'.   that's why you should provide
    ///   identifier filters
    /// - Parameters:
    ///   - localFileInfos: an array representing your local data that wants to be synced
    ///   - identifierFilters: In the case of syncing a smaller set of your data that likely relates to a `Syncable` object, provide the identifier(s) of those objects here.
    ///   - progress: A progress block for UI callbacks
    ///   - completion: A completion block when syncing has finished
    private func syncCloudFolder(localFileInfos: [SyncableFileInfo], identifierFilters: [String]? = nil, progress: SyncProgressBlock?, completion: SyncCompletionBlock?) {
        guard !self.isSyncing else {
            log.info("A full sync was triggered while it's currently running.  Ignoring...")
            return
        }
        
        // do a check for authentication state and bail out early if not.
        guard storageController.isAuthenticated, storageController.isReadyForSyncing else {
            
            let error: SyncError = {
                if !storageController.isAuthenticated {
                    return SyncError.initializationFailed(details: L10n.CloudServiceController.Sync.CouldNotBegin.auth)
                } else {
                    return SyncError.initializationFailed(details: L10n.CloudServiceController.Sync.CouldNotBegin.other)
                }
            }()
            
            DispatchQueue.main.async {
                completion?(false, [error])
            }
            return
        }
        
        self.isSyncing = true
        
        let cloudSync = DispatchQueue.global(qos: .utility)
        cloudSync.async { [unowned self] in
            
            storageController.listApplicationRootFolder(completionQueue: cloudSync) { [weak self] (remoteList, error) in
                guard let `self` = self else { return }
                var errorAccumulator: [Error] = []
                
                var remoteInfos = remoteList
                if let identifierFilters = identifierFilters, identifierFilters.count > 0 {
                    remoteInfos = remoteList.filter({ (fileInfo) -> Bool in
                        let idForFile = self.fileHandler.identifier(from: fileInfo)
                        return identifierFilters.contains(idForFile)
                    })
                }
                
                let comparison = self.compareFileInfos(remote: remoteInfos, local: localFileInfos, handling: self.fileHandler)
                errorAccumulator.append(contentsOf: comparison.errors)
                
                var numCompletedForProgress = 0
                let numExpectedForProgress = (
                    comparison.result.filesToDeleteLocally.count +
                    comparison.result.filesToDeleteOnRemote.count +
                    comparison.result.filesToUpload.count +
                    comparison.result.filesToDownload.count
                )
                
                guard !comparison.result.isNull else {
                    DispatchQueue.main.async {
                        completion?(false, errorAccumulator)
                    }
                    return
                }
                
                // next steps are to take care of the comparison result's arrays (completion group?)
                let fm = FileManager.default
                for info in comparison.result.filesToDeleteLocally {
                    
                    var success = false
                    if let dataURL = info.localDataURL, fm.fileExists(atPath: dataURL.path) {
                        
                        do {
                            try self.fileHandler.removeData(at: dataURL, belongingTo: info)
                            info.state = .deleted
                            success = true
                        } catch let e {
                            errorAccumulator.append(SyncError.fileManager(error: e))
                        }
                    }
                        
                    numCompletedForProgress += 1
                    let completed = numCompletedForProgress
                    self.notify(
                        progress: progress,
                        status: L10n.CloudServiceController.Sync.syncingFile,
                        details: L10n.CloudServiceController.Sync.Details.DeleteResult.Filename.success(info.filename, success ? L10n.Words.succeeded : L10n.Words.failed),
                        numExpected: numExpectedForProgress,
                        numComplete: completed
                    )
                    
                }
                
                let completionGroup = DispatchGroup()
                
                for info in comparison.result.filesToUpload {
                    completionGroup.enter()
                    self.fileHandler.prepareLocalDataURL(for: info)
                    self.storageController.uploadDataToRootFolder(info, overwrite: true, completionQueue: cloudSync) { (success, errors) in
                        if let errors = errors, errors.count > 0 {
                            errorAccumulator.append(contentsOf: errors)
                        } else {
                            info.state = .normal
                        }
                        
                        numCompletedForProgress += 1
                        let completed = numCompletedForProgress
                        self.notify(
                            progress: progress,
                            status: L10n.CloudServiceController.Sync.syncingFile,
                            details: L10n.CloudServiceController.Sync.Details.UploadResult.Filename.success(info.filename, success ? L10n.Words.succeeded : L10n.Words.failed),
                            numExpected: numExpectedForProgress,
                            numComplete: completed
                        )
                        
                        completionGroup.leave()
                    }
                }
                
                for info in comparison.result.filesToDownload {
                    completionGroup.enter()
                    self.storageController.downloadData(of: info, completionQueue: cloudSync) { (fileData, error) in
                        var success = true
                        if let error = error {
                            errorAccumulator.append(error)
                            success = false
                        }
                        
                        // sync helper helps determine where to put the data
                        // saves it to disk and sets the struct's localDataURL
                        if let data = fileData {
                            do {
                                try self.fileHandler.saveLocally(data, belongingTo: info)
                                info.state = .normal
                                info.isDirty = true
                                assert(info.localDataURL != nil, "Something went wrong with your AppFileHandling instance.  It should have set a localDataURL.")
                            } catch let e {
                                success = false
                                errorAccumulator.append(SyncError.fileManager(error: e))
                            }
                        }
                        
                        numCompletedForProgress += 1
                        let completed = numCompletedForProgress
                        self.notify(
                            progress: progress,
                            status: L10n.CloudServiceController.Sync.syncingFile,
                            details: L10n.CloudServiceController.Sync.Details.DownloadResult.Filename.success(info.filename, success ? L10n.Words.succeeded : L10n.Words.failed),
                            numExpected: numExpectedForProgress,
                            numComplete: completed
                        )
                        
                        completionGroup.leave()
                    }
                }
                
                for info in comparison.result.filesToDeleteOnRemote {
                    completionGroup.enter()
                    self.storageController.removeFromRootFolder(info, completionQueue: cloudSync ) { (success, errors) in
                        var success = true
                        if let errors = errors, errors.count > 0 {
                            errorAccumulator.append(contentsOf: errors)
                            success = false
                        } else {
                            
                            do {
                                // removed on remote, ensure it's gone locally too.
                                try self.fileHandler.removeData(at: info.localDataURL, belongingTo: info)
                                info.state = .deleted
                            } catch let e {
                                success = false
                                errorAccumulator.append(SyncError.fileManager(error: e))
                            }
                        }
                        
                        numCompletedForProgress += 1
                        let completed = numCompletedForProgress
                        self.notify(
                            progress: progress,
                            status: L10n.CloudServiceController.Sync.syncingFile,
                            details: L10n.CloudServiceController.Sync.Details.DeleteResult.Filename.success(info.filename, success ? L10n.Words.succeeded : L10n.Words.failed),
                            numExpected: numExpectedForProgress,
                            numComplete: completed
                        )
                        
                        completionGroup.leave()
                    }
                }
                
                completionGroup.notify(queue: self.worker) {
                    
                    // then you'll know that they're all in sync and you'll have a flat array of SyncableFileInfos again representing files that are now up-to-date
                    let syncedFiles = comparison.result.allSyncedInfos
                    
                    let isFull: Bool = {
                        if let identifiers = identifierFilters, identifiers.count > 0 {
                            return false
                        }
                        return true
                    }()
                    
                    self.fileHandler.updateDataStore(with: syncedFiles, entireDataModel: isFull) { (success, errors) in
                        DispatchQueue.main.async { [weak self] in
                            self?.isSyncing = false
                            completion?(success, errors)
                        }
                    }
                }
            }
        }
    }
    
    func compareFileInfos(remote: [SyncableFileInfo],
                          local: [SyncableFileInfo],
                          handling: AppFileHandling) -> (result: SyncableFileInfoComparisonResult, errors: [Error]) {
        
        let invalid = remote.filter { (info) -> Bool in
            return !handling.canHandleFile(with: info.filename)
        }
        
        var toBeDeletedLocally = remote.filter { (info) -> Bool in
                
            if handling.canHandleFile(with: info.filename) && info.state == .deleted {
                // These elements won't have their localDataURL set because they originated on remote
                // so see if we have the local variant
                if let localInfo = local.info(with: info.filename) {
                    info.localDataURL = localInfo.localDataURL
                    localInfo.state = .deleted
                }
                return true
            } else {
                return false
            }
        }
        
        let remotesToCompare = Set(remote.filter { (info) -> Bool in
            // we still need to work with any that aren't already marked invalid or to be deleted
            return !invalid.contains(info) && !toBeDeletedLocally.contains(info)
        })
        
        
        let toBeDeletedOnRemote = local.filter { (info) -> Bool in
            if info.state == .deleted {
                // These local elements might not have their remoteDataURL set because they originated on remote
                if let remoteInfo = remote.info(with: info.filename) {
                    info.remoteDataURL = remoteInfo.remoteDataURL
                }
                return true
            } else {
                return false
            }
        }
        
        var needingDownload = Set<SyncableFileInfo>()
        var needingUpload = Set<SyncableFileInfo>()
        var unchanged = Set<SyncableFileInfo>()
        
        for info in remotesToCompare {
            let localInfo = local.info(with: info.filename)
            
            if let localInfo = localInfo, localInfo.state == .deleted {
                // it's already in the delete on remote array and has been dealt with.
                // we do not want to add to up/download
                continue
            }
            
            let status = info.syncStatus(comparedToLocal: localInfo)
            switch status {
            case .localNewer:
                needingUpload.insert(localInfo!)
            case .remoteNewer:
                needingDownload.insert(info)
            case .synced:
                // if they're synced, then both are defined, and we can force unwrap here
                if localInfo!.state == .newOrUnsynced {
                    needingUpload.insert(localInfo!)
                } else if localInfo!.state == .normal {
                    unchanged.insert(localInfo!)
                }
            case .undetermined:
                log.info("Unexpected state.  Got undetermined file sync status and that doesn't make sense.")
            default:
                break
            }
        }
        
        // now I need to find any object whose filename isn't in remotesToCompare nor toBeDeletedOnRemote, and add those to the needingUpload.
        let remainingLocalFiles = local.filter { (localInfo) -> Bool in
            
            if remotesToCompare.contains(localInfo) {
                return false // already handled this.
            }
            
            if localInfo.state == .newOrUnsynced {
                return true
            }
            
            if localInfo.state == .normal {
                return true
            }
            
            if localInfo.state == .deleted {
                return false
            }
            
            return false
        }
        
        /// these are basically files that aren't known to the remote.  They most likely require upload
        for info in remainingLocalFiles {
            if info.state == .normal {
                // we delete it locally because it's not on the remote but it's status is not new
                toBeDeletedLocally.append(info)
            } else {
                needingUpload.insert(info)
            }
        }
        
        let result = SyncableFileInfoComparisonResult(filesUnchanged: Array(unchanged),
                                                      filesToUpload: Array(needingUpload),
                                                      filesToDownload: Array(needingDownload),
                                                      filesToDeleteLocally: toBeDeletedLocally,
                                                      filesToDeleteOnRemote: toBeDeletedOnRemote,
                                                      invalidFiles: invalid)
        
        return (result, [])
    }
    
    // you actually want to sync any files relating to the same identifier, in case new files were added
    public func sync(fileInfos: [SyncableFileInfo], completion: SyncCompletionBlock?) {
        // basically you want to sync a cloud folder, but filter by identifiers
        let groupedAndSorted = self.fileHandler.groupedAndSortedForSyncable(infos: fileInfos)
        let identifierFilters = Array(groupedAndSorted.keys)
        
        self.syncCloudFolder(localFileInfos: fileInfos, identifierFilters: identifierFilters, progress: nil, completion: completion)
    }
    
    public func delete(fileInfos fileInfosToDelete: [SyncableFileInfo], completion: SyncCompletionBlock?) {
     
        guard !self.isSyncing else {
            log.info("A full sync was triggered while it's currently running.  Ignoring...")
            return
        }
        
        // do a check for authentication state and bail out early if not.
        guard storageController.isAuthenticated, storageController.isReadyForSyncing else {
            
            let error: SyncError = {
                if !storageController.isAuthenticated {
                    return SyncError.initializationFailed(details: L10n.CloudServiceController.Sync.CouldNotBegin.auth)
                } else {
                    return SyncError.initializationFailed(details: L10n.CloudServiceController.Sync.CouldNotBegin.other)
                }
            }()
            
            DispatchQueue.main.async {
                completion?(false, [error])
            }
            return
        }
        
        let cloudSync = DispatchQueue.global(qos: .utility)
        cloudSync.async { [unowned self] in
            
            let completionGroup = DispatchGroup()
            var errorAccumulator: [Error] = []
            
            for info in fileInfosToDelete {
                completionGroup.enter()
                self.storageController.removeFromRootFolder(info, completionQueue: cloudSync ) { (success, errors) in
                    var success = true
                    if let errors = errors, errors.count > 0 {
                        errorAccumulator.append(contentsOf: errors)
                        success = false
                    } else {
                        
                        do {
                            // removed on remote, ensure it's gone locally too.
                            try self.fileHandler.removeData(at: info.localDataURL, belongingTo: info)
                            info.state = .deleted
                        } catch let e {
                            success = false
                            errorAccumulator.append(SyncError.fileManager(error: e))
                        }
                    }
                    
                    completionGroup.leave()
                }
            }
            
            // NOTE: Main Queue
            completionGroup.notify(queue: .main) {
                completion?(errorAccumulator.count == 0, errorAccumulator)
            }
        }
    }
    
    public func rename(_ changes: [(source: SyncableFileInfo, destination: SyncableFileInfo)], completion: SyncCompletionBlock?) {
        
        guard !self.isSyncing else {
            log.info("A full sync was triggered while it's currently running.  Ignoring...")
            return
        }
        
        // do a check for authentication state and bail out early if not.
        guard storageController.isAuthenticated, storageController.isReadyForSyncing else {
            
            let error: SyncError = {
                if !storageController.isAuthenticated {
                    return SyncError.initializationFailed(details: L10n.CloudServiceController.Sync.CouldNotBegin.auth)
                } else {
                    return SyncError.initializationFailed(details: L10n.CloudServiceController.Sync.CouldNotBegin.other)
                }
            }()
            
            DispatchQueue.main.async {
                completion?(false, [error])
            }
            return
        }
        
        let cloudSync = DispatchQueue.global(qos: .utility)
        cloudSync.async { [unowned self] in
            
            var errorAccumulator: [Error] = []
            
            self.storageController.renameInRootFolder(changes: changes, completionQueue: cloudSync) { (success, errors) in
                
                if let errors = errors, errors.count > 0 {
                    errorAccumulator.append(contentsOf: errors)
                    
                    DispatchQueue.main.async {
                        completion?(errorAccumulator.count == 0, errorAccumulator)
                    }
                    
                } else {
                    self.fileHandler.updateObjects(with: changes) { (updateSuccess, updateErrors) in
                        DispatchQueue.main.async {
                            completion?(updateSuccess, updateErrors)
                        }
                    }
                }
            }
        }
    }
    
    public func startService(completion: SyncCompletionBlock?) {
        
    }
    
    public func stopService() {
        
    }
}

fileprivate extension SyncableFileInfoComparisonResult {
    
    /// once we've done all the work with the object type SyncableFileInfo, we can use the SyncableFileInfoComparisonResult
    /// to get an array of all the files that are now in sync.
    /// You only call this after you've synced the files and can now re-constitute the objects
    var allSyncedInfos: [SyncableFileInfo] {
        var allSyncedInfos = self.filesToDownload + self.filesToUpload + self.filesUnchanged
        allSyncedInfos.sort { (a, b) -> Bool in
            return a.filename.caseInsensitiveCompare(b.filename) == .orderedAscending
        }
        return allSyncedInfos
    }
    
}
