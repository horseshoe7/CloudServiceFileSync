//
//  SyncableFileInfo.swift
//  CloudSyncSandbox
//
//  Created by Stephen O'Connor on 17.02.21.
//

import Foundation



public enum SyncableFileState {
    
    /// this could mean a newly created on device, or one that's not on the device and appeared on the remote
    case newOrUnsynced
    
    /// this refers to one that's likely already present on the remote/local
    case normal
    
    /// it's been deleted, so when you handle it, you should delete it.
    case deleted
}

/// You should see this type as a type you can pass across threads that ultimately is used to find NSManagedObjects
public class SyncableFileInfo: Hashable, CustomStringConvertible, NSCopying {
    
    public var description: String {
        return "Filename: \(self.filename)"
    }
    
    public var filename: String
    public var state: SyncableFileState
    public var updatedAt: Date
    
    /// if this is true, it means the data has been updated.  This is relevant when updating `Syncable` types with their component `SyncableFileInfo` counterparts.
    public var isDirty: Bool = false
    
    // optional
    public var fileSizeInBytes: UInt64?
    
    /// basically where the data from the cloud can be loaded from on the device.
    /// it should get set after you download its data or when you're preparing for upload.
    public var localDataURL: URL?
    /// basically where the data from the cloud can be downloaded from.  `nil` values do not mean it doesn't exist.  it's a convenience attribute that could otherwise be found in the `userInfo` property.
    public var remoteDataURL: URL?
    
    public static func ==(lhs: SyncableFileInfo, rhs: SyncableFileInfo) -> Bool {
        return lhs.filename == rhs.filename
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.filename)
    }
    
    public var userInfo: [String: AnyHashable]? = nil
    
    public init(filename: String,
                state: SyncableFileState,
                updatedAt: Date,
                localDataURL: URL?,
                remoteDataURL: URL?,
                fileSizeInBytes: UInt64? = nil,
                userInfo: [String : AnyHashable]? = nil) {
        self.filename = filename
        self.state = state
        self.updatedAt = updatedAt
        self.fileSizeInBytes = fileSizeInBytes
        self.localDataURL = localDataURL
        self.remoteDataURL = remoteDataURL
        self.userInfo = userInfo
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = SyncableFileInfo(filename: filename,
                                    state: state,
                                    updatedAt: updatedAt,
                                    localDataURL: self.localDataURL,
                                    remoteDataURL: self.remoteDataURL,
                                    fileSizeInBytes: self.fileSizeInBytes,
                                    userInfo: self.userInfo)
        return copy
    }
}

extension SyncableFileInfo {
    func syncStatus(comparedToRemote remoteInfo: SyncableFileInfo) -> SyncableFileStatus {
        
        guard self.filename == remoteInfo.filename else {
            return .undetermined
        }
        
        let deltaTimeUncertainty: TimeInterval = 1 // we say that 2 files updated within a second of each other are 'the same'
        let timeDifference = self.updatedAt.timeIntervalSince(remoteInfo.updatedAt)
        if abs(timeDifference) <= deltaTimeUncertainty {
            return .synced
        } else if timeDifference < 0 {
            // local is older
            return .remoteNewer(localExists: true)
        } else {
            // local is newer
            return .localNewer
        }
    }
    
    func syncStatus(comparedToLocal localInfo: SyncableFileInfo?) -> SyncableFileStatus {
        guard let local = localInfo else {
            return .remoteNewer(localExists: false)
        }
        guard self.filename == local.filename else {
            return .undetermined
        }
        
        let deltaTimeUncertainty: TimeInterval = 1 // we say that 2 files updated within a second of each other are 'the same'
        let timeDifference = self.updatedAt.timeIntervalSince(local.updatedAt)
        if abs(timeDifference) <= deltaTimeUncertainty {
            return .synced
        } else if timeDifference < 0 {
            // remote is older
            return .localNewer
        } else {
            // remote is newer
            return .remoteNewer(localExists: true)
        }
    }
}

extension Array where Element == SyncableFileInfo {
    
    func info(with filename: String) -> SyncableFileInfo? {
        return self.first { (info) -> Bool in
            return info.filename == filename
        }
    }
    
    @discardableResult
    mutating func removeInfo(with filename: String) -> SyncableFileInfo? {
        if let index = self.firstIndex(where: { (info) -> Bool in
            return info.filename == filename
        }) {
            let info = self[index]
            self.remove(at: index)
            return info
        }
        return nil
    }
}
