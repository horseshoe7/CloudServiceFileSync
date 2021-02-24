//
//  AppFileHandling.swift
//  CloudSyncSandbox
//
//  Created by Stephen O'Connor on 17.02.21.
//

import Foundation

/// sets the basis for converting files into your data types
/// one could consider breaking this out into a delegate pattern
/// Typically this acts as your bridge from your local data store to the remote file system
/// So any concrete implementation is likely going to have a data store reference
public protocol AppFileHandling {
    /// Basically is the highest level file filter for your application.
    /// Here you can determine whether your app is interested in this file
    func canHandleFile(with filename: String) -> Bool
    
    /// This is where you would derive fileInfos from your Syncable objects
    func knownFileInfos() -> [SyncableFileInfo]
    
    /// only if something needs to be uploaded will you need to have data ready to upload.  You use the fileInfo to locate your Syncable
    /// then have it prepare the data as approprite
    func prepareLocalDataURL(for fileInfo: SyncableFileInfo)
    
    /// should save the data to an application-specific location (e.g. Documents/SubFolder) and set info.localDataURL while also setting info.isDirty = true
    func saveLocally(_ fileData: Data, belongingTo info: SyncableFileInfo) throws
    
    /// Your implementation should remove the data and do any other housekeeping on your data model
    /// for example, if this was the last file associated with your object, you might also delete the object from your store.
    func removeData(at fileURL: URL?, belongingTo info: SyncableFileInfo) throws
    
    /// the common aspect of any file that establishes a relationship between SyncableFileInfo and its parent Syncable
    func identifier(from fileInfo: SyncableFileInfo) -> String
    
    /// A preliminary step to create a `Syncable` instance.  From a list of file infos, you need to group them so to know how to associate them to a `Syncable`.
    /// - Parameter infos: A flat list of Files that needs to be grouped and sorted.
    /// - Returns: A dictionary with a `Syncable`'s `identifier` as a key, and the values being Arrays of `SyncableFileInfo` that will belong to that `Syncable`
    func groupedAndSortedForSyncable(infos: [SyncableFileInfo]) -> [String: [SyncableFileInfo]]
    
    /// If your application returned true from the method `canHandleFile(...)`, this method will be invoked with synced file infos.
    /// It is your job to determine which of these represent updates and update them on your data model.
    /// It is within this method that you essentially update your local data type with that fileInfo
    /// - Parameters:
    ///   - syncedFileInfos: fileInfos that are now synced with the cloud service.  Depending on the value of `entireDataModel` it might represent your whole model
    ///   - entireDataModel: A Boolean that indicates whether the `syncedFileInfos` parameter represents all the data in your Cloud Folder.  Typically `true` for a full sync
    ///   - completion: A completion block that you need to invoke when these changes have completed.  You can complete on the main queue, as this will all be forwarded to Main anyway.
    func updateDataStore(with syncedFileInfos: [SyncableFileInfo], entireDataModel: Bool, completion: @escaping SyncCompletionBlock)
    
    /// This is a callback used by the sync engine to notify your data store when files have been renamed on the remote according to your API call to make changes.
    /// - Parameters:
    ///   - changes: An array of changes just completed on the remote requiring your data model to update
    ///   - completion: A completion block that you need to invoke when these changes have completed.  You can complete on the main queue, as this will all be forwarded to Main anyway.
    func updateObjects(with changes: [(source: SyncableFileInfo, destination: SyncableFileInfo)], completion: @escaping SyncCompletionBlock)
}
