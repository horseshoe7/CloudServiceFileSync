//
//  CloudSyncControllerProtocol.swift
//  CloudSyncSandbox
//
//  Created by Stephen O'Connor on 15.02.21.
//

import Foundation
import UIKit



// MARK: - Storage Controller

public protocol CloudStorageControlling: class {
    /// if your cloud storage service needs to present something to the user, for example to authenticate, you need to provide a view controller it can present that from.
    /// An exception will be thrown if it is nil when something needs to be presented
    var presentingViewController: UIViewController? { get set }
    init(presentingViewController: UIViewController?)
    
    /// if the user is logged into the service
    var isAuthenticated: Bool { get }
    
    /// just because you are authenticated, doesn't mean you can sync.  So we make that distinction here.
    var isReadyForSyncing: Bool { get }
    
    /// The Name of the cloud service your instance will represent
    var serviceType: CloudServiceType { get }
    
    
    /// To get a list of files in one folder in your cloud sync folder
    /// - Parameters:
    ///   - completionQueue: The queue that this method should complete on, which is typically the queue that invoked this method.
    ///   - completion: A completion block that will handle the result
    func listApplicationRootFolder(completionQueue: DispatchQueue, completion: @escaping ((_ fileList: [SyncableFileInfo], _ error: Error?) -> Void))
    
    /// To download the data associated with a `SyncableFileInfo`
    /// - Parameters:
    ///   - fileInfo: the file you are interested in downloading
    ///   - completionQueue: The queue that this method should complete on, which is typically the queue that invoked this method.
    ///   - completion: A completion block that will handle the result
    func downloadData(of fileInfo: SyncableFileInfo, completionQueue: DispatchQueue, completion: @escaping ((_ data: Data?, _ error: Error?) -> Void))
    
    /// If you have data you want to upload to the cloud
    /// - Parameters:
    ///   - fileInfo: the file you are interested in downloading
    ///   - overwrite: whether it should overwrite at the destination or potentially throw an error if the file exists
    ///   - completionQueue: The queue that this method should complete on, which is typically the queue that invoked this method.
    ///   - completion: A completion block that will handle the result
    func uploadDataToRootFolder(_ fileInfo: SyncableFileInfo, overwrite: Bool, completionQueue: DispatchQueue, completion: @escaping SyncCompletionBlock)
    
    /// Remove a file from the Cloud folder
    /// - Parameters:
    ///   - fileInfo: the file you are interested in deleting
    ///   - completionQueue: The queue that this method should complete on, which is typically the queue that invoked this method.
    ///   - completion: A completion block that will handle the result
    func removeFromRootFolder(_ fileInfo: SyncableFileInfo, completionQueue: DispatchQueue, completion: @escaping SyncCompletionBlock)
    
    /// If you need to rename a file in the remote.  Could also be considered "moving" a file in the same folder, should you ever expand this code to work with folder hierarchies.
    /// It will first check if the renames are possible for all changes before performing the changes.  Meaning, it will only make changes if it seems likely to succeed for all.
    /// - Parameters:
    ///   - source: The File descriptor for the source file in the remote.  It will fail if it cannot be found
    ///   - destination: A descriptor that essentially is the same as the source, though with a different filename.  You are responsible for the new file name and whether that affects your `Syncable` type
    ///   - completionQueue: The queue that this method should complete on, which is typically the queue that invoked this method.
    ///   - completion: A completion block that will handle the result
    func renameInRootFolder(changes: [(source: SyncableFileInfo, destination: SyncableFileInfo)], completionQueue: DispatchQueue, completion: @escaping SyncCompletionBlock)
}


// MARK: - Types
public typealias SyncProgressBlock = (_ status: String, _ details: String?, _ numExpected: Int, _ numComplete: Int) -> Void
public typealias SyncCompletionBlock = (_ success: Bool, _ errors: [Error]?) -> Void

public enum CloudServiceType: Int {
    case none = 0
    case dropbox = 2  // note, these values should be these for legacy reasons!
    case iCloud = 1  // note, these values should be these for legacy reasons!
    
    var description: String {
        switch self {
        case .none:
            return "Cloud Services Inactive"
        case .dropbox:
            return "Dropbox"
        case .iCloud:
            return "iCloud"
        }
    }
}

let CloudServiceManagerNotificationServiceBecameAvailable = "CloudServiceManagerNotificationServiceBecameAvailable"
let CloudServiceManagerNotificationServiceLostAvailability = "CloudServiceManagerNotificationServiceLostAvailability"
let CloudServiceManagerNotificationSyncingDidBegin = "CloudServiceManagerNotificationSyncingDidBegin"
let CloudServiceManagerNotificationSyncingDidFinish = "CloudServiceManagerNotificationSyncingDidFinish"

public extension Notification.Name {
    static let cloudSyncingDidBegin = Notification.Name(CloudServiceManagerNotificationSyncingDidBegin)
    static let cloudSyncingDidFinish = Notification.Name(CloudServiceManagerNotificationSyncingDidFinish)
    static let cloudServiceBecameAvailable = Notification.Name(CloudServiceManagerNotificationServiceBecameAvailable)
    static let cloudServiceLostAvailability = Notification.Name(CloudServiceManagerNotificationServiceLostAvailability)
}

// MARK: - Cloud Service Controller

public protocol CloudServiceControllable {
    
    var storageController: CloudStorageControlling { get }
    var fileHandler: AppFileHandling { get }
    init(fileHandler: AppFileHandling, storageController: CloudStorageControlling)
    
    var isSyncing: Bool { get }
    
    var serviceType: CloudServiceType { get }
    
    // basically you can use this method to determine if something went wrong last time you tried to sync
    func shouldBeginFullSync() -> Bool
    
    // this is basically a way of fetching all files in the remote root folder
    // then using knownFiles to determine what is new on other side, local or remote
    // both sync methods will determine whether to upload, download, delete, or do nothing
    func beginFullSync(progress:SyncProgressBlock?,
                       completion:SyncCompletionBlock?)
    
    // this is like a full sync, but it only asks the cloud for metadata associated with the given fileInfos
    func sync(fileInfos: [SyncableFileInfo], completion:SyncCompletionBlock?)
    
    // this is like a 'fast sync'.  It just tells the remote to delete the files if it has it.
    func delete(fileInfos: [SyncableFileInfo], completion:SyncCompletionBlock?)
    
    /// this is a tricky one.  Because we deal with asynchronous communication with the internet, we should only change the object
    /// locally after we know if succeeded on the destination.  Especially since one object might be represented by more than
    /// one file.  What if one succeeds and the other fails?  How do you go back?
    /// - Parameters:
    ///   - changes: An array of changes that you want to execute
    ///   - completion: A completion block for when the operation has completed
    func rename(_ changes: [(source: SyncableFileInfo, destination: SyncableFileInfo)], completion: SyncCompletionBlock?)
    
    // concrete implementations of this protocol should be doing type checking of the delegate.  it should conform to the sub-protocol
    // also, when the completion block is called successfully, assume isAuthenticatedAndReadyForSyncing also to be true
    func startService(completion:SyncCompletionBlock?)
    
    func stopService()
}

extension CloudServiceControllable {
    
    public var serviceType: CloudServiceType {
        return self.storageController.serviceType
    }
}


