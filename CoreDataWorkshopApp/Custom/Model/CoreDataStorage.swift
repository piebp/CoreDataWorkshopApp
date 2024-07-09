//
//  CoreDataService.swift
//  CoreDataWorkshopApp
//
//  Created by Igor Postoev on 24.1.24..
//

import CoreData
import Foundation

class CoreDataStorage: DataStorage {
    
    let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
    
    var context: NSManagedObjectContext {
        return coreDataStack.mainQueueContext
    }
    
    // MARK: CRUD Operations
    
    func getAllSongs() -> [Song] {
        let request = NSFetchRequest<Song>(entityName: "Song")
        var songs: [Song]!
        do {
            songs = try context.fetch(request)
        } catch {
            debugPrint(error.localizedDescription)
        }
        return songs
    }
    
    func deleteSong(_ objectId: NSManagedObjectID) {
        context.performAndWait {
            let object = context.object(with: objectId)
            context.delete(object)
        }
    }
    
    func createSong() -> Song {
        var created: Song!
        context.performAndWait {
            created = Song(context: context)
        }
        return created
    }
    
    func save() {
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            debugPrint(error.localizedDescription)
        }
    }

    
    // MARK: -Fetching
    
    func performFetchingWithSubquery() {
        do {
            // find playlists which songs' authors name contains some input string
            let request = NSFetchRequest<Playlist>(entityName: Playlist.entity().name!)
            request.predicate = NSPredicate(format: "SUBQUERY(songs, $song, $song.name ==[cd] \"\("Auguri Cha Cha")\").@count > 0")
            let playlists = try context.fetch(request)
            print("debug point")
        } catch {
            debugPrint(error.localizedDescription)
        }
    }
    
    func performFetchingWithExpressions() {
        do {
            //sum duration of playlist/album
            let fetchRequest = NSFetchRequest<NSDictionary>(entityName: Song.entity().name!)
            fetchRequest.resultType = .dictionaryResultType
            
            let expressionDescription = NSExpressionDescription()
            expressionDescription.name = "aveDuration"
            
            let expression = NSExpression(forKeyPath: #keyPath(Song.duration))
            expressionDescription.expression = NSExpression(forFunction: "average:", arguments: [expression])
            expressionDescription.expressionResultType = .doubleAttributeType
            
            fetchRequest.propertiesToFetch = [expressionDescription]
        
            do {
                let results = try coreDataStack.mainQueueContext.fetch(fetchRequest)
                let resultDict = results.first!
                let aveDuration = resultDict["aveDuration"] as! NSNumber
                print(aveDuration)
            } catch let error as NSError {
                print("Count not fetch \(error), \(error.userInfo)")
            }
        }
    }
    
    func performFetchingWithGrouping() {
        //wip
    }
    
    // MARK: -Methods not covered
    
    func performBackgroundActions(handler: (([NSManagedObject]) -> Void)?) {
        let request = NSFetchRequest<Song>(entityName: Song.entity().name!)
        request.predicate = NSPredicate(format: "name BEGINSWITH[cd] %@", "A")
        
        /// NSAsynchronousFetchRequest
        let asyncRequest = NSAsynchronousFetchRequest<Song>(fetchRequest: request) {
            (result: NSAsynchronousFetchResult<Song>) in
            if let final = result.finalResult {
                handler?(final)
            }
        }
        asyncRequest.estimatedResultCount = 2000
        do {
            try coreDataStack.mainQueueContext.execute(asyncRequest)
        } catch {
            print("ERROR: \(error.localizedDescription)")
        }
        
        /// performBackgroundTask
        coreDataStack.container.performBackgroundTask { context in
            do {
                let results = try context.fetch(request)
                print(results.count)
            } catch let error as NSError {
                print("ERROR: \(error.localizedDescription)")
            }
        }
        
        /// privateQueueContext.perform
        coreDataStack.privateQueueContext.perform {
            do {
                let results = try self.coreDataStack.privateQueueContext.fetch(request)
                print(results.count)
            } catch let error as NSError {
                print("ERROR: \(error.localizedDescription)")
            }
        }
        
        /// async privateQueueContext.perform
        Task {
            do {
                let result = try await coreDataStack.privateQueueContext.perform {
                    return try self.coreDataStack.privateQueueContext.fetch(request)
                }
                print(result.count)
            } catch let error as NSError {
                print("ERROR: \(error.localizedDescription)")
            }
        }
    }
    
    func passingResultsBetweenContexts() {
        let request = NSFetchRequest<Song>(entityName: Song.entity().name!)
        request.fetchLimit = 100
        
        let anotherQueueManagedObjectAction: ([NSManagedObject]) -> Void = { objects in
            //proceeding with objects may lead to internal CD issues
            DispatchQueue.main.async {
                // objects
            }
            DispatchQueue.global(qos: .background).async {
                // objects
            }
        }
        
        let anotherQueueManagedObjectIDAction: ([NSManagedObjectID]) -> Void = { objectIDs in
            DispatchQueue.main.async {
                //proceed with objectIDs
            }
            DispatchQueue.global(qos: .background).async {
                //proceed with objectIDs
            }
        }
        
        let anotherQueueStringsAction: ([String]) -> Void = { objectIDs in
            DispatchQueue.main.async {
                //proceed with strings
            }
            DispatchQueue.global(qos: .background).async {
                //proceed with strings
            }
        }
        
        coreDataStack.privateQueueContext.perform {
            do {
                let managedObjects = try self.coreDataStack.privateQueueContext.fetch(request)
                anotherQueueManagedObjectAction(managedObjects)
                
                request.resultType = .managedObjectIDResultType
                let managedObjectsIDs = try self.coreDataStack.privateQueueContext.fetch(request)
                anotherQueueManagedObjectIDAction(managedObjectsIDs.map { $0.objectID })
                
                request.resultType = .dictionaryResultType //or request.resultType = .managedObjectResultType
                request.propertiesToFetch = ["name"]
                let names = try self.coreDataStack.privateQueueContext.fetch(request) as! [NSDictionary]
                anotherQueueStringsAction(names.map {$0["name"] as! String})
                
                print("debug point")
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
    
    func performFetchingCachedAndNonFaults() {
        let request = NSFetchRequest<Song>(entityName: Song.entity().name!)
        request.returnsObjectsAsFaults = false
        var elapsed = try! measureElapsedTime {
            context.performAndWait {
                let songs = try! context.fetch(request)
                songs.forEach {
                    let _ = $0.band
                }
            }
        }
        print(elapsed)
        request.returnsObjectsAsFaults = true
        elapsed = try! measureElapsedTime {
            context.performAndWait {
                let songs = try! context.fetch(request)
                songs.forEach {
                    let _ = $0.band
                }
            }
        }
        print(elapsed)
        let clearCacheContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        clearCacheContext.persistentStoreCoordinator = coreDataStack.coordinator
        elapsed = try! measureElapsedTime {
            clearCacheContext.performAndWait {
                let songs = try! clearCacheContext.fetch(request)
                songs.forEach {
                    let _ = $0.band
                }
            }
        }
        print(elapsed)
    }
    
    func performWithPendingChanges() {
        do {
            let request = NSFetchRequest<Song>(entityName: Song.entity().name!)
            request.fetchLimit = 1
            var songs = try coreDataStack.mainQueueContext.fetch(request)
            songs.first?.name = "New song name"
            
            let requestByName = NSFetchRequest<Song>(entityName: Song.entity().name!)
            requestByName.fetchLimit = 1
            requestByName.predicate = NSPredicate(format: "name = %@", "New song name")
            songs = try coreDataStack.mainQueueContext.fetch(requestByName)
            print(songs.first?.id)
            
            requestByName.includesPendingChanges = false
            requestByName.predicate = NSPredicate(format: "name = %@", "New song name")
            songs = try coreDataStack.mainQueueContext.fetch(requestByName)
            print(songs.first?.id)
        } catch {
            debugPrint(error.localizedDescription)
        }
    }
    
    func performManagedObjectUniqueness() {
        let bandRequest = NSFetchRequest<Band>(entityName: Band.entity().name!)
        bandRequest.fetchLimit = 1
        
        context.performAndWait {
            let band = (try! context.fetch(bandRequest)).first!
            
            let songRequest = NSFetchRequest<Song>(entityName: Song.entity().name!)
            songRequest.predicate = NSPredicate(format: "band = %@", band)
            songRequest.fetchLimit = 2
            
            let songs = try! context.fetch(songRequest)
            let bandOfFirst = songs[0]
            let bandOfSecond = songs[1]
            
            //bandOfFirst - bandOfSecond - same fault and managedobject
            
            songs.forEach {
                let _ = $0.band
            }
        }
    }
    
    func performFetchingWithBatchingAndPrefetching() {
        let request = NSFetchRequest<Song>(entityName: Song.entity().name!)
        request.fetchLimit = 1000
        request.returnsObjectsAsFaults = false
        request.relationshipKeyPathsForPrefetching = [#keyPath(Song.band)]
        
        request.fetchBatchSize = 100
        
        context.performAndWait {
            let songs = (try! context.fetch(request))
            songs.forEach {
                let _ = $0.band
            }
        }
    }
    
    func savingContextsIntoParent() {
        let childMainContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        let childPrivateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        childMainContext.parent = coreDataStack.privateQueueContext
        childPrivateContext.parent = coreDataStack.mainQueueContext
        
        childMainContext.perform {
            do {
                try childMainContext.save() // changes only commited to coreDataStack.privateQueueContext
                self.coreDataStack.privateQueueContext.perform {
                    do {
                        try self.coreDataStack.privateQueueContext.save() // changes are going to settle down in persistent store
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
    
    // -MARK: Batched operations
    
    func performBatchOperations() {
        coreDataStack.mainQueueContext.performAndWait {
            do {
                let batchRequest = NSBatchUpdateRequest(entityName: Song.entity().name!)
                batchRequest.predicate = NSPredicate(format: "name == %@", "b")
                batchRequest.resultType = .updatedObjectIDsResultType
                batchRequest.propertiesToUpdate = ["name": "Name is invalid"]
                let batchResult = try coreDataStack.mainQueueContext.execute(batchRequest) as! NSBatchUpdateResult
                let result = batchResult.result as? [NSManagedObjectID]
                print("updated \(result?.count) records")
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
        //NSBatchDeleteResult
        //NSBatchInsertRequest
    }
    
    func measureElapsedTime(_ operation: () throws -> Void) throws -> UInt64 {
        let startTime = DispatchTime.now()
        try operation()
        let endTime = DispatchTime.now()
        
        let elapsedTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        let convertedElapsedTime = Double(elapsedTime) // 1_000.0
        
        return UInt64(convertedElapsedTime)
    }
}
