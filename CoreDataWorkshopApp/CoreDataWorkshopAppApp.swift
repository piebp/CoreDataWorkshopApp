//
//  CoreDataWorkshopAppApp.swift
//  CoreDataWorkshopApp
//
//  Created by Igor Postoev on 24.1.24..
//

import SwiftUI

@main
struct CoreDataWorkshopAppApp: App {
    
    @State
    var coreDataStack = {
        let stack = CoreDataStack()
        stack.setup()
        return stack
    }()
    
    func makeViewModel() -> ViewModel {
        let storage = CoreDataStorage(coreDataStack: coreDataStack)
        let vm = ViewModel(storage: storage)
        vm.getAllSongs()
        return vm
    }

    var body: some Scene {
        WindowGroup {
            let viewModel = makeViewModel()
            CustomContentView(
                viewModel: viewModel, isNewSongViewOpen: false, newSongName: ""
            )
        }
    }
}
