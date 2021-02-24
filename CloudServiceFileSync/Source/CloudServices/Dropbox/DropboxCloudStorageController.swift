//
//  DropboxCloudStorageController.swift
//  CloudSyncSandbox
//
//  Created by Stephen O'Connor on 22.02.21.
//

import Foundation
import SwiftyDropbox
import UIKit


// MARK: - Cloud Storage Controller
public class DropboxCloudStorageController: CloudStorageControlling {
    
    let config: DropboxConfig
    let worker = DispatchQueue(label: "com.hometeam.cloud.dropbox.worker")
    
    public var presentingViewController: UIViewController?
    
    public init(config: DropboxConfig, presentingViewController: UIViewController?) {
        self.config = config
        self.presentingViewController = presentingViewController
        beginAuthorizationFlow()
    }
    
    public required init(presentingViewController: UIViewController?) {
        fatalError("Not a valid initializer.  Need to provide Dropbox credentials.  Use init(config:presentingViewController) instead.")
    }

    // MARK: - SwiftyDropbox considerations
    func beginAuthorizationFlow() {
        
        guard DropboxClientsManager.authorizedClient == nil else {
            return
        }
        
        let scopeRequest = ScopeRequest(scopeType: .user, scopes: ["account_info.read"], includeGrantedScopes: true)
        DropboxClientsManager.authorizeFromControllerV2(
            UIApplication.shared,
            controller: self.presentingViewController,
            loadingStatusDelegate: nil,
            openURL: { (url: URL) -> Void in UIApplication.shared.open(url) },
            scopeRequest: scopeRequest
        )
    }
    
    func logoutUser() {
        DropboxClientsManager.unlinkClients()
    }
    
    // MARK: - Protocol Support
    
    public var isAuthenticated: Bool {
        return DropboxClientsManager.authorizedClient != nil
    }
    
    public var isReadyForSyncing: Bool {
        return DropboxClientsManager.authorizedClient != nil
    }
    
    public var serviceType: CloudServiceType { return .dropbox }
    
    public func listApplicationRootFolder(completionQueue: DispatchQueue,
                                          completion: @escaping (([SyncableFileInfo], Error?) -> Void)) {
        guard let client = DropboxClientsManager.authorizedClient else {
            completionQueue.async {
                completion([], SyncError.notAuthenticated)
            }
            return
        }
        
        self.worker.async { [unowned self] in
            
            client.files.listRootFolder(includeDeleted: true,
                                        dispatchQueue: self.worker,
                                        completionQueue: completionQueue) {
                (files: Array<Files.Metadata>?, error: DropboxError?) in
                
                if let files = files {
                    let syncableFileInfos = files.compactMap { (metadata) -> SyncableFileInfo? in
                        if let file = metadata as? Files.FileMetadata {
                            return file.fileInfo
                        } else if let folder = metadata as? Files.FolderMetadata {
                            return folder.fileInfo
                        } else if let deleted = metadata as? Files.DeletedMetadata {
                            return deleted.fileInfo
                        } else {
                            return nil
                        }
                    }
                    
                    completion(syncableFileInfos, error)
                } else {
                    completion([], error)
                }
            }
        }
    }
    
    public func downloadData(of fileInfo: SyncableFileInfo,
                             completionQueue: DispatchQueue,
                             completion: @escaping ((Data?, Error?) -> Void)) {
        
        guard let client = DropboxClientsManager.authorizedClient else {
            completionQueue.async {
                completion(nil, SyncError.notAuthenticated)
            }
            return
        }
        self.worker.async {
            client.files.download(path: "/\(fileInfo.filename)")
                .response(queue: completionQueue) {
                    (result: (metadata: Files.FileMetadata, data: Data)?, error: CallError<Files.DownloadError>?) in
                    
                    if let error = error {
                        completion(result?.data, DropboxError(dropboxCallError: error))
                    } else {
                        completion(result?.data, nil)
                    }
                }
        }
    }
    
    public func uploadDataToRootFolder(_ fileInfo: SyncableFileInfo,
                                       overwrite: Bool,
                                       completionQueue: DispatchQueue,
                                       completion: @escaping SyncCompletionBlock) {
        
        guard DropboxClientsManager.authorizedClient != nil else {
            completionQueue.async {
                completion(false, [SyncError.notAuthenticated])
            }
            return
        }
        
        guard let fileUrl = fileInfo.localDataURL else {
            log.error("There was no data given at localDataURL, hence you can't upload anything.")
            completionQueue.async {
                completion(false, [SyncError.noContent(filename: fileInfo.filename)])
            }
            return
        }
        
        guard let uploadData = try? Data(contentsOf: fileUrl) else {
            log.error("Could not load data at given URL, hence you can't upload anything.  If this becomes a problem wrap in do-catch and get more info.")
            completionQueue.async {
                completion(false, [SyncError.noContent(filename: fileInfo.filename)])
            }
            return
        }
        
        self.worker.async { [unowned self] in
            
            self._autoRetryUpload(filename: fileInfo.filename,
                                  data: uploadData,
                                  clientModified: fileInfo.updatedAt,
                                  dispatchQueue: self.worker,
                                  completionQueue: completionQueue) {
                (success, errors) in
                
                if success {
                    fileInfo.state = .normal  // do we do this here?
                }
                
                completion(success, errors)
            }
        }
    }
    
    private func _autoRetryUpload(filename: String,
                                  data: Data,
                                  clientModified: Date,
                                  dispatchQueue: DispatchQueue,
                                  completionQueue: DispatchQueue,
                                  delayInSeconds: UInt64 = 0,
                                  completion: @escaping SyncCompletionBlock) {
        
        guard let client = DropboxClientsManager.authorizedClient else {
            completionQueue.async {
                completion(false, [SyncError.notAuthenticated])
            }
            return
        }
        
        // https://stackoverflow.com/a/37801602/421797
        dispatchQueue.asyncAfter(deadline: (.now() + Double(delayInSeconds))) { [unowned self] in
            client.files.upload(path: "/\(filename)",
                                mode: .overwrite,
                                autorename: false,
                                clientModified: clientModified,
                                mute: false,
                                input: data)
                .response(queue: dispatchQueue) {
                    (metadata: Files.FileMetadata?, error: CallError<Files.UploadError>?) in
  
                    if let error = error {
                        switch error {
                        case .rateLimitError(let rateLimitError, _, _, _):
                            let retryAfter = rateLimitError.retryAfter
                            log.error("Got a rate limit error while trying to upload \(filename).  Trying again in \(retryAfter)...")
                            self._autoRetryUpload(filename: filename,
                                                  data: data,
                                                  clientModified: clientModified,
                                                  dispatchQueue: dispatchQueue,
                                                  completionQueue: completionQueue,
                                                  delayInSeconds: retryAfter,
                                                  completion: completion)
                            return
                        default:
                            let dbError = DropboxError(dropboxCallError: error) ?? .unspecifiedFailure(filename: filename)
                            completionQueue.async {
                                completion(false, [dbError])
                            }
                            return
                        }
                    } else if let metadata = metadata {
                        
                        if clientModified.compare(metadata.clientModified) != .orderedSame {
                            log.info("Uploaded \(metadata.name).\nDate sent: \(clientModified)\nDate received\(metadata.clientModified)")
                        } else {
                            log.info("Uploaded \(metadata.name) successfully.")
                        }
                        
                        if delayInSeconds > 0 {
                            log.error("Uploaded \(filename) after retry.")
                        }
                        
                        completionQueue.async {
                            completion(true, nil) // not expected to happen
                        }
                        return
                        
                    } else {
                        completionQueue.async {
                            completion(false, [DropboxError.unspecifiedFailure(filename: filename)]) // not expected to happen
                        }
                        return
                    }
                }
        }
    }
    
    public func removeFromRootFolder(_ fileInfo: SyncableFileInfo,
                                     completionQueue: DispatchQueue,
                                     completion: @escaping SyncCompletionBlock) {
        
        guard let client = DropboxClientsManager.authorizedClient else {
            completionQueue.async {
                completion(false, [SyncError.notAuthenticated])
            }
            return
        }
        
        self.worker.async {
            client.files.deleteV2(path: "/\(fileInfo.filename)")
                .response(queue: completionQueue,
                          completionHandler: {
                            (result: Files.DeleteResult?, error: CallError<Files.DeleteError>?) in
                            
                            if let error = error {
                                log.error("Error deleting file \(fileInfo.filename): \(error.description)")
                                let dbError = DropboxError(dropboxCallError: error) ?? .unspecifiedFailure(filename: fileInfo.filename)
                                completion(false, [dbError])
                                
                            } else if let _ = result?.metadata {
                                //fileInfo.state = .deleted // gets handled by the CloudServiceController
                                completion(true, nil)
                                
                            } else {
                                completion(false, [DropboxError.unspecifiedFailure(filename: fileInfo.filename)]) // not likely to happen
                            }
             })
        }
    }
    
    public func renameInRootFolder(changes: [(source: SyncableFileInfo, destination: SyncableFileInfo)],
                                   completionQueue: DispatchQueue,
                                   completion: @escaping SyncCompletionBlock) {
        
        guard let client = DropboxClientsManager.authorizedClient else {
            completionQueue.async {
                completion(false, [SyncError.notAuthenticated])
            }
            return
        }
        
        // validate
        for change in changes {
            guard (change.source.filename as NSString).pathExtension == (change.destination.filename as NSString).pathExtension else {
                completionQueue.async {
                    completion(false, [SyncError.differentFileTypes])
                }
                return
            }
        }
        
        let group = DispatchGroup()
        var accumulatedErrors: [Error] = []
        
        for (source, destination) in changes {
            
            group.enter()
            
            client.files.moveV2(
                fromPath: "/\(source.filename)",
                toPath: "/\(destination.filename)")
                .response(queue: completionQueue) {
                    
                    (result:Files.RelocationResult?, error: CallError<Files.RelocationError>?) in
                    
                    if let metadata = result?.metadata {
                        
                        log.info("Renamed file: \(source.filename) to \(metadata.name)")
                    }
                    else if let error = error {
                        log.error("Error moving file \(source.filename): \(error.description)")
                        let dbError = DropboxError(dropboxCallError: error) ?? .unspecifiedFailure(filename: source.filename)
                        accumulatedErrors.append(dbError)
                    } else {
                        accumulatedErrors.append(DropboxError.unspecifiedFailure(filename: source.filename))
                    }
                    
                    group.leave()
                }
        }
        
        group.notify(queue: completionQueue) {
            completion(accumulatedErrors.count == 0, accumulatedErrors)
        }
    }
}
