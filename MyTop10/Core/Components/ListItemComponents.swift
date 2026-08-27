import SwiftUI
import PhotosUI
import UIKit

struct TagChip: View {
    let text: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.custom("AvenirNext-Medium", size: 12))
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(Theme.deepTeal)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.lagoon.opacity(0.15))
        .clipShape(Capsule())
    }
}

struct TagEditor: View {
    @Binding var tags: [String]
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: "Tags")
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    TagChip(text: tag) {
                        tags.removeAll { $0 == tag }
                    }
                }
            }
            HStack {
                TextField("Add tag + return", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.custom("AvenirNext-Medium", size: 15))
                    .onSubmit(addTag)
                Button("Add", action: addTag)
                    .font(.custom("AvenirNext-DemiBold", size: 14))
                    .foregroundStyle(Theme.deepTeal)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func addTag() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty, !tags.contains(value), tags.count < 12 else { return }
        tags.append(value)
        draft = ""
    }
}

struct StarRatingControl: View {
    @Binding var rating: Int?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    rating = rating == star ? nil : star
                } label: {
                    Image(systemName: (rating ?? 0) >= star ? "star.fill" : "star")
                        .font(.system(size: 22))
                        .foregroundStyle((rating ?? 0) >= star ? Theme.amber : Theme.mutedText.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
            if rating != nil {
                Button("Clear") { rating = nil }
                    .font(.custom("AvenirNext-Medium", size: 12))
                    .foregroundStyle(Theme.mutedText)
            }
        }
    }
}

struct PhotoStripEditor: View {
    @Binding var remoteUrls: [String]
    @Binding var localPhotos: [Data]
    @State private var pickerItems: [PhotosPickerItem] = []

    private let maxPhotos = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: "Photos")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(remoteUrls.enumerated()), id: \.offset) { index, urlString in
                        photoThumb {
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image): image.resizable().scaledToFill()
                                    default: Theme.mist
                                    }
                                }
                            }
                        } onRemove: {
                            remoteUrls.remove(at: index)
                        }
                    }
                    ForEach(Array(localPhotos.enumerated()), id: \.offset) { index, data in
                        photoThumb {
                            if let ui = UIImage(data: data) {
                                Image(uiImage: ui).resizable().scaledToFill()
                            }
                        } onRemove: {
                            localPhotos.remove(at: index)
                        }
                    }

                    if remoteUrls.count + localPhotos.count < maxPhotos {
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: maxPhotos, matching: .images) {
                            VStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Add")
                                    .font(.custom("AvenirNext-Medium", size: 11))
                            }
                            .foregroundStyle(Theme.deepTeal)
                            .frame(width: 84, height: 84)
                            .background(Theme.lagoon.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .onChange(of: pickerItems) { _, items in
                Task { await loadPhotos(items) }
            }
        }
    }

    @ViewBuilder
    private func photoThumb<Content: View>(
        @ViewBuilder content: () -> Content,
        onRemove: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            content()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Theme.coral)
            }
            .offset(x: 6, y: -6)
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var remaining = maxPhotos - remoteUrls.count - localPhotos.count
        guard remaining > 0 else { return }
        for item in items {
            guard remaining > 0 else { break }
            if let data = try? await item.loadTransferable(type: Data.self) {
                localPhotos.append(data)
                remaining -= 1
            }
        }
        pickerItems = []
    }
}

/// Simple wrapping layout for tag chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight), frames)
    }
}

struct TopTenItemRow: View {
    let item: TopTenItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(item.rank)")
                .font(.custom("AvenirNext-Heavy", size: 24))
                .foregroundStyle(Theme.amber)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.custom("AvenirNext-DemiBold", size: 16))
                        .foregroundStyle(Theme.ink)
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.coral)
                    }
                }

                if item.hasNote {
                    Text(item.note!)
                        .font(.custom("AvenirNext-Regular", size: 13))
                        .foregroundStyle(Theme.mutedText)
                        .lineLimit(2)
                }

                if item.hasTags {
                    FlowLayout(spacing: 6) {
                        ForEach(item.tags.prefix(4), id: \.self) { tag in
                            TagChip(text: tag)
                        }
                    }
                }

                HStack(spacing: 10) {
                    if let rating = item.rating {
                        Label("\(rating)/5", systemImage: "star.fill")
                            .foregroundStyle(Theme.amber)
                    }
                    if item.hasLocation {
                        Label(item.placeName ?? "Pinned", systemImage: "mappin.and.ellipse")
                            .foregroundStyle(Theme.deepTeal)
                    }
                    if item.hasPhotos {
                        Label("\(item.photoUrls.count)", systemImage: "photo")
                            .foregroundStyle(Theme.lagoon)
                    }
                    if item.visitedOn != nil {
                        Label("Visited", systemImage: "checkmark.circle")
                            .foregroundStyle(Theme.lagoon)
                    }
                }
                .font(.custom("AvenirNext-Medium", size: 11))

                if item.hasPhotos, let first = item.photoUrls.first, let url = URL(string: first) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Theme.mist
                        }
                    }
                    .frame(height: 88)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
