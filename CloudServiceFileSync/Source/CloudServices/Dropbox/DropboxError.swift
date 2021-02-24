//
//  DropboxError.swift
//  CloudSyncSandbox
//
//  Created by Stephen O'Connor on 22.02.21.
//

import Foundation
import SwiftyDropbox

// Basically will convert a CallError to a non-generic format that's easier to work with.

public enum RouteErrorType {
    case pathError(Files.LookupError)  // relevant for lists, get metadatas, and deletes
    case deleteError(Files.DeleteError)  // relevant for delete ops
    case relocationError(Files.RelocationError) // only relevant for moving ( and renaming?)
    case uploadError(Files.UploadError)  // only relevant on uploads
    case downloadError(Files.DownloadError) // only relevant on data downloads
    case retryRequired // generally for errors that can be resolved by trying again.  .reset, or tooManyWriteOperations
    case unspecified
}

public enum DropboxError: Error {

    case internalServerError(errorCode:Int, message:String?, requestId:String?)
    case badInputError(message: String?, requestId: String?)
    case rateLimitError(error: Auth.RateLimitError, requestId: String?)
    case httpError(code: Int?, message: String?, requestId: String?)
    case authError(error: Auth.AuthError, requestId: String?)
    case accessError(error: Auth.AccessError, requestId: String?)
    case routeError(type: RouteErrorType, requestId: String?)
    case clientError(error: Error?)
    case unspecifiedFailure(filename: String?)
    
    // this initializer is not public!
    // NOTE:  This is disgusting, so if you know how to type erase in order to clean this up, please do!
    init?(dropboxCallError: Any?) {
        
        guard dropboxCallError != nil else {
            return nil
        }
        
        if let callError = dropboxCallError as? CallError<Files.ListFolderContinueError> {
            switch callError {
            case let .internalServerError(code, message, requestId):
                self = .internalServerError(errorCode: code, message: message, requestId: requestId)
            case let .badInputError(message, requestId):
                self = .badInputError(message: message, requestId: requestId)
            case let .authError(error, _, _, requestId):
                self = .authError(error: error, requestId: requestId)
            case let .accessError(error, _, _, requestId):
                self = .accessError(error: error, requestId: requestId)
            case let .httpError(code, message, requestId):
                self = .httpError(code: code, message: message, requestId: requestId)
            case let .routeError(box, _, _, requestId):
                switch box.unboxed {
                case .path(let lookup):
                    self = .routeError(type: .pathError(lookup), requestId: requestId)
                case .other:
                    self = .routeError(type: .unspecified, requestId: requestId)
                case .reset:
                    self = .routeError(type: .retryRequired, requestId: requestId)
                }
            case let .rateLimitError(error, _, _, requestId):
                self = .rateLimitError(error: error, requestId: requestId)
            case let .clientError(err):
                self = .clientError(error: err)
            }
        } else if let callError = dropboxCallError as? CallError<Files.ListFolderError> {
            switch callError {
            case let .internalServerError(code, message, requestId):
                self = .internalServerError(errorCode: code, message: message, requestId: requestId)
            case let .badInputError(message, requestId):
                self = .badInputError(message: message, requestId: requestId)
            case let .authError(error, _, _, requestId):
                self = .authError(error: error, requestId: requestId)
            case let .accessError(error, _, _, requestId):
                self = .accessError(error: error, requestId: requestId)
            case let .httpError(code, message, requestId):
                self = .httpError(code: code, message: message, requestId: requestId)
            case let .routeError(box, _, _, requestId):
                switch box.unboxed {
                    case .path(let lookup):
                        self = .routeError(type: .pathError(lookup), requestId: requestId)
                    case .other:
                        self = .routeError(type: .unspecified, requestId: requestId)
                    case .templateError(let error):
                        log.error("Got an unexpected Template error: \(error.description)")
                        self = .routeError(type: .unspecified, requestId: requestId)
                    }
            case let .rateLimitError(error, _, _, requestId):
                self = .rateLimitError(error: error, requestId: requestId)
            case let .clientError(err):
                self = .clientError(error: err)
            }
        } else if let callError = dropboxCallError as? CallError<Files.GetMetadataError> {
            switch callError {
            case let .internalServerError(code, message, requestId):
                self = .internalServerError(errorCode: code, message: message, requestId: requestId)
            case let .badInputError(message, requestId):
                self = .badInputError(message: message, requestId: requestId)
            case let .authError(error, _, _, requestId):
                self = .authError(error: error, requestId: requestId)
            case let .accessError(error, _, _, requestId):
                self = .accessError(error: error, requestId: requestId)
            case let .httpError(code, message, requestId):
                self = .httpError(code: code, message: message, requestId: requestId)
            case let .routeError(box, _, _, requestId):
                switch box.unboxed {
                case .path(let lookup):
                    self = .routeError(type: .pathError(lookup), requestId: requestId)
                }
            case let .rateLimitError(error, _, _, requestId):
                self = .rateLimitError(error: error, requestId: requestId)
            case let .clientError(err):
                self = .clientError(error: err)
            }
        } else if let callError = dropboxCallError as? CallError<Files.DeleteError> {
            switch callError {
            case let .internalServerError(code, message, requestId):
                self = .internalServerError(errorCode: code, message: message, requestId: requestId)
            case let .badInputError(message, requestId):
                self = .badInputError(message: message, requestId: requestId)
            case let .authError(error, _, _, requestId):
                self = .authError(error: error, requestId: requestId)
            case let .accessError(error, _, _, requestId):
                self = .accessError(error: error, requestId: requestId)
            case let .httpError(code, message, requestId):
                self = .httpError(code: code, message: message, requestId: requestId)
            case let .routeError(box, _, _, requestId):
                switch box.unboxed {
                    case .pathLookup(let lookup):
                        self = .routeError(type: .pathError(lookup), requestId: requestId)
                    default:
                        self = .routeError(type: .deleteError(box.unboxed), requestId: requestId)
                    }
            case let .rateLimitError(error, _, _, requestId):
                self = .rateLimitError(error: error, requestId: requestId)
            case let .clientError(err):
                self = .clientError(error: err)
            }
        } else if let callError = dropboxCallError as? CallError<Files.RelocationError> {
            switch callError {
            case let .internalServerError(code, message, requestId):
                self = .internalServerError(errorCode: code, message: message, requestId: requestId)
            case let .badInputError(message, requestId):
                self = .badInputError(message: message, requestId: requestId)
            case let .authError(error, _, _, requestId):
                self = .authError(error: error, requestId: requestId)
            case let .accessError(error, _, _, requestId):
                self = .accessError(error: error, requestId: requestId)
            case let .httpError(code, message, requestId):
                self = .httpError(code: code, message: message, requestId: requestId)
            case let .routeError(box, _, _, requestId):
                self = .routeError(type: .relocationError(box.unboxed), requestId: requestId)
            case let .rateLimitError(error, _, _, requestId):
                self = .rateLimitError(error: error, requestId: requestId)
            case let .clientError(err):
                self = .clientError(error: err)
            }
        } else if let callError = dropboxCallError as? CallError<Files.UploadError> {
            switch callError {
            case let .internalServerError(code, message, requestId):
                self = .internalServerError(errorCode: code, message: message, requestId: requestId)
            case let .badInputError(message, requestId):
                self = .badInputError(message: message, requestId: requestId)
            case let .authError(error, _, _, requestId):
                self = .authError(error: error, requestId: requestId)
            case let .accessError(error, _, _, requestId):
                self = .accessError(error: error, requestId: requestId)
            case let .httpError(code, message, requestId):
                self = .httpError(code: code, message: message, requestId: requestId)
            case let .routeError(box, _, _, requestId):
                self = .routeError(type: .uploadError(box.unboxed), requestId: requestId)
            case let .rateLimitError(error, _, _, requestId):
                self = .rateLimitError(error: error, requestId: requestId)
            case let .clientError(err):
                self = .clientError(error: err)
            }
        } else if let callError = dropboxCallError as? CallError<Files.DownloadError> {
            switch callError {
            case let .internalServerError(code, message, requestId):
                self = .internalServerError(errorCode: code, message: message, requestId: requestId)
            case let .badInputError(message, requestId):
                self = .badInputError(message: message, requestId: requestId)
            case let .authError(error, _, _, requestId):
                self = .authError(error: error, requestId: requestId)
            case let .accessError(error, _, _, requestId):
                self = .accessError(error: error, requestId: requestId)
            case let .httpError(code, message, requestId):
                self = .httpError(code: code, message: message, requestId: requestId)
            case let .routeError(box, _, _, requestId):
                self = .routeError(type: .downloadError(box.unboxed), requestId: requestId)
            case let .rateLimitError(error, _, _, requestId):
                self = .rateLimitError(error: error, requestId: requestId)
            case let .clientError(err):
                self = .clientError(error: err)
            }
        } else {
            return nil
        }
    }
}

/*
 switch callError {
 case let .internalServerError(code, message, requestId):
 self = .internalServerError(errorCode: code, message: message, requestId: requestId)
 case let .badInputError(message, requestId):
 self = .badInputError(message: message, requestId: requestId)
 case let .authError(error, _, _, requestId):
 self = .authError(error: error, requestId: requestId)
 case let .accessError(error, _, _, requestId):
 self = .accessError(error: error, requestId: requestId)
 case let .httpError(code, message, requestId):
 self = .httpError(code: code, message: message, requestId: requestId)
 case let .routeError(box, _, _, requestId):
 
 // here you have to deal with the Boxed types that are relevant to what we're doing
 // e.g. ListFolderContinueError, ListFolderError, GetMetadataError, DeleteError, RelocationError, UploadError,DownloadError
 if let continueError = box.unboxed as? Files.ListFolderContinueError {
 switch continueError {
 case .path(let lookup):
 self = .routeError(type: .pathError(lookup), requestId: requestId)
 case .other:
 self = .routeError(type: .unspecified, requestId: requestId)
 case .reset:
 self = .routeError(type: .retryRequired, requestId: requestId)
 }
 } else if let folderError = box.unboxed as? Files.ListFolderError {
 switch folderError {
 case .path(let lookup):
 self = .routeError(type: .pathError(lookup), requestId: requestId)
 case .other:
 self = .routeError(type: .unspecified, requestId: requestId)
 case .templateError(let error):
 log.error("Got an unexpected Template error: \(error.description)")
 self = .routeError(type: .unspecified, requestId: requestId)
 }
 
 } else if let metadataError = box.unboxed as? Files.GetMetadataError {
 switch metadataError {
 case .path(let lookup):
 self = .routeError(type: .pathError(lookup), requestId: requestId)
 }
 } else if let deleteError = box.unboxed as? Files.DeleteError {
 switch deleteError {
 case .pathLookup(let lookup):
 self = .routeError(type: .pathError(lookup), requestId: requestId)
 default:
 self = .routeError(type: .deleteError(deleteError), requestId: requestId)
 }
 } else if let relocationError = box.unboxed as? Files.RelocationError {
 self = .routeError(type: .relocationError(relocationError), requestId: requestId)
 } else if let uploadError = box.unboxed as? Files.UploadError {
 self = .routeError(type: .uploadError(uploadError), requestId: requestId)
 } else if let downloadError = box.unboxed as? Files.DownloadError {
 self = .routeError(type: .downloadError(downloadError), requestId: requestId)
 } else {
 self = .routeError(type: .unspecified, requestId: requestId)
 }
 case let .rateLimitError(error, _, _, requestId):
 self = .rateLimitError(error: error, requestId: requestId)
 case let .clientError(err):
 self = .clientError(error: err)
 }
 */
