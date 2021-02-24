//
//  AppleCloudSyncTests.swift
//  CloudSyncSandboxTests
//
//  Created by Stephen O'Connor on 15.02.21.
//

import XCTest
@testable import CloudServiceFileSync


class AppleCloudStorageControllerTests: XCTestCase {

    var cloudStorage: CloudStorageControlling!
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        cloudStorage = AppleCloudStorageController(presentingViewController: nil) // TODO: Refactor UIViewController as a protocol that has the present method.
        
        if let appleCloudStorage = cloudStorage as? AppleCloudStorageController {
            appleCloudStorage.removeAllFilesInCloudFolder()
        }
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testLocalApplicationRootExistsOrIsCreated() throws {
        guard let appleCloudStorage = cloudStorage as? AppleCloudStorageController else {
            XCTSkip("Skipping test.  Only for Apple Cloud Storage.")
            return
        }
        
        guard let rootURL = appleCloudStorage.config.containerUrl else {
            return XCTFail("❌ No container URL.  Is your test device signed in to iCloud?")
        }
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: rootURL.path)
        XCTAssertTrue(exists, "❌ The root folder should exist")
    }

    func testCanAuthenticateWithCloudServiceIfRequired() throws {
        
    }

    func testCanGetListOfFilesInApplicationRootFolder() throws {
        
        let expectation = self.expectation(description: "Can get folder contents")
        cloudStorage.listApplicationRootFolder(completionQueue: .main) { (fileList, error) in
            
            if let syncError = error as? SyncError, case .initializationFailed = syncError {
                XCTFail("You aren't authenticated.  That means, depending on the cloud service, you'll have to sign into iCloud on iOS Settings, or you'll have to run the Test Host once to authenticate with Dropbox.")
            }
            
            XCTAssertNil(error)
            log.info("Contents of Application Root folder:")
            log.info(String(describing: fileList.map({ return $0.filename })))
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 3.0)
    }
    
    func testCanAddAndRemoveAFile() throws {
        let filename = "TestFile"
        let textFile = try TextFile.createLocalTextFile(filenameWithoutExtension: filename, overwrite: true)
        
        let expectation = self.expectation(description: "Adding and removing file succeeded.")
        
        cloudStorage.uploadDataToRootFolder(textFile.fileInfos.first!, overwrite: false, completionQueue: .main) { [weak cloudStorage] (addSuccess, addErrors) in
            if let errors = addErrors {
                
                if let syncError = errors.first as? SyncError, case .initializationFailed = syncError {
                    XCTFail("You aren't authenticated.  That means, depending on the cloud service, you'll have to sign into iCloud on iOS Settings, or you'll have to run the Test Host once to authenticate with Dropbox.")
                }
                
                log.error("Errors occurred: \n\(errors)")
                XCTFail("❌ Failed with errors.")
            }
            XCTAssertTrue(addSuccess, "❌ Should have succeeded")
            guard let storage = cloudStorage else {
                return XCTFail("❌ Lost the cloud service")
            }
            
            storage.listApplicationRootFolder(completionQueue: .main) { (infos, listError) in
                
                if let syncError = listError as? SyncError, case .initializationFailed = syncError {
                    XCTFail("You aren't authenticated.  That means, depending on the cloud service, you'll have to sign into iCloud on iOS Settings, or you'll have to run the Test Host once to authenticate with Dropbox.")
                }
                
                if listError == nil {
                    log.info("List of files:\n\(infos)")
                }
                XCTAssertNil(listError, "❌ As an intermediate step we list that this file is present, so it shouldn't fail.")
                
                // a TextFile always has one and only one fileInfo
                storage.removeFromRootFolder(textFile.fileInfos.first!, completionQueue: .main) { (removeSuccess, removeErrors) in
                    XCTAssertTrue(removeSuccess, "❌ Couldn't remove.")
                    
                    expectation.fulfill()
                }
            }
        }
        
        self.wait(for: [expectation], timeout: 10)
    }
    
    func testCanCorrectlyDetermineSyncState() throws {
        
        let earlierDate = Date(timeIntervalSinceNow: -3600)
        let now = Date()
        // create a local file that's older...
        var testFileLocal = try TextFile.createLocalTextFile(filenameWithoutExtension: "SyncTest", overwrite: true, creationDate: earlierDate)
        
        // create a pretend remote file that's newer
        var testFileRemote = try TextFile.createLocalTextFile(filenameWithoutExtension: "SyncTest", overwrite: true, creationDate: now)
        
        var result = testFileLocal.syncStatus(comparedToRemote: testFileRemote)
        XCTAssertEqual(result, SyncableFileStatus.remoteNewer(localExists: true))
        
        result = testFileRemote.syncStatus(comparedToLocal: nil)
        XCTAssertEqual(result, SyncableFileStatus.remoteNewer(localExists: false))
        
        testFileLocal = try TextFile.createLocalTextFile(filenameWithoutExtension: "SyncTest", overwrite: true, creationDate: now)
        testFileRemote = try TextFile.createLocalTextFile(filenameWithoutExtension: "SyncTest", overwrite: true, creationDate: earlierDate)
        
        result = testFileLocal.syncStatus(comparedToRemote: testFileRemote)
        XCTAssertEqual(result, SyncableFileStatus.localNewer)
        
        result = testFileRemote.syncStatus(comparedToLocal: testFileLocal)
        XCTAssertEqual(result, SyncableFileStatus.localNewer)
        
        testFileRemote = try TextFile.createLocalTextFile(filenameWithoutExtension: "SyncTest", overwrite: true, creationDate: now)
        result = testFileRemote.syncStatus(comparedToLocal: testFileLocal)
        XCTAssertEqual(result, SyncableFileStatus.synced)
        
        result = testFileLocal.syncStatus(comparedToRemote: testFileRemote)
        XCTAssertEqual(result, SyncableFileStatus.synced)
        
        testFileRemote = try TextFile.createLocalTextFile(filenameWithoutExtension: "SyncTestOther", overwrite: true, creationDate: now)
        result = testFileLocal.syncStatus(comparedToRemote: testFileRemote)
        XCTAssertEqual(result, SyncableFileStatus.undetermined)
        
        
        /*
         case remoteNewer(localExists: Bool)
         case localNewer
         case synced
         */
    }
    
    func testCanAddAFileAndItAppearsInList() throws {
        let filename = "TestFile"
        let textFile = try TextFile.createLocalTextFile(filenameWithoutExtension: filename, overwrite: true)
        
        let expectation = self.expectation(description: "Adding and removing file succeeded.")
        
        // remove any existing.  TextFile always has one and only one fileInfo
        cloudStorage.removeFromRootFolder(textFile.fileInfos.first!, completionQueue: .main) { [weak cloudStorage] (removeSuccess, removeErrors) in
            
            guard let storage = cloudStorage else {
                return XCTFail("Lost the cloud service")
            }
            
            if let syncError = removeErrors?.first as? SyncError, case .initializationFailed = syncError {
                XCTFail("You aren't authenticated.  That means, depending on the cloud service, you'll have to sign into iCloud on iOS Settings, or you'll have to run the Test Host once to authenticate with Dropbox.")
            }
            
            storage.uploadDataToRootFolder(textFile.fileInfos.first!, overwrite: false, completionQueue: .main) {  (addSuccess, addErrors) in
                XCTAssertTrue(addSuccess, "Should have succeeded")
                
                storage.listApplicationRootFolder(completionQueue: .main) { (infos, listError) in
                    
                    if listError == nil {
                        log.info("List of files:\n\(infos)")
                    }
                    XCTAssertNil(listError, "As an intermediate step we list that this file is present, so it shouldn't fail.")
                    
                    expectation.fulfill()
                }
            }
        }
        
        self.wait(for: [expectation], timeout: 10)
    }
}
