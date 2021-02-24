//
//  MockCloudStorageController.swift
//  CloudSyncSandboxTests
//
//  Created by Stephen O'Connor on 18.02.21.
//

import Foundation
import CloudServiceFileSync
import UIKit

class MockCloudStorageController: CloudStorageControlling {
    
    var files = Set<SyncableFileInfo>()
    
    var presentingViewController: UIViewController?
    
    required init(presentingViewController: UIViewController?) {
        self.presentingViewController = presentingViewController
    }
    
    var isAuthenticated: Bool { return true }
    var isReadyForSyncing: Bool { return true }
    var serviceType: CloudServiceType { return .none }
    
    let worker = DispatchQueue(label: "com.hometeam.cloud.mock.worker")
    
    let msDelay = 0 // milliseconds of delay to the mock controller responses
    
    func listApplicationRootFolder(completionQueue: DispatchQueue, completion: @escaping (([SyncableFileInfo], Error?) -> Void)) {
        self.worker.asyncAfter(deadline: .now() + .milliseconds(msDelay)) { [unowned self] in
            
            let sortedFiles = Array(self.files).sorted { (a, b) -> Bool in
                return a.filename.caseInsensitiveCompare(b.filename) == .orderedAscending
            }
            
            completionQueue.async {
                completion(sortedFiles, nil)
            }
        }
    }
    
    func downloadData(of fileInfo: SyncableFileInfo, completionQueue: DispatchQueue, completion: @escaping ((Data?, Error?) -> Void)) {
        self.worker.asyncAfter(deadline: .now() + .milliseconds(msDelay)) { [unowned self] in
            
            let fm = FileManager.default
            guard let file = self.files.remove(fileInfo),
                  let dataURL = file.remoteDataURL,
                  fm.fileExists(atPath: dataURL.path),
                  let data = fm.contents(atPath: dataURL.path) else {
                
                completionQueue.async {
                    completion(nil, SyncError.noContent(filename: fileInfo.filename))
                }
                return
            }
            
            // put it back
            self.files.insert(file)
            
            completionQueue.async {
                completion(data, nil)
            }
        }
    }
    
    func uploadDataToRootFolder(_ fileInfo: SyncableFileInfo, overwrite: Bool, completionQueue: DispatchQueue, completion: @escaping SyncCompletionBlock) {
        self.worker.asyncAfter(deadline: .now() + .milliseconds(msDelay)) { [unowned self] in
            
            let fm = FileManager.default
            guard let localURL = fileInfo.localDataURL,
                  fm.fileExists(atPath: localURL.path),
                  let data = fm.contents(atPath: localURL.path) else {
                
                completionQueue.async {
                    completion(false, [SyncError.noContent(filename: fileInfo.filename)])
                }
                return
            }
            
            do {
                let writeURL = self.rootURL.appendingPathComponent(fileInfo.filename)
                
                if !overwrite {
                    if fm.fileExists(atPath: writeURL.path) {
                        throw SyncError.fileAlreadyExists(filename: fileInfo.filename)
                    }
                }
                
                try data.write(to: writeURL)
                fileInfo.remoteDataURL = writeURL
                
                completionQueue.async {
                    completion(true, nil)
                }
                
            } catch let e as SyncError {
                completionQueue.async {
                    completion(false, [e])
                }
            } catch let e {
                completionQueue.async {
                    completion(false, [SyncError.fileManager(error: e)])
                }
            }
        }
    }
    
    func removeFromRootFolder(_ fileInfo: SyncableFileInfo, completionQueue: DispatchQueue, completion: @escaping SyncCompletionBlock) {
        self.worker.asyncAfter(deadline: .now() + .milliseconds(msDelay)) { [unowned self] in
            
            let fm = FileManager.default
            guard let file = self.files.remove(fileInfo),
                  let dataURL = file.remoteDataURL,
                  fm.fileExists(atPath: dataURL.path)  else {
                
                completionQueue.async {
                    completion(false, [SyncError.noContent(filename: fileInfo.filename)])
                }
                return
            }
            
            do {
            
                try fm.removeItem(at: dataURL)
                fileInfo.remoteDataURL = nil
                
                completionQueue.async {
                    completion(true, nil)
                }
                
            } catch let e {
                completionQueue.async {
                    completion(true, [SyncError.fileManager(error: e)])
                }
            }
        }
    }

    func renameInRootFolder(changes: [(source: SyncableFileInfo, destination: SyncableFileInfo)],
                            completionQueue: DispatchQueue,
                            completion: @escaping SyncCompletionBlock) {
        
        self.worker.asyncAfter(deadline: .now() + .milliseconds(msDelay)) { [unowned self] in
            
            let fm = FileManager.default
            var errors: [SyncError] = []
            
            for change in changes {
                
                // check if it exists
                if let source = self.files.remove(change.source), let dataURL = source.remoteDataURL, fm.fileExists(atPath: dataURL.path) {
                    // it exists.
                } else {
                    errors.append(SyncError.noContent(filename: change.source.filename))
                    continue
                }
                
                if let _ = self.files.remove(change.destination) {
                    errors.append(SyncError.fileAlreadyExists(filename: change.destination.filename))
                    continue
                }
            }
            
            guard errors.count == 0 else {
                completionQueue.async {
                    completion(false, errors)
                }
                return
            }
            
            // if we are here, you can theoretically make all the changes
            for change in changes {
                if let infoToChange = self.files.remove(change.source) {
                    infoToChange.filename = change.destination.filename
                    self.files.insert(infoToChange)
                }
            }
            
            completionQueue.async {
                completion(errors.count == 0, errors)  // No-op.  The file was already removed / desired result achieved.
            }
        }
    }
    
}

extension MockCloudStorageController {
    
    var rootURL: URL {
        let cachesDirectoryURL =
            try! FileManager.default.url(for: .cachesDirectory,
                                         in: .userDomainMask,
                                         appropriateFor: nil,
                                         create: false)
        
        log.info("Temp Storage Folder at: \(cachesDirectoryURL.absoluteString)")
        let rootURL = cachesDirectoryURL.appendingPathComponent("/MockCloudStorage/")
        
        if !FileManager.default.fileExists(atPath: rootURL.path, isDirectory: nil) {
            do {
                try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
            }
            catch {
                print(error.localizedDescription)
            }
        }
        return rootURL
    }
    
    /// A method for setting up tests.  It will move the data at localDataURL to remoteFileURL
    func addFileInfoToStorage(_ fileInfo: SyncableFileInfo) {
        
        guard let localURL = fileInfo.localDataURL else {
            fatalError("You need to provide a SyncableFileInfo with local data set!")
        }
        
        do {
            let writeURL = rootURL.appendingPathComponent(fileInfo.filename)
            let fm = FileManager.default
            if fm.fileExists(atPath: writeURL.path) {
                try fm.removeItem(at: writeURL)
            }
            try fm.copyItem(at: localURL, to: writeURL)
            fileInfo.remoteDataURL = writeURL
            files.insert(fileInfo)
        }
        catch let e {
            fatalError("Failed moving files \(e.localizedDescription)")
        }
    }
    
    /// typically used in a tearDown method
    func clearFilesFromStorageFolder() {
        let rootURL = self.rootURL
        do {
            try FileManager.default.removeItem(at: rootURL)
        } catch let e {
            log.error(e.localizedDescription)
        }
    }
}
