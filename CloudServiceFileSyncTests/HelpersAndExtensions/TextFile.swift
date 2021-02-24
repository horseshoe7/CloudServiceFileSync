//
//  TextFile.swift
//  CloudSyncSandboxTests
//
//  Created by Stephen O'Connor on 17.02.21.
//

import Foundation
import CloudServiceFileSync

struct TextFile: Hashable, Syncable {
    
    static var supportedMIMETypes: [MimeType] = [MimeType(path: "OnlyTheExtensionMatters.txt")]
    
    static let tempStorageFolder: URL = {
        let cachesDirectoryURL =
            try! FileManager.default.url(for: .cachesDirectory,
                                         in: .userDomainMask,
                                         appropriateFor: nil,
                                         create: false)

        log.info("Temp Storage Folder at: \(cachesDirectoryURL.absoluteString)")
        return cachesDirectoryURL
    }()
    
    let identifier: String
    var fileInfos: [SyncableFileInfo]
    var userInfo: [String : Any]?
    
    init?(fileInfos: [SyncableFileInfo], identifier: String? = nil) {
        guard fileInfos.count == 1 else {
            return nil
        }
        if let id = identifier {
            self.identifier = id
        } else {
            self.identifier = (fileInfos.first!.filename as NSString).deletingPathExtension
        }
        
        self.fileInfos = fileInfos
    }
    
    static func ==(lhs: TextFile, rhs: TextFile) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.identifier)
    }
}

extension TextFile {
    
    /// creates a new file outside of any cloud container in the tempStorage folder and returns a URL to it.  Provide a name if you want to override a name, otherwise a UUID String will be used.
    /// - Parameters:
    ///   - filenameWithoutExtension: What you want the file to be named.  Do not include extension.  .txt will be added
    ///   - overwrite: whether it should overwrite if a file already exists
    /// - Throws: Will throw a `SyncError.fileAlreadyExists` if overwrite is set to false.  Otherwise does not throw
    /// - Returns: a TextFile representation to the file created.
    static func createLocalTextFile(filenameWithoutExtension: String? = nil, isNew: Bool = true, overwrite: Bool = true, creationDate: Date = Date()) throws -> TextFile {
        let content = "Well damn, if this ain't a text file!"
        let filename = "\(filenameWithoutExtension ?? UUID().uuidString).txt"
        let fm = FileManager.default
        
        let fileURL = Self.tempStorageFolder.appendingPathComponent(filename)
        if !overwrite {
            if fm.fileExists(atPath: fileURL.path) {
                throw SyncError.fileAlreadyExists(filename: filename)
            }
        }
        guard let fileData = content.data(using: .utf8) else {
            throw SyncError.unexpected(details: "Could not get data from the given content")
        }
        try fileData.write(to: fileURL)
        
        var attributes = try fm.attributesOfItem(atPath: fileURL.path)
        attributes[.creationDate] = creationDate
        try fm.setAttributes(attributes, ofItemAtPath: fileURL.path)
    
        let info = SyncableFileInfo(filename: filename,
                                    state: isNew ? .newOrUnsynced : .normal,
                                    updatedAt: creationDate,
                                    localDataURL: fileURL,
                                    remoteDataURL: nil,
                                    fileSizeInBytes: UInt64(fileData.count),
                                    userInfo: nil)
        
        let textFile = TextFile(fileInfos: [info])!
        
        return textFile
    }
}

extension TextFile {
    func deleteLocalData() {
        let fm = FileManager.default
        for info in self.fileInfos {
            if let url = info.localDataURL, fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
            }
        }
    }
}
