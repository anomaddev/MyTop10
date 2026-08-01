import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var session: AppSession
    @State private var lists: [TopTen] = []
    @State private var bookmarks: [TopTen] = []
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                List {
                    if !bookmarks.isEmpty {
                        Section("Bookmarked") {
                            ForEach(bookmarks) { list in
                                NavigationLink(value: list.id) {
                                    TopTenRow(list: list)
                                }
                                .listRowBackground(Color.white.opacity(0.65))
                            }
                        }
                    }

                    Section("Trending public lists") {
                        ForEach(Array(lists.enumerated()), id: \.element.id) { index, list in
                            NavigationLink(value: list.id) {
                                TopTenRow(list: list)
                            }
                            .listRowBackground(Color.white.opacity(0.65))

                            if index == 2 {
                                BannerAdView(unitID: AppConfig.admobBannerUnitID)
                                    .frame(height: 50)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets())
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
            .navigationTitle("Discover")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileBubble(profile: session.profile) {
                        showProfile = true
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                TopTenDetailView(listId: id)
            }
            .sheet(isPresented: $showProfile) {
                NavigationStack {
                    ProfileView(userId: session.auth.uid ?? "", isSelf: true)
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        lists = (try? await session.lists.fetchDiscover()) ?? []
        if let uid = session.auth.uid {
            bookmarks = (try? await session.lists.fetchBookmarks(userId: uid)) ?? []
        }
    }
}
