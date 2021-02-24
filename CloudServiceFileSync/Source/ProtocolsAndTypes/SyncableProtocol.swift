import Foundation


public protocol Syncable {
    
    // used for parsing
    static var supportedMIMETypes: [MimeType] { get }  // just use the filename to get this
    
    /// `Syncable`s are serialized/deserialized via their fileInfos, so you will typically need this initializer while syncing.
    /// Note: It is up to your sync helper to work out which files in your sync folder shall be grouped to create these.
    /// identifier is an optional parameter for overriding; one way or another, you should set identifier in your init method.
    init?(fileInfos: [SyncableFileInfo], identifier: String?)
    
    /// This array describes the object in terms of how it is serialized to files.  Since one object can be serialized to multiple files (consider pages in a book), it's done this way
    var fileInfos: [SyncableFileInfo] { get }
    
    /// Basically a String that can give context to the data object this Syncable will represent
    /// In most cases where an object can be serialized 1:1 with a file, makes the most sense to just have this be the filename.
    var identifier: String { get }
    
    /// The last time anything happened with this file, either created or updated.  Used with syncing logic
    /// you'll generally derive this from your 
    var updatedAt: Date { get }

    /// basically to pass an arbitrary payload around if you need that.
    var userInfo: [String: Any]? { get set }
}

public enum SyncableFileStatus: Equatable {
    
    case remoteNewer(localExists: Bool)
    case localNewer
    
    // timestamps are essentially the same.  Some cloud services don't allow you to modify the updatedAt on the remote,
    // so we allow a few seconds 'grace period'.
    case synced
    
    /// should almost never happen, but can also be returned if you compare 2 different files.
    case undetermined
}


public extension Syncable {
    
    var updatedAt: Date {
        var newest = Date.distantPast
        for info in self.fileInfos {
            if info.updatedAt.compare(newest) == .orderedDescending {
                newest = info.updatedAt
            }
        }
        return newest
    }
    
    func syncStatus(comparedToRemote remoteSyncable: Syncable) -> SyncableFileStatus {
        
        guard self.identifier == remoteSyncable.identifier else {
            return .undetermined
        }
        
        let deltaTimeUncertainty: TimeInterval = 1 // we say that 2 files updated within a second of each other are 'the same'
        let timeDifference = self.updatedAt.timeIntervalSince(remoteSyncable.updatedAt)
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
    
    func syncStatus(comparedToLocal localSyncable: Syncable?) -> SyncableFileStatus {
        guard let local = localSyncable else {
            return .remoteNewer(localExists: false)
        }
        guard self.identifier == local.identifier else {
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

public protocol RenameableSyncableFile: Syncable {
    var oldFilename: String? { get set }
}




