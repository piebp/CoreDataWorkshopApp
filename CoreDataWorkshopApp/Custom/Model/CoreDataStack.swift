//
//  CoreDataStack.swift
//  CoreDataWorkshopApp
//
//  Created by Igor Postoev on 24.1.24..
//

import CoreData
import Foundation

class CoreDataStack {
    
    var coordinator: NSPersistentStoreCoordinator!
    
    // You use an NSPersistentContainer instance to set up the model, context, and store coordinator simultaneously.
    var container: NSPersistentContainer!
    
    lazy var mainQueueContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        context.automaticallyMergesChangesFromParent = false
        context.name = "main"
        context.retainsRegisteredObjects = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        //mainQueueContext.automaticallyMergesChangesFromParent
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        return context
    }()
    
    lazy var privateQueueContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }()
    
    func setup() {
        
        func songDescription() -> NSEntityDescription {
            let desc = NSEntityDescription()
            desc.name = "Song"
            desc.managedObjectClassName = String(describing: Song.self)
            
            let idAttr = NSAttributeDescription()
            idAttr.name = "id"
            idAttr.attributeType = .stringAttributeType
            
            let nameAttr = NSAttributeDescription()
            nameAttr.name = "name"
            nameAttr.attributeType = .stringAttributeType
            
            let durationAttr = NSAttributeDescription()
            durationAttr.name = "duration"
            durationAttr.attributeType = .doubleAttributeType
            durationAttr.defaultValue = 0
            
            desc.properties = [idAttr, nameAttr, durationAttr]
            return desc
        }
        
        func playlistDescription() -> NSEntityDescription {
            let desc = NSEntityDescription()
            desc.name = "Playlist"
            desc.managedObjectClassName = String(describing: Playlist.self)
            
            let attr = NSAttributeDescription()
            attr.name = "name"
            attr.attributeType = .stringAttributeType
            
            desc.properties = [attr]
            return desc
        }
        
        func bandDescription() -> NSEntityDescription {
            let desc = NSEntityDescription()
            desc.name = "Band"
            desc.managedObjectClassName = String(describing: Band.self)
            
            let idAttr = NSAttributeDescription()
            idAttr.name = "id"
            idAttr.attributeType = .stringAttributeType
            
            let nameAttr = NSAttributeDescription()
            nameAttr.name = "name"
            nameAttr.attributeType = .stringAttributeType
            nameAttr.defaultValue = "Unknown"
            
            desc.properties = [idAttr, nameAttr]
            return desc
        }
        
        let songDesc = songDescription()
        let playlistDesc = playlistDescription()
        let bandDesc = bandDescription()
        
        func setupRelationShips() {
            let songToBandRel = NSRelationshipDescription()
            songToBandRel.name = "band"
            songToBandRel.maxCount = 1
            songToBandRel.minCount = 1
            songToBandRel.destinationEntity = bandDesc
            songDesc.properties.append(songToBandRel)
            
            let songToPlaylistRel = NSRelationshipDescription()
            songToPlaylistRel.name = "playlist"
            songToPlaylistRel.destinationEntity = playlistDesc
            songToPlaylistRel.maxCount = 1
            songToPlaylistRel.isOptional = true
            songToPlaylistRel.deleteRule = .nullifyDeleteRule
            // how obnject erases
            songDesc.properties.append(songToPlaylistRel)
            
            let playlistToSongsRel = NSRelationshipDescription()
            playlistToSongsRel.name = "songs"
            playlistToSongsRel.destinationEntity = songDesc
            playlistDesc.properties.append(playlistToSongsRel)
        }
        setupRelationShips()
        
        let model = NSManagedObjectModel()
        model.entities = [songDesc,
                          playlistDesc,
                          bandDesc]
        
        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last
        
        try? FileManager.default.contentsOfDirectory(atPath: documentDir!.relativePath).forEach {
            let url = documentDir!.appending(path: $0)
            try? FileManager.default.removeItem(at: url)
        }
        
        let url = documentDir!.appending(path: "Playlists.sqlite")
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        _ = try! coordinator.addPersistentStore(type: .sqlite, at: url)
        self.coordinator = coordinator
        
        container = NSPersistentContainer(name: "Playlists", managedObjectModel: model)
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        description.url = url
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
    }
    
    func populateFromJSON() {
        guard let urlString = Bundle.main.path(forResource: "Songs", ofType: "json") else {
            fatalError("Data missed")
        }
        let jsonUrl = URL(filePath: urlString)
        var jsonArray: [[String: Any]]!
        do {
            let jsonData = try Data(contentsOf: jsonUrl)
            jsonArray = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
        } catch {
            print(error.localizedDescription)
        }
        
        func trimPrefix(_ string: String) -> String {
            var result = String(string.trimmingPrefix("b'"))
            if result.hasSuffix("\'") {
                result = String(result.dropLast(1))
            }
            return result
        }
        
        mainQueueContext.performAndWait {
            func createBandAndSongs(_  json: [String: Any]) throws {
                let song = Song(context: mainQueueContext)
                song.id = trimPrefix(json["SongID"] as! String)
                song.name = trimPrefix(json["Title"] as! String)
                song.duration = json["Duration"] as! Double
                
                let artistId = trimPrefix(json["ArtistID"] as!String)
                let bandPredicate = NSPredicate(format: "id == %@", artistId)
                let bandRequest = Band.fetchRequest()
                bandRequest.predicate = bandPredicate
                bandRequest.fetchLimit = 1
                var band = (try mainQueueContext.fetch(bandRequest)).first as? Band
                if band == nil {
                    band = Band(context: mainQueueContext)
                    band!.id = artistId
                    band!.name = trimPrefix(json["ArtistName"] as!String)
                }
                song.band = band!
            }
            
            jsonArray.forEach {
                try? createBandAndSongs($0)
            }

            try! mainQueueContext.save()
            
            populatePlaylist()
        }
    }
    
    func populatePlaylist() {
        let playlistRequest = NSFetchRequest<Playlist>(entityName: Playlist.entity().name!)
        playlistRequest.fetchLimit = 1
        do {
            var playlist = (try mainQueueContext.fetch(playlistRequest)).first
            if playlist == nil {
                playlist = Playlist(context: mainQueueContext)
                playlist!.name = "A and B playlist"
            }
            let request = NSFetchRequest<Song>(entityName: Song.entity().name!)
            request.predicate = NSPredicate(format: "name BEGINSWITH[cd] %@ OR name BEGINSWITH[cd] %@", "A", "B")
            let songs = try mainQueueContext.fetch(request)
            playlist?.songs = Set(songs)
            songs.forEach {
                $0.playlist = playlist!
            }
            try mainQueueContext.save()
        } catch {
            debugPrint(error.localizedDescription)
        }
    }
}
