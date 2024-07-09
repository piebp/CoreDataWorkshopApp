//
//  ContentView.swift
//  CoreDataWorkshopApp
//
//  Created by Igor Postoev on 24.1.24..
//

import SwiftUI
import CoreData

struct CustomContentView: View {
    
    @ObservedObject var viewModel: ViewModel
    @State var isNewSongViewOpen: Bool
    @State var newSongName: String

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.songs) { item in
                    NavigationLink {
                        Text(item.name)
                    } label: {
                        Text(item.name)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                    .sheet(isPresented: $isNewSongViewOpen) {
                        VStack(alignment: .leading, spacing: 20) {
                            TextField(
                                "Song name",
                                text: $newSongName
                            )
                            Button(action: addItem) {
                                Label("Add Item", systemImage: "plus")
                            }
                        }
                    }
                    .onDisappear {
                        newSongName = ""
                    }
                }
            }
            Text("Select an item")
        }
    }

    private func addItem() {
        isNewSongViewOpen = true
        _ = viewModel.addSong()
        viewModel.saveUpdates()
    }

    private func deleteItems(offsets: IndexSet) {
        viewModel.deleteSongs(offsets)
        viewModel.saveUpdates()
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

func storageForPreview() -> CoreDataStorage {
    let stack = CoreDataStack()
    stack.setup()
    return CoreDataStorage(coreDataStack: stack)
}
