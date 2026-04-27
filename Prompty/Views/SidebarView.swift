import SwiftUI
import SwiftData
import AppKit

struct SidebarView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\PromptDocument.updatedAt, order: .reverse)])
    private var documents: [PromptDocument]

    @Binding var selection: PromptDocument?

    var body: some View {
        VStack(spacing: 0) {
            mainList
            Divider()
            footerLink
        }
        .frame(minWidth: 220)
        .navigationTitle("Prompty")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createEmpty) {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("New prompt (⌘N)")
                .clickable()
            }
        }
    }

    private var mainList: some View {
        List(selection: $selection) {
            if !documents.isEmpty {
                Section("Prompts") {
                    ForEach(documents) { doc in
                        NavigationLink(value: doc) {
                            row(for: doc)
                        }
                        .contextMenu {
                            Button("Duplicate") { duplicate(doc) }
                            Divider()
                            Button("Delete", role: .destructive) { delete(doc) }
                        }
                    }
                    .onDelete(perform: deleteIndexed)
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if documents.isEmpty {
                emptyState
            }
        }
    }

    private var footerLink: some View {
        Button {
            if let url = URL(string: "https://x.com/ducaswtf") {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image("AppLogo")
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                Text("Made by **@ducaswtf**")
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Follow on X")
        .clickable()
    }

    private func row(for doc: PromptDocument) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(doc.name.isEmpty ? "Untitled" : doc.name)
                .font(.body)
                .lineLimit(1)
            Text(doc.updatedAt.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .opacity(0.7)
            Text("No prompts yet")
                .font(.subheadline.weight(.medium))
            Text("Pick a template on the right or hit ⌘N")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func createEmpty() {
        let doc = PromptDocument(name: "New Prompt", blocks: PromptTemplate.empty.makeBlocks())
        context.insert(doc)
        try? context.save()
        selection = doc
    }

    private func duplicate(_ doc: PromptDocument) {
        let copy = PromptDocument(name: doc.name + " Copy", blocks: doc.blocks)
        context.insert(copy)
        try? context.save()
        selection = copy
    }

    private func delete(_ doc: PromptDocument) {
        if selection == doc { selection = nil }
        context.delete(doc)
        try? context.save()
    }

    private func deleteIndexed(_ offsets: IndexSet) {
        for index in offsets {
            delete(documents[index])
        }
    }
}
