//
//  ViewModel.swift
//  CoreDataWorkshopApp
//
//  Created by Igor Postoev on 26.1.24..
//

import SwiftUI
import CoreData

protocol DataStorage {
    
    func getAllSongs() -> [Song]
    func deleteSong(_ objectId: NSManagedObjectID)
    func createSong() -> Song
    func save()
}

class ViewModel: ObservableObject {
    
    @Published var songs: [Song] = []
    var storage: DataStorage
    
    init(storage: DataStorage) {
        self.storage = storage
    }
    
    func getAllSongs() {
        songs = storage.getAllSongs()
    }
    
    func deleteSongs(_ offsets: IndexSet) {
        offsets.forEach {
            storage.deleteSong(songs[$0].objectID)
        }
    }
    
    func addSong() -> Song {
        storage.createSong()
    }
    
    func saveUpdates() {
        storage.save()
    }
}
