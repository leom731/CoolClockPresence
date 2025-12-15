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
    @State private var deletionSnapshot: PhotoDeletionSnapshot?
    @State private var undoWorkItem: DispatchWorkItem?

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
                            ManagePhotoRow(photo: photo, onRemove: handleDelete)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(width: 520, height: 420)
        .overlay(alignment: .bottom) {
            if let snapshot = deletionSnapshot {
                UndoBannerView(
                    title: "Photo deleted",
                    subtitle: snapshot.item.displayName,
                    undoAction: undoDeletion,
                    dismissAction: dismissUndoBanner
                )
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: deletionSnapshot != nil)
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

    private func handleDelete(_ photo: PhotoItem) {
        guard let snapshot = manager.removePhotoWithSnapshot(id: photo.id) else { return }

        undoWorkItem?.cancel()
        withAnimation {
            deletionSnapshot = snapshot
        }

        scheduleUndoDismiss()
    }

    private func undoDeletion() {
        undoWorkItem?.cancel()
        if let snapshot = deletionSnapshot {
            manager.restorePhoto(from: snapshot)
        }

        withAnimation {
            deletionSnapshot = nil
        }
    }

    private func dismissUndoBanner() {
        undoWorkItem?.cancel()
        withAnimation {
            deletionSnapshot = nil
        }
    }

    private func scheduleUndoDismiss() {
        let workItem = DispatchWorkItem {
            withAnimation {
                deletionSnapshot = nil
            }
        }

        undoWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: workItem)
    }
}

struct ManagePhotoRow: View {
    let photo: PhotoItem
    let onRemove: (PhotoItem) -> Void
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
                    onRemove(photo)
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

private struct UndoBannerView: View {
    let title: String
    let subtitle: String
    let undoAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Undo") {
                undoAction()
            }
            .buttonStyle(.borderedProminent)

            Button(action: dismissAction) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
    }
}

struct ManagePhotosView_Previews: PreviewProvider {
    static var previews: some View {
        ManagePhotosView()
    }
}
#endif
