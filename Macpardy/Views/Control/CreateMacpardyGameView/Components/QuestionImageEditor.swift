//
//  QuestionImageEditor.swift
//  Macpardy
//

import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// Add, preview, replace and remove the one optional image on a question.
struct QuestionImageEditor: View {

    @Binding
    var image: QuestionImage?

    @State private var showImporter = false
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("create.question.image_label")
                    .font(.headline)
                Text("create.question.image_hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isImporting {
                    ProgressView()
                        .controlSize(.small)
                }
                LoggedButton(image == nil ? LocalizedStringKey("create.question.image_add") : "create.question.image_replace", log: "Editor › Clue › Image › \(image == nil ? "Add" : "Replace")") {
                    showImporter = true
                }
                .disabled(isImporting)
                if image != nil {
                    LoggedButton("create.question.image_remove", log: "Editor › Clue › Image › Remove", role: .destructive) {
                        image = nil
                    }
                    .disabled(isImporting)
                }
            }

            if let image {
                preview(for: image)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: ImageImporter.acceptedTypes
        ) { result in
            UIActionLog.filePicked("file importer 'Clue image'", result)
            switch result {
            case .success(let url):
                importImage(from: url)
            case .failure(let error):
                AppLogger.control.error("Image picker failed: \(error.localizedDescription)")
            }
        }
        .logPresentation("file importer 'Clue image'", isPresented: showImporter)
    }

    @ViewBuilder
    private func preview(for image: QuestionImage) -> some View {
        Group {
            if let nsImage = image.nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(Text("create.question.image_preview_accessibility"))
            } else {
                QuestionImagePlaceholder()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 160)
        .background(Color(.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func importImage(from url: URL) {
        isImporting = true
        errorMessage = nil
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try ImageImporter.importImage(at: url) }
            }.value
            isImporting = false
            switch result {
            case .success(let output):
                AppLogger.control.state("Clue image imported: \(output.data.count) bytes .\(output.fileExtension)")
                image = QuestionImage(
                    path: "\(BoardPackage.imagesDirectory)/\(UUID().uuidString.lowercased()).\(output.fileExtension)",
                    data: output.data
                )
            case .failure(let error):
                errorMessage = Self.message(for: error)
                AppLogger.control.error("Image import failed: \(error.localizedDescription)")
            }
        }
    }

    private static func message(for error: Error) -> String {
        switch error as? ImageImporter.ImportError {
        case .fileTooLarge:
            String(localized: "create.question.image_error.too_large")
        case .unsupportedFormat:
            String(localized: "create.question.image_error.unsupported")
        case .unreadable, .none:
            String(localized: "create.question.image_error.unreadable")
        }
    }
}
