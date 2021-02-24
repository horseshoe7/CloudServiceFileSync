//
//  TextFileHandler.swift
//  CloudSyncSandboxTests
//
//  Created by Stephen O'Connor on 17.02.21.
//

import Foundation
import CloudServiceFileSync

/// Basically a `AppFileHandling` implementation that also has basic (transient) storage.  This is for unit tests!
class TextFileManager: AppFileHandling {
    
    var textFiles: [String: TextFile] = [:]
    
    func canHandleFile(with filename: String) -> Bool {
        let fileExtension = (filename as NSString).pathExtension
        if fileExtension == "txt" {
            return true
        }
        return false
    }
    
    func knownFileInfos() -> [SyncableFileInfo] {
        
        let fileInfos: [SyncableFileInfo] = self.textFiles.values.reduce([]) { (accumulator, textFile) -> [SyncableFileInfo] in
            var accumulated = accumulator
            accumulated.append(contentsOf: textFile.fileInfos)
            return accumulated
        }
        return fileInfos
    }
    
    func prepareLocalDataURL(for fileInfo: SyncableFileInfo) {
        guard fileInfo.localDataURL != nil else {
            fatalError("It shouldn't be possible to have a TextFile without a localDataURL")
            //return // nothing to do
        }
    }
    
    func saveLocally(_ fileData: Data, belongingTo info: SyncableFileInfo) throws {
        let localDataURL = TextFile.tempStorageFolder.appendingPathComponent(info.filename)
        try fileData.write(to: localDataURL)
        info.localDataURL = localDataURL
        info.fileSizeInBytes = UInt64(fileData.count)
    }
    
    func removeData(at fileURL: URL?, belongingTo info: SyncableFileInfo) throws {
        
        if let fileURL = fileURL {
            let fm = FileManager.default
            if fm.fileExists(atPath: fileURL.path) {
                try fm.removeItem(at: fileURL)
            }
        }
        
        
        // we know that it's 1:1 file:syncable so we just need to get the identifier and remove that text file
        let parentId = self.identifier(from: info)
        self.textFiles[parentId] = nil
    }
    
    func updateObjects(with changes: [(source: SyncableFileInfo, destination: SyncableFileInfo)], completion: @escaping SyncCompletionBlock) {
        let fm = FileManager.default
        
        var errors: [SyncError] = []
        for change in changes {
            let sourceId = self.identifier(from: change.source)
            let destId = self.identifier(from: change.destination)
            
            // have to move file from source to dest, update fileInfos
            let sourceURL = TextFile.tempStorageFolder.appendingPathComponent(change.source.filename)
            let destURL = TextFile.tempStorageFolder.appendingPathComponent(change.destination.filename)
            
            do {
                
                if !fm.fileExists(atPath: sourceURL.path) {
                    throw SyncError.noContent(filename: change.source.filename)
                }
                
                if fm.fileExists(atPath: destURL.path) {
                    log.error("A file exists at the destination and will be overwritten.")
                    try fm.removeItem(at: destURL)
                }
                
                try fm.moveItem(at: sourceURL, to: destURL)
                
                let movedInfo = change.destination.copy() as! SyncableFileInfo
                movedInfo.localDataURL = destURL
                
                // then clean up the original
                self.textFiles[sourceId] = nil
                let movedFile = TextFile(fileInfos: [movedInfo], identifier: destId)
                self.textFiles[destId] = movedFile
                
            } catch let e {
                errors.append(SyncError.fileManager(error: e))
            }
        }
        
        completion(errors.count == 0, errors)
    }
    
    /// Note this can represent all the files in sync.  MAKE SURE YOU PASS entireDataModel = false if you pass a subset of your data into here, otherwise  it will make the store think that's all there is on the remote.
    func updateDataStore(with syncedFileInfos: [SyncableFileInfo], entireDataModel: Bool, completion: (_ success: Bool, _ errors: [Error]?) -> Void) {
        
        guard entireDataModel else {
            // TODO: Implement me!
            fatalError("Haven't implemented the case where it's not the entire data model")
        }
        
        // since in our case we have a 1:1 syncedFileInfo to TextFile mapping, we can
        let grouped = groupedAndSortedForSyncable(infos: syncedFileInfos)
        
        // have to determine which local ones aren't in syncedFileInfos and remove them
        if entireDataModel {
            let syncedIdentifiers = Array(grouped.keys)
            var textFileIdentifiersToRemove: [String] = []
            for identifier in textFiles.keys {
                if !syncedIdentifiers.contains(identifier) {
                    textFileIdentifiersToRemove.append(identifier)
                }
            }
            for identifier in textFileIdentifiersToRemove {
                if let textFileToDelete = textFiles[identifier] {
                    textFileToDelete.deleteLocalData()
                }
                textFiles[identifier] = nil  // this suffices for our simple purposes, but you should actually clean up the data on disk
            }
        }
        
        
        // then have to determine which syncedFileInfos are dirty, then update those
        for info in syncedFileInfos {
            if info.isDirty {
                let id = identifier(from: info)
                if var existing = textFiles[id] {
                    existing.fileInfos = [info]
                    textFiles[id] = existing
                } else {
                    let newFile = TextFile(fileInfos: [info], identifier: id)
                    textFiles[id] = newFile
                }
            }
        }
        completion(true, nil)
    }
    
    /// A preliminary step to create a `Syncable` instance.  From a list of file infos, you need to group them so to know how to associate them to a `Syncable`.
    /// - Parameter infos: A flat list of Files that needs to be grouped and sorted.
    /// - Returns: A dictionary with a `Syncable`'s identifier as a key, and the values being Arrays of `SyncableFileInfo` that will belong to that `Syncable`
    func groupedAndSortedForSyncable(infos: [SyncableFileInfo]) -> [String: [SyncableFileInfo]] {
        
        var grouping: [String: [SyncableFileInfo]] = [:]
        
        for info in infos {
            let identifier = self.identifier(from: info)
            var infos = grouping[identifier] ?? []
            infos.append(info)
            grouping[identifier] = infos
        }
        
        // now sort them all by filename
        let keys = grouping.keys
        for key in keys {
            grouping[key] = (grouping[key] ?? []).sorted(by: { (a, b) -> Bool in
                return a.filename.caseInsensitiveCompare(b.filename) == .orderedAscending
            })
        }
        return grouping
    }
    
    func identifier(from fileInfo: SyncableFileInfo) -> String {
        return (fileInfo.filename as NSString).deletingPathExtension
    }
}

// MARK: Testing Extensions
extension TextFileManager {
    
    @discardableResult
    func createLocalTextFile(filenameWithoutExtension: String? = nil, isNew: Bool = true, overwrite: Bool = true, creationDate: Date = Date()) throws -> TextFile {
        let textFile = try TextFile.createLocalTextFile(filenameWithoutExtension: filenameWithoutExtension, isNew: isNew, overwrite: overwrite, creationDate: creationDate)
        textFiles[textFile.identifier] = textFile
        return textFile
    }
    
    func clearFilesFromStorageFolder() {
        let syncables = Array(self.textFiles.values)
        for textFile in syncables {
            textFile.deleteLocalData()
        }
    }
}
