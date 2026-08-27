import SwiftUI

enum MainTab: Hashable {
    case lists
    case categories
    case create
    case discover
}

struct MainTabView: View {
    @EnvironmentObject private var session: AppSession
    @State private var selectedTab: MainTab = .lists

    var body: some View {
        TabView(selection: $selectedTab) {
            MyListsView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Lists", systemImage: "list.number")
                }
                .tag(MainTab.lists)

            CategoriesView()
                .tabItem {
                    Label("Categories", systemImage: "square.grid.2x2")
                }
                .tag(MainTab.categories)

            CreateTopTenView()
                .tabItem {
                    Label("Create", systemImage: "plus.circle.fill")
                }
                .tag(MainTab.create)

            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "sparkles")
                }
                .tag(MainTab.discover)
        }
        .tint(Theme.deepTeal)
    }
}
