// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  ManagePhotosView.swift
//
//  UI for showing/hiding/removing photo windows
//

#if os(macOS)
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ManagePhotosView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = PhotoWindowManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("Manage Photos")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Add Photo…") {
                    showPhotoPicker()
                }
                .buttonStyle(.borderedProminent)
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            if manager.savedPhotos.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Photos")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Add a photo to get started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(manager.savedPhotos) { photo in
                            ManagePhotoRow(photo: photo)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(width: 520, height: 420)
    }

    private func showPhotoPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.title = "Choose a Photo"

        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            manager.addPhoto(from: url)
        }
    }
}

struct ManagePhotoRow: View {
    let photo: PhotoItem
    @ObservedObject private var manager = PhotoWindowManager.shared

    private var isOpen: Bool {
        manager.isPhotoOpen(id: photo.id)
    }

    private var previewImage: NSImage? {
        manager.image(for: photo)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 70, height: 70)

                if let previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(photo.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                if let original = photo.originalFileName {
                    Text(original)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: {
                    manager.togglePhotoWindow(for: photo)
                }) {
                    Image(systemName: isOpen ? "eye.fill" : "eye.slash.fill")
                        .foregroundColor(isOpen ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help(isOpen ? "Hide" : "Show")

                Button(action: {
                    manager.removePhoto(id: photo.id)
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
}

struct ManagePhotosView_Previews: PreviewProvider {
    static var previews: some View {
        ManagePhotosView()
    }
}
#endif
