// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  WorldClockPickerView.swift
//
//  UI for selecting world clock locations
//

#if os(macOS)
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct WorldClockPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = WorldClockManager.shared
    let onSelect: ((WorldClockLocation) -> Void)?

    init(onSelect: ((WorldClockLocation) -> Void)? = nil) {
        self.onSelect = onSelect
    }

    @State private var searchText = ""
    @State private var selectedCategory: WorldClockLocation.Category = .all

    private var filteredLocations: [WorldClockLocation] {
        let categoryLocations = selectedCategory.locations()

        if searchText.isEmpty {
            return categoryLocations
        }

        return categoryLocations.filter { location in
            location.displayName.localizedCaseInsensitiveContains(searchText) ||
            location.timeZoneIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add World Clock")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            // Category selector
            Picker("Category", selection: $selectedCategory) {
                ForEach(WorldClockLocation.Category.allCases, id: \.self) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 12)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search locations...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 12)

            Divider()

            // Location list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredLocations) { location in
                        LocationRow(location: location, isAdded: manager.savedLocations.contains(where: { $0.id == location.id }))
                            .onTapGesture {
                                addLocation(location)
                            }
                        Divider()
                    }
                }
            }

            if filteredLocations.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No locations found")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Try a different search term")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 500, height: 600)
    }

    private func addLocation(_ location: WorldClockLocation) {
        if let onSelect {
            onSelect(location)
            dismiss()
            return
        }

        // Check if already added
        if manager.savedLocations.contains(where: { $0.id == location.id }) {
            // Just toggle the window if already exists
            manager.toggleWorldClock(for: location)
        } else {
            // Add new location
            manager.addLocation(location)
        }
        dismiss()
    }
}

// MARK: - Location Row

struct LocationRow: View {
    let location: WorldClockLocation
    let isAdded: Bool

    private var currentTime: String {
        guard let timeZone = location.timeZone else { return "" }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(location.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                Text(location.timeZoneIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(currentTime)
                    .font(.body)
                    .foregroundColor(.primary)
                if isAdded {
                    Text("Added")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Manage World Clocks View

struct ManageWorldClocksView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = WorldClockManager.shared
    @State private var showingPicker = false
    @State private var draggingLocationID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("Manage World Clocks")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Add Location…") {
                    showingPicker = true
                }
                .buttonStyle(.borderedProminent)
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Location list
            if manager.savedLocations.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No World Clocks")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Add a world clock to get started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(manager.savedLocations) { location in
                            ManageLocationRow(location: location)
                                .onDrag {
                                    draggingLocationID = location.id
                                    return NSItemProvider(object: location.id.uuidString as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: WorldClockDropDelegate(
                                        target: location,
                                        manager: manager,
                                        draggingLocationID: $draggingLocationID
                                    )
                                )
                            Divider()
                        }
                        Color.clear
                            .frame(height: 12)
                            .onDrop(
                                of: [UTType.text],
                                delegate: WorldClockDropDelegate(
                                    target: nil,
                                    manager: manager,
                                    draggingLocationID: $draggingLocationID
                                )
                            )
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
        .sheet(isPresented: $showingPicker) {
            WorldClockPickerView()
        }
    }
}

// MARK: - Manage Location Row

struct ManageLocationRow: View {
    let location: WorldClockLocation
    @StateObject private var manager = WorldClockManager.shared

    private var currentLocation: WorldClockLocation? {
        manager.savedLocations.first(where: { $0.id == location.id })
    }

    private var isDocked: Bool {
        currentLocation?.isDocked ?? location.isDocked
    }

    private var isWindowOpen: Bool {
        manager.isLocationOpen(id: location.id)
    }

    private var isVisible: Bool {
        isDocked || isWindowOpen
    }

    private var eyeHelpText: String {
        if isDocked {
            return "Remove from dock"
        }

        if isWindowOpen {
            return "Close world clock window"
        }

        return "Dock to main clock"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(location.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                Text(location.timeZoneIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                // Show/Hide button
                Button(action: {
                    handleVisibilityToggle()
                }) {
                    Image(systemName: isVisible ? "eye.fill" : "eye.slash.fill")
                        .foregroundColor(isVisible ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help(eyeHelpText)

                // Remove button
                Button(action: {
                    manager.removeLocation(id: location.id)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Remove")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func handleVisibilityToggle() {
        if isDocked || isWindowOpen {
            // Remove from dock or close the floating window without changing modes
            manager.hideLocation(id: location.id)
        } else {
            // If not visible anywhere, dock it to the main clock
            manager.dockClock(for: location.id)
        }
    }
}

// MARK: - Drag and Drop

private struct WorldClockDropDelegate: DropDelegate {
    let target: WorldClockLocation?
    let manager: WorldClockManager
    @Binding var draggingLocationID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingLocationID else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            if let target {
                manager.moveLocation(draggedID: draggingLocationID, to: target.id)
            } else {
                manager.moveLocationToEnd(draggingLocationID)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingLocationID = nil
        return true
    }
}

// MARK: - Preview

struct WorldClockPickerView_Previews: PreviewProvider {
    static var previews: some View {
        WorldClockPickerView(onSelect: nil)
    }
}

struct ManageWorldClocksView_Previews: PreviewProvider {
    static var previews: some View {
        ManageWorldClocksView()
    }
}
#endif
