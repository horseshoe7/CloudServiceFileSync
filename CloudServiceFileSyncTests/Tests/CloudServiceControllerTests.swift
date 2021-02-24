//
//  AppleCloudServiceControllerTests.swift
//  CloudSyncSandboxTests
//
//  Created by Stephen O'Connor on 17.02.21.
//

import XCTest
@testable import CloudServiceFileSync

class CloudServiceControllerTests: XCTestCase {

    enum Expectation {
        case download
        case upload
        case deleteRemotely
        case deleteLocally
        case doNothing
    }
    
    var cloudService: CloudServiceController!
    var mockStorage = MockCloudStorageController(presentingViewController: nil)
    var handler = TextFileManager()
    
    override func setUpWithError() throws {
        
        cloudService = CloudServiceController(fileHandler: handler, storageController: mockStorage)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        if let textFileManager = self.cloudService.fileHandler as? TextFileManager {
            textFileManager.clearFilesFromStorageFolder()
        }
        if let mockStorage = self.cloudService.storageController as? MockCloudStorageController {
            mockStorage.clearFilesFromStorageFolder()
        }
    }
    
    /// Here we want to know that our `compareFileInfos` method is correct.
    func testFileInfoComparison() throws {
        
        var situations: [(filename: String, local: SyncableFileInfo?, remote: SyncableFileInfo?, expectation: Expectation)] = []
        
        let newer = Date(timeIntervalSinceNow: 24*60*60*5) // 5 days from now
        let sameOrAny = Date()
        let older = Date(timeIntervalSinceNow: -24*60*60*5) // 5 days ago
        let irrelevantURL = URL(fileURLWithPath: "SomePath.txt")
        
        var filename = "fileA.txt"
        situations.append(
            (filename: filename,
             local: nil,
             remote: SyncableFileInfo(filename: filename, state: .normal, updatedAt: sameOrAny, localDataURL: nil, remoteDataURL: irrelevantURL),
             expectation: .download)
        )
        
        filename = "fileB.txt"
        situations.append(
            (filename: filename,
             local: SyncableFileInfo(filename: filename, state: .newOrUnsynced, updatedAt: sameOrAny, localDataURL: irrelevantURL, remoteDataURL: nil),
             remote: nil,
             expectation: .upload)
        )
        
        filename = "fileC.txt"
        situations.append(
            (filename: filename,
             local: SyncableFileInfo(filename: filename, state: .normal, updatedAt: newer, localDataURL: irrelevantURL, remoteDataURL: nil),
             remote: SyncableFileInfo(filename: filename, state: .normal, updatedAt: older, localDataURL: nil, remoteDataURL: irrelevantURL),
             expectation: .upload)
        )
        
        filename = "fileD.txt"
        situations.append(
            (filename: filename,
             local: SyncableFileInfo(filename: filename, state: .normal, updatedAt: older, localDataURL: irrelevantURL, remoteDataURL: nil),
             remote: SyncableFileInfo(filename: filename, state: .normal, updatedAt: newer, localDataURL: nil, remoteDataURL: irrelevantURL),
             expectation: .download)
        )
        
        filename = "fileE.txt"
        situations.append(
            (filename: filename,
             local: SyncableFileInfo(filename: filename, state: .deleted, updatedAt: sameOrAny, localDataURL: irrelevantURL, remoteDataURL: nil),
             remote: SyncableFileInfo(filename: filename, state: .normal, updatedAt: sameOrAny, localDataURL: nil, remoteDataURL: irrelevantURL),
             expectation: .deleteRemotely)
        )
        
        filename = "fileF.txt"
        situations.append(
            (filename: filename,
             local: SyncableFileInfo(filename: filename, state: .normal, updatedAt: sameOrAny, localDataURL: irrelevantURL, remoteDataURL: nil),
             remote: nil,
             expectation: .deleteLocally)
        )
        
        filename = "fileG.txt"
        situations.append(
            (filename: filename,
             local: SyncableFileInfo(filename: filename, state: .normal, updatedAt: sameOrAny, localDataURL: irrelevantURL, remoteDataURL: nil),
             remote: SyncableFileInfo(filename: filename, state: .normal, updatedAt: sameOrAny, localDataURL: nil, remoteDataURL: irrelevantURL),
             expectation: .doNothing)
        )
        
        filename = "fileH.txt"
        situations.append(
            (filename: filename,
             local: SyncableFileInfo(filename: filename, state: .newOrUnsynced, updatedAt: sameOrAny, localDataURL: irrelevantURL, remoteDataURL: nil),
             remote: SyncableFileInfo(filename: filename, state: .normal, updatedAt: sameOrAny, localDataURL: nil, remoteDataURL: irrelevantURL),
             expectation: .upload)
        )
        
        filename = "fileI.txt"
        situations.append(
            (filename: filename,
             local: SyncableFileInfo(filename: filename, state: .newOrUnsynced, updatedAt: older, localDataURL: irrelevantURL, remoteDataURL: nil),
             remote: SyncableFileInfo(filename: filename, state: .normal, updatedAt: newer, localDataURL: nil, remoteDataURL: irrelevantURL),
             expectation: .download)
        )
        
        let remotes: [SyncableFileInfo] = situations.compactMap { (_,_, remote, _) -> SyncableFileInfo? in
            return remote
        }
        let locals: [SyncableFileInfo] = situations.compactMap { (_, local, _, _) -> SyncableFileInfo? in
            return local
        }
        
        let localFiles = ["B", "C", "D", "E", "F", "G", "H", "I"].map { return "file\($0).txt" }
        XCTAssertEqual(localFiles.count, locals.count)
        for info in locals {
            XCTAssertTrue(localFiles.contains(info.filename))
        }
        
        let remoteFiles = ["A", "C", "D", "E", "G", "H", "I"].map { return "file\($0).txt" }
        XCTAssertEqual(remoteFiles.count, remotes.count)
        for info in remotes {
            XCTAssertTrue(remoteFiles.contains(info.filename))
        }
        
        /*
         Data  (--- means doesn't exist there)
         
         Filename    |    Local     |    Remote     |    Expectation   |    Notes
         --------------------------------------------------------------------------
         A             ---           any date         download
         B           (new) any        ---             upload
         C           newer           older            upload
         D           older           newer            download
         E           (deleted)       any date         delete remotely
         F           any (notNew)     ---             delete locally
         G           same            same date        nothing
         H           (isNew) same    same or older    upload          ideally shouldn't happen, but here local is truth
         I           (isNew) older   newer           download         ideally shouldn't happen, but remote is truth if newer
         
         */
        
        let comparison = cloudService.compareFileInfos(remote: remotes,
                                                   local: locals,
                                                   handling: cloudService.fileHandler)
        
        XCTAssertEqual(comparison.errors.count, 0, "Should have completed without errors")
        
        XCTAssertEqual(comparison.result.filesUnchanged.count, 1)
        XCTAssertEqual(comparison.result.filesToDeleteLocally.count, 1)
        XCTAssertEqual(comparison.result.filesToDeleteOnRemote.count, 1)
        XCTAssertEqual(comparison.result.filesToUpload.count, 3)
        XCTAssertEqual(comparison.result.filesToDownload.count, 3)
        
        for situation in situations {
            switch situation.expectation {
            case .download:
                XCTAssertNotNil(comparison.result.filesToDownload.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesToUpload.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesToDeleteLocally.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesToDeleteOnRemote.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesUnchanged.info(with: situation.filename))
                XCTAssertNil(comparison.result.invalidFiles.info(with: situation.filename))
                
            case .upload:
                XCTAssertNil(comparison.result.filesToDownload.info(with: situation.filename))
                XCTAssertNotNil(comparison.result.filesToUpload.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesToDeleteLocally.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesToDeleteOnRemote.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesUnchanged.info(with: situation.filename))
                XCTAssertNil(comparison.result.invalidFiles.info(with: situation.filename))
            case .deleteLocally:
                XCTAssertNil(comparison.result.filesToDownload.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesToUpload.info(with: situation.filename))
                XCTAssertNotNil(comparison.result.filesToDeleteLocally.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesToDeleteOnRemote.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesUnchanged.info(with: situation.filename))
                XCTAssertNil(comparison.result.invalidFiles.info(with: situation.filename))
            case .deleteRemotely:
                XCTAssertNil(comparison.result.filesToDownload.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesToUpload.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesToDeleteLocally.info(with: situation.filename))
                XCTAssertNotNil(comparison.result.filesToDeleteOnRemote.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesUnchanged.info(with: situation.filename))
                XCTAssertNil(comparison.result.invalidFiles.info(with: situation.filename))
            case .doNothing:
                XCTAssertNil(comparison.result.filesToDownload.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesToUpload.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesToDeleteLocally.info(with: situation.filename))
                XCTAssertNil(comparison.result.filesToDeleteOnRemote.info(with: situation.filename))
                XCTAssertNil(comparison.result.invalidFiles.info(with: situation.filename))
                XCTAssertNotNil(comparison.result.filesUnchanged.info(with: situation.filename))
            }
        }
        
        
    }
    
    func testSimpleSync() throws {
        
        let newer = Date(timeIntervalSinceNow: 24*60*60*5) // 5 days from now
        let sameOrAny = Date()
        let older = Date(timeIntervalSinceNow: -24*60*60*5) // 5 days ago
        
        // set up local files and remote files.  Should follow from the table in the test above.
        var textFile = try TextFile.createLocalTextFile(filenameWithoutExtension: "A", isNew: false, overwrite: true, creationDate: sameOrAny)
        mockStorage.addFileInfoToStorage(textFile.fileInfos.first!) // TextFile always has 1 fileInfo
        
        // B
        textFile = try handler.createLocalTextFile(filenameWithoutExtension: "B", isNew: true, overwrite: true, creationDate: sameOrAny)
        
        // C
        textFile = try handler.createLocalTextFile(filenameWithoutExtension: "C", isNew: false, overwrite: true, creationDate: newer)
        var info = textFile.fileInfos.first!.copy() as! SyncableFileInfo
        info.updatedAt = older
        mockStorage.addFileInfoToStorage(info)
        
        // D
        textFile = try handler.createLocalTextFile(filenameWithoutExtension: "D", isNew: false, overwrite: true, creationDate: older)
        info = textFile.fileInfos.first!.copy() as! SyncableFileInfo
        info.updatedAt = newer
        mockStorage.addFileInfoToStorage(info)
        
        // E
        textFile = try handler.createLocalTextFile(filenameWithoutExtension: "E", isNew: false, overwrite: true, creationDate: newer)
        info = textFile.fileInfos.first!.copy() as! SyncableFileInfo
        textFile.fileInfos.first!.state = .deleted
        info.updatedAt = older
        mockStorage.addFileInfoToStorage(info)
        
        
        // F
        textFile = try handler.createLocalTextFile(filenameWithoutExtension: "F", isNew: false, overwrite: true, creationDate: sameOrAny)
        
        // G
        textFile = try handler.createLocalTextFile(filenameWithoutExtension: "G", isNew: false, overwrite: true, creationDate: sameOrAny)
        info = textFile.fileInfos.first!.copy() as! SyncableFileInfo
        mockStorage.addFileInfoToStorage(info)
        
        // H
        textFile = try handler.createLocalTextFile(filenameWithoutExtension: "H", isNew: true, overwrite: true, creationDate: sameOrAny)
        info = textFile.fileInfos.first!.copy() as! SyncableFileInfo
        mockStorage.addFileInfoToStorage(info)
        
        // I
        textFile = try handler.createLocalTextFile(filenameWithoutExtension: "I", isNew: true, overwrite: true, creationDate: older)
        info = textFile.fileInfos.first!.copy() as! SyncableFileInfo
        info.updatedAt = newer
        mockStorage.addFileInfoToStorage(info)
        
        let localFiles = ["B", "C", "D", "E", "F", "G", "H", "I"].map { return "\($0).txt"}
        XCTAssertEqual(localFiles.count, handler.textFiles.values.count)
        for textFile in handler.textFiles.values {
            XCTAssertTrue(localFiles.contains(textFile.fileInfos.first!.filename))
        }
        
        let remoteFiles = ["A", "C", "D", "E", "G", "H", "I"].map { return "\($0).txt"}
        XCTAssertEqual(remoteFiles.count, mockStorage.files.count)
        for info in mockStorage.files {
            XCTAssertTrue(remoteFiles.contains(info.filename))
        }
        
        
        // run a sync
        let expectation = self.expectation(description: "Async Code Completes")
        cloudService.beginFullSync { (summary, details, numExpected, numCompleted) in
            log.info("\(numCompleted)/\(numExpected): \(summary) - \(details ?? "")")
            
        } completion: { [unowned self] (success, errors) in
            if let errors = errors {
                XCTFail("❌ There were errors that shouldn't have been.\n\(errors)")
            }
            
            // test the assumptions
            // expect 7 text files in TextFileManager with filenames in [ABCDGHI]
            // with dates that match the action done on them
            let expectedFileIdentifiers = ["A","B","C","D","G","H","I"]
            XCTAssertEqual(self.handler.textFiles.values.count, 7, "❌ There should be only 7 TextFiles after the sync")
            for textFile in self.handler.textFiles.values {
                
                XCTAssertTrue(expectedFileIdentifiers.contains(textFile.identifier), "❌ Somehow a file we didn't expect made it into the synced result")
                
                let info = textFile.fileInfos.first!
                XCTAssertEqual(info.state, .normal, "❌ After a sync, all your files should be in a normal state.")
                
                switch textFile.identifier {
                case "A":
                    XCTAssertEqual(info.updatedAt, sameOrAny, "❌ Got the wrong date")
                case "B":
                    XCTAssertEqual(info.updatedAt, sameOrAny, "❌ Got the wrong date")
                case "C":
                    XCTAssertEqual(info.updatedAt, newer, "❌ Got the wrong date")
                case "D":
                    XCTAssertEqual(info.updatedAt, newer, "❌ Got the wrong date")
                case "G":
                    XCTAssertEqual(info.updatedAt, sameOrAny, "❌ Got the wrong date")
                case "H":
                    XCTAssertEqual(info.updatedAt, sameOrAny, "❌ Got the wrong date")
                case "I":
                    XCTAssertEqual(info.updatedAt, newer, "❌ Got the wrong date")
                default:
                    break
                }
            }
            
            expectation.fulfill()
        }
        
        self.wait(for: [expectation], timeout: 600)
    }
    
    func testSyncOneObject() throws {
        // imagine you're dealing with a Songbook Song that uses images.

        // cases
        
        // 2 images locally, 3 images remote  (remote: 3rd image added)
        
        // 2 images locally, 3 images remote  (remote: 1st image updated, 3rd image added)
        
        // 3 images locally, 2 images remote (remote: 1st image was deleted but not renamed)
        
        // 3 images locally, 2 images remote (remote: 1st image was deleted, the other two renamed to maintain array order, so it just looks like 3rd was deleted)
        
        // as assume that AppFileHandling's known file infos will be the current state.
        
        // 3 images locally (initially) then deleting 1st.  2nd and 3rd will be re-generated as 1st and 2nd, or you just mark the deleted ones as deleted then they get cleaned up after sync.
        // but then you'll still have to do re-adjusting the array indices after the sync is complete...  Hmmm...
        
        // or maybe when  you update one file in an object's collection, you should update all of them, so that when you sync it gets corrected.
    }
    
    func testSyncDeleteInfos() throws {
        
    }
    
    func testRenameInfos() throws {
        
    }
}
