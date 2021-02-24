//
//  SwiftyDropboxExtensions.swift
//  CloudSyncSandbox
//
//  Created by Stephen O'Connor on 22.02.21.
//

import Foundation
import SwiftyDropbox


extension FilesRoutes {
    
    open func listRootFolder(includeDeleted: Bool = true,
                             dispatchQueue: DispatchQueue,
                             completionQueue: DispatchQueue,
                             completion: @escaping ((_ entries: Array<Files.Metadata>?, _ error: DropboxError?) -> Void)) {
        
        dispatchQueue.async { [unowned self] in
            
            self.listFolder(path: "",
                            recursive: false,
                            includeMediaInfo: false,
                            includeDeleted: includeDeleted,
                            includeHasExplicitSharedMembers: false).response(queue: completionQueue) {
                                (response: Files.ListFolderResult?, error: CallError<(Files.ListFolderError)>?) in
                                
                                if let result = response {
                                    if result.hasMore {
                                        let entries = result.entries
                                        dispatchQueue.async {
                                            self.listRootFolder(cursor: result.cursor,
                                                                includeDeleted: includeDeleted,
                                                                accumulatedEntries: entries,
                                                                dispatchQueue: dispatchQueue,
                                                                completionQueue: completionQueue,
                                                                completion: completion)
                                        }
                                    
                                    } else {
                                        completion(result.entries, nil)
                                    }
                                } else if let dbError = DropboxError(dropboxCallError: error) {
                                    completion(nil, dbError)
                                } else {
                                    completion(nil, DropboxError.unspecifiedFailure(filename: nil)) // or some other error
                                }
                            }
        }
    }
    
    private func listRootFolder(cursor: String,
                                includeDeleted: Bool,
                                accumulatedEntries: Array<Files.Metadata>,
                                dispatchQueue: DispatchQueue,
                                completionQueue: DispatchQueue,
                                completion:@escaping ((_ entries: Array<Files.Metadata>?,  _ error: DropboxError?) -> Void)) {
        
        dispatchQueue.async { [unowned self] in
            self.listFolderContinue(cursor: cursor).response(queue: completionQueue) { [unowned self] (_ response: Files.ListFolderResult?, error: CallError<(Files.ListFolderContinueError)>?) in
                
                if let result = response {
                    
                    var allEntries = accumulatedEntries
                    allEntries.append(contentsOf: result.entries)
                    
                    if result.hasMore {
                        dispatchQueue.async {
                            self.listRootFolder(cursor: result.cursor,
                                                includeDeleted: includeDeleted,
                                                accumulatedEntries: allEntries,
                                                dispatchQueue: dispatchQueue,
                                                completionQueue: completionQueue,
                                                completion: completion)
                        }
                        
                    } else {
                        completion(allEntries, nil)
                    }
                    
                } else if let dbError = DropboxError(dropboxCallError: error) {
                    completion(accumulatedEntries, dbError)
                } else {
                    completion(accumulatedEntries, DropboxError.unspecifiedFailure(filename: nil)) // or some other error
                }
            }
        }
    }
    
    open func getMetadata(of filenames: [String],
                          includeDeleted: Bool = true,
                          queue:DispatchQueue? = nil,
                          completion:@escaping ((_ entries: Array<Files.Metadata>, _ errors: [Error]?)->())) {
        
        let completionGroup = DispatchGroup()
        
        var results: [Files.Metadata] = []
        var errors: [Error] = []
        
        for filename in filenames {
            completionGroup.enter()
            
            self.getMetadata(path: "/\(filename)")
                .response(queue: queue,
                          completionHandler: { (metadata: (Files.Metadata)?, error: CallError<(Files.GetMetadataError)>?) in
                            
                            if let metadata = metadata {
                                
                                results.append(metadata)
                            }
                            else if let error = error {
                                
                                var fileNotFound = false
                                
                                switch error as CallError {
                                case let .routeError(box, _, _, _):
                                    
                                    let metadataError = box.unboxed
                                    switch metadataError {
                                    case .path(let lookupError):
                                        switch lookupError {
                                        case .notFound:
                                            // this is OK
                                            fileNotFound = true
                                        default:
                                            break
                                        }
                                    }
                                default:
                                    break
                                }
                                
                                if !fileNotFound {
                                    if let dbError = DropboxError(dropboxCallError: error) {
                                        errors.append(dbError)
                                    }
                                    
                                }
                            }
                            
                            completionGroup.leave()
                          })
        }
        
        completionGroup.notify(queue: queue == nil ? DispatchQueue.main : queue!) {
            completion(results, errors.count > 0 ? errors : nil)
        }
    }
}

let MetadataDictionaryKeyFilename = "filename"
let MetadataDictionaryKeyDeleted = "deleted"
let MetadataDictionaryKeyCreatedAt = "createdAt"
let MetadataDictionaryKeyUpdatedAt = "updatedAt"

/// NOTE:  Since interacting with the Dropbox API doesn't really deal with direct https URLs, all we ever need to know is the path.
/// Hence, we use fileURLs with the path to represent remote locations.

extension Files.FileMetadata {
    var fileInfo: SyncableFileInfo {
        let path = self.pathLower ?? self.name  // in this flat hierarchy implementation, pathLower and name should be the same
        
        return SyncableFileInfo(filename: self.name,
                                state: .normal,
                                updatedAt: self.clientModified,
                                localDataURL: nil,
                                remoteDataURL: URL(fileURLWithPath: path))
    }
}

extension Files.DeletedMetadata {
    var fileInfo: SyncableFileInfo {
        let path = self.pathLower ?? self.name  // in this flat hierarchy implementation, pathLower and name should be the same
        return SyncableFileInfo(filename: self.name,
                                state: .deleted,
                                updatedAt: Date.distantFuture, /* A deleted file will always be 'newer' than anything else */
                                localDataURL: nil,
                                remoteDataURL: URL(fileURLWithPath: path))
    }
}

extension Files.FolderMetadata {
    var fileInfo: SyncableFileInfo {
        let path = self.pathLower ?? self.name  // in this flat hierarchy implementation, pathLower and name should be the same
        return SyncableFileInfo(filename: self.name,
                                state: .normal,
                                updatedAt: Date.distantPast, /* Folders don't have creation dates. */
                                localDataURL: nil,
                                remoteDataURL: URL(fileURLWithPath: path))
    }
}
