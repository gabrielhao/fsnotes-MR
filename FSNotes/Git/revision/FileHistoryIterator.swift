//
//  FileRevLog.swift
//  Git2Swift
//
//  Created by Damien Giron on 14/09/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation

import Cgit2

/// Iterate to file history
public class FileHistoryIterator : RevisionIterator {
    
    // File path
    private let path: String
    
    // Previous commit oid
    private var previousOid: OID? = nil
    private var lastFetchedOid: OID? = nil
    
    public init(repository: Repository, path: String, refspec: String = "HEAD") throws {
        
        // Set path
        self.path = path
        
        // Create walker
        let walker = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Init walker
        var error = git_revwalk_new(walker, repository.pointer.pointee)
        guard error == 0 else {
            walker.deinitialize(count: 1)
            walker.deallocate()
            throw gitUnknownError("Unable to create rev walker for '\(refspec)'", code: error)
        }
        
        // Push reference
        error = git_revwalk_push_ref(walker.pointee, refspec)
        guard error == 0 else {
            walker.deinitialize(count: 1)
            walker.deallocate()
            throw gitUnknownError("Unable to set rev walker for '\(refspec)'", code: error)
        }
        
        super.init(repository: repository, pointer: walker)
    }
    
    
    /// Next value
    ///
    /// - returns: Next value or nil
    public override func next() -> OID? {
        
        guard let oid = super.next() else {
            return nil
        }
                
        lastFetchedOid = oid
        
        do {
            // Find commit
            let currentCommit = try repository.commitLookup(oid: oid)
            
            // Find parent entry
            let tree = try currentCommit.tree()
            
            // Find current entry
            let entry = try tree.entry(byPath: path)
            if (entry == nil) {
                return diffPrev(tree: tree, oid: oid)
            }
            
            // Test previous
            if (previousOid == nil) {
                previousOid = oid
                
                return next()
            } else {
                return diffPrev(tree: tree, oid: oid)
            }
            
        } catch {
            NSLog("Unable to find next OID \(error)")
        }
        
        return nil
    }
    
    private func diffPrev(tree: Tree, oid: OID) -> OID? {
        guard let pOid = previousOid else { return next() }
        
        do {
            // Find commit
            let previousCommit = try repository.commitLookup(oid: pOid)
            
            // Find parent entry
            let previousTree = try previousCommit.tree()
            
            // Find diff
            let diff = try previousTree.diff(other: tree)
            
            // Find
            if !diff.find(byPath: path, oid: oid) {
                
                // Set previous and find next
                previousOid = oid
                
                return next()
            } else {
                
                // Save previousOid
                let validOid = previousOid
                
                // Set previousOid
                previousOid = oid
                
                return validOid;
            }
        } catch {
            return nil
        }
    }
    
    public func getLast() -> OID? {
        return lastFetchedOid
    }
    
    public func checkFirstCommit() -> Bool {
        guard let oid = lastFetchedOid else { return false }
        
        do {
            let currentCommit = try repository.commitLookup(oid: oid)
            let tree = try currentCommit.tree()
            let entry = try tree.entry(byPath: path)
            if entry != nil {
                return true
            }
        } catch {/*_*/}
        
        return false
    }
}
