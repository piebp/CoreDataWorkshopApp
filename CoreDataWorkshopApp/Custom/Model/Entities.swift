//
//  Entities.swift
//  CoreDataWorkshopApp
//
//  Created by Igor Postoev on 24.1.24..
//

import CoreData

@objc(Band)
class Band: NSManagedObject, Identifiable {
    
    @NSManaged var id: String
    @NSManaged var name: String
}

@objc(Playlist)
class Playlist: NSManagedObject, Identifiable {
    
    @NSManaged var name: String
    @NSManaged var songs: Set<Song>
}

@objc(Song)
class Song: NSManagedObject, Identifiable {
    
    @NSManaged var id: String
    @NSManaged var name: String
    @NSManaged var band: Band
    @NSManaged var playlist: Playlist
    @NSManaged var duration: Double
}
