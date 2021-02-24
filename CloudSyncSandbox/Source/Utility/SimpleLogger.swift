//
//  SimpleLogger.swift
//  CloudSyncSandbox
//
//  Created by Stephen O'Connor on 15.02.21.
//

import Foundation

// ideally use a framework like XCGLogger...

public protocol Loggable {
    func info(_ message: String)
    func error(_ message: String)
    func debug(_ message: String)
}

public class Logger: Loggable {
    
    public enum Level: CaseIterable {
        case info
        case error
        case debug
    }
    
    public var levelsOfInterest: [Level] = Level.allCases
    
    public init() {
        
    }
    
    public func info(_ message: String) {
        printLog(message, level: .info)
    }
    
    public func error(_ message: String) {
        printLog(message, level: .error)
    }
    
    public func debug(_ message: String) {
        printLog(message, level: .debug)
    }
    
    private func printLog(_ message: String, level: Level) {
        guard self.levelsOfInterest.contains(level) else {
            return
        }
        
        print(message)
    }
}

var log: Logger = Logger()
