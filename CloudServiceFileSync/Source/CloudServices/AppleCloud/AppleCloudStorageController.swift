//
//  AppleCloudStorageController.swift
//  CloudSyncSandbox
//
//  Created by Stephen O'Connor on 17.02.21.
//

import Foundation
import UIKit

// MARK: - Cloud Storage Controller
public class AppleCloudStorageController: CloudStorageControlling {
    
    let config = AppleCloudConfig()
    
    public var presentingViewController: UIViewController?
    
    public required init(presentingViewController: UIViewController?) {
        self.presentingViewController = presentingViewController
        config.initialize()
    }
    
    public var isAuthenticated: Bool {
        return config.containerUrl != nil
    }
    
    public var isReadyForSyncing: Bool {
        return config.containerUrl != nil
    }
    
    public var serviceType: CloudServiceType { return .iCloud }
    
    public func listApplicationRootFolder(completionQueue: DispatchQueue, completion: @escaping ((_ fileList: [SyncableFileInfo], _ error: Error?) -> Void)) {
        guard let rootURL = config.containerUrl else {
            completionQueue.async {
                completion([], SyncError.initializationFailed(details: "Could not initalize the cloud service's local root directory"))
            }
            return
        }
        
        log.info("Listing iCloud Files at:\n\(rootURL.absoluteString)")
        
        do {
            let fm = FileManager.default
            let contents = try fm.contentsOfDirectory(at: rootURL,
                                                      includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey, .totalFileSizeKey, .nameKey],
                                                      options: [])
            
            let fileList = try contents.compactMap { (fileURL) -> SyncableFileInfo? in
                let attributes = try fm.attributesOfItem(atPath: fileURL.path) as NSDictionary
                guard let lastUpdated = attributes.fileModificationDate() else {
                    log.error("Could not get all required attributes from file at URL: \(fileURL)")
                    return nil
                }
                
                let sizeInBytes = attributes.fileSize()
                let filename = fileURL.lastPathComponent
                
                let fileInfo = SyncableFileInfo(filename: filename,
                                                state: .normal,
                                                updatedAt: lastUpdated,
                                                localDataURL: nil,
                                                remoteDataURL: fileURL,
                                                fileSizeInBytes: sizeInBytes,
                                                userInfo: nil)
                return fileInfo
            }
            
            completionQueue.async {
                completion(fileList, nil)
            }
            
            
        } catch let e {
            log.error(e.localizedDescription)
            completionQueue.async {
                completion([], e)
            }
        }
    }
    
    public func uploadDataToRootFolder(_ fileInfo: SyncableFileInfo,
                                       overwrite: Bool,
                                       completionQueue: DispatchQueue,
                                       completion: @escaping SyncCompletionBlock) {
        guard let rootURL = config.containerUrl else {
            completionQueue.async {
                completion(false, [SyncError.initializationFailed(details: "Could not initalize the cloud service's local root directory")])
            }
            return
        }
        
        guard let localDataURL = fileInfo.localDataURL else {
            completionQueue.async {
                completion(false, [SyncError.noContent(filename: fileInfo.filename)])
            }
            return
        }
        
        let fm = FileManager.default
        
        // first check for existence
        var syncErrors = [SyncError]()
        
        let writeURL = rootURL.appendingPathComponent(fileInfo.filename)
        guard !fm.fileExists(atPath: writeURL.path) && !overwrite else {
            syncErrors.append(SyncError.fileAlreadyExists(filename: fileInfo.filename))
            completionQueue.async {
                completion(false, syncErrors)
            }
            return
        }
        
        if !fm.fileExists(atPath: localDataURL.path) {
            syncErrors.append(SyncError.noContent(filename: fileInfo.filename))
        }
        
        guard syncErrors.count == 0 else {
            completionQueue.async {
                completion(false, syncErrors)
            }
            return
        }
        
        do {
            // then do it.
            let writeURL = rootURL.appendingPathComponent(fileInfo.filename)
            try fm.copyItem(at: localDataURL, to: writeURL) // we've already checked that there's no file at this location.
            
            completionQueue.async {
                completion(true, nil)
            }
            
        } catch let e {
            completionQueue.async {
                completion(false, [SyncError.fileManager(error: e)])
            }
        }
    }
    
    public func removeFromRootFolder(_ fileInfo: SyncableFileInfo,
                                     completionQueue: DispatchQueue,
                                     completion: @escaping SyncCompletionBlock) {
        guard let rootURL = config.containerUrl else {
            completionQueue.async {
                completion(false, [SyncError.initializationFailed(details: "Could not initalize the cloud service's local root directory")])
            }
            return
        }
        
        let fm = FileManager.default
        let fileURL = rootURL.appendingPathComponent(fileInfo.filename)
        
        // check to see if it's already removed / not there, then it's a no-op, job done.
        guard fm.fileExists(atPath: fileURL.path) else {
            completionQueue.async {
                completion(true, nil)  // No-op.  The file was already removed / desired result achieved.
                
            }
            return
        }
        
        do {
            try fm.removeItem(at: fileURL)
            
            completionQueue.async {
                completion(true, nil)  // No-op.  The file was already removed / desired result achieved.
            }
            
        } catch let e {
            completionQueue.async {
                completion(false, [SyncError.fileManager(error: e)])
            }
        }
    }
    
    public func downloadData(of fileInfo: SyncableFileInfo,
                             completionQueue: DispatchQueue,
                             completion: @escaping ((Data?, Error?) -> Void)) {
        
        guard let rootURL = config.containerUrl else {
            completionQueue.async {
                completion(nil, SyncError.initializationFailed(details: "Could not initalize the cloud service's local root directory"))
            }
            return
        }
        
        let fm = FileManager.default
        let fileURL = rootURL.appendingPathComponent(fileInfo.filename)
        guard let data = fm.contents(atPath: fileURL.path) else {
            completionQueue.async {
                completion(nil, SyncError.noContent(filename: fileInfo.filename))
            }
            return
        }
        
        completionQueue.async {
            completion(data, nil)
        }
    }
    
    public func renameInRootFolder(changes: [(source: SyncableFileInfo, destination: SyncableFileInfo)],
                            completionQueue: DispatchQueue,
                            completion: @escaping SyncCompletionBlock) {
        
        guard let rootURL = config.containerUrl else {
            completionQueue.async {
                completion(false, [SyncError.initializationFailed(details: "Could not initalize the cloud service's local root directory")])
            }
            return
        }
        
        let fm = FileManager.default
        var errors: [SyncError] = []
        for change in changes {
            let sourceURL = rootURL.appendingPathComponent(change.source.filename)
            let destinationURL = rootURL.appendingPathComponent(change.destination.filename)
            
            if !fm.fileExists(atPath: sourceURL.path) {
                errors.append(SyncError.noContent(filename: sourceURL.lastPathComponent))
            }
            
            if fm.fileExists(atPath: destinationURL.path) {
                errors.append(SyncError.fileAlreadyExists(filename: sourceURL.lastPathComponent))
            }
        }
        
        guard errors.count == 0 else {
            completionQueue.async {
                completion(false, errors)
            }
            return
        }
        
        do {
            for change in changes {
                let sourceURL = rootURL.appendingPathComponent(change.source.filename)
                let destinationURL = rootURL.appendingPathComponent(change.destination.filename)
                try fm.moveItem(at: sourceURL, to: destinationURL)
            }
            
        } catch let e {
            errors.append(SyncError.fileManager(error: e))
        }
        
        completionQueue.async {
            completion(errors.count == 0, errors)  // No-op.  The file was already removed / desired result achieved.
        }
    }
}
