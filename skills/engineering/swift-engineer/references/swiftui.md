# SwiftUI Reference

## View Lifecycle

### Task Modifiers

```swift
struct ContentView: View {
    @State private var data: [Item] = []
    
    var body: some View {
        List(data) { item in
            ItemRow(item: item)
        }
        // Runs when view appears, cancels on disappear
        .task {
            data = await fetchItems()
        }
        // Re-runs when id changes
        .task(id: selectedCategory) {
            data = await fetchItems(for: selectedCategory)
        }
    }
}
```

### Lifecycle Events

```swift
struct DetailView: View {
    var body: some View {
        content
            .onAppear { analytics.trackView() }
            .onDisappear { saveState() }
            .onChange(of: selection) { oldValue, newValue in
                handleSelectionChange(from: oldValue, to: newValue)
            }
    }
}
```

## Observable Pattern (Swift 5.9+)

### Basic Observable

```swift
import Observation

@Observable
final class Store {
    var items: [Item] = []
    var isLoading = false
    var selectedItem: Item?
    
    // Computed properties automatically tracked
    var hasSelection: Bool { selectedItem != nil }
    
    func load() async {
        isLoading = true
        defer { isLoading = false }
        items = await api.fetchItems()
    }
}

struct ItemListView: View {
    @State private var store = Store()
    
    var body: some View {
        List(store.items) { item in
            ItemRow(item: item)
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            }
        }
        .task { await store.load() }
    }
}
```

### Observable with Environment

```swift
@Observable
final class AppState {
    var user: User?
    var preferences: Preferences = .default
}

@main
struct MyApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        if let user = appState.user {
            UserProfile(user: user)
        }
    }
}
```

## Custom Environments

### Environment Keys

```swift
// Define key
struct APIClientKey: EnvironmentKey {
    static let defaultValue: APIClient = LiveAPIClient()
}

extension EnvironmentValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

// Convenience modifier
extension View {
    func apiClient(_ client: APIClient) -> some View {
        environment(\.apiClient, client)
    }
}

// Usage
struct ContentView: View {
    @Environment(\.apiClient) private var api
}

// Injection for tests/previews
#Preview {
    ContentView()
        .apiClient(MockAPIClient())
}
```

## Layout System

### Stacks with Alignment

```swift
VStack(alignment: .leading, spacing: 12) {
    Text("Title").font(.headline)
    Text("Subtitle").font(.subheadline)
}

HStack(alignment: .firstTextBaseline) {
    Text("Label")
    TextField("Value", text: $value)
}
```

### Lazy Stacks

```swift
// Only renders visible items
ScrollView {
    LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
        ForEach(sections) { section in
            Section {
                ForEach(section.items) { item in
                    ItemRow(item: item)
                }
            } header: {
                SectionHeader(title: section.title)
            }
        }
    }
}
```

### Grid Layout

```swift
// Fixed columns
LazyVGrid(columns: [
    GridItem(.fixed(100)),
    GridItem(.fixed(100)),
    GridItem(.fixed(100))
], spacing: 16) {
    ForEach(items) { item in
        ItemCell(item: item)
    }
}

// Adaptive columns
LazyVGrid(columns: [
    GridItem(.adaptive(minimum: 80, maximum: 120))
]) {
    ForEach(items) { item in
        ItemCell(item: item)
    }
}

// Flexible columns
LazyVGrid(columns: [
    GridItem(.flexible(minimum: 50)),
    GridItem(.flexible(minimum: 50)),
    GridItem(.flexible(minimum: 50))
]) {
    ForEach(items) { item in
        ItemCell(item: item)
    }
}
```

### ViewThatFits

```swift
ViewThatFits {
    // Try horizontal first
    HStack {
        icon
        label
        Spacer()
        button
    }
    // Fall back to vertical
    VStack {
        HStack {
            icon
            label
        }
        button
    }
}
```

## Navigation

### NavigationStack

```swift
struct RootView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: User.self) { user in
                    UserDetailView(user: user)
                }
                .navigationDestination(for: Post.self) { post in
                    PostDetailView(post: post)
                }
        }
    }
}

struct HomeView: View {
    @Binding var path: NavigationPath
    
    var body: some View {
        List(users) { user in
            NavigationLink(value: user) {
                UserRow(user: user)
            }
        }
        .toolbar {
            Button("Go to Settings") {
                path.append(Settings())
            }
        }
    }
}
```

### Deep Linking

```swift
@Observable
final class Router {
    var path = NavigationPath()
    
    func navigate(to destination: any Hashable) {
        path.append(destination)
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
    
    func handle(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host else { return }
        
        switch host {
        case "user":
            if let id = components.queryItems?.first(where: { $0.name == "id" })?.value {
                path.append(UserDestination(id: id))
            }
        case "post":
            if let id = components.queryItems?.first(where: { $0.name == "id" })?.value {
                path.append(PostDestination(id: id))
            }
        default:
            break
        }
    }
}
```

## Sheets and Alerts

### Item-Based Sheets

```swift
struct ContentView: View {
    @State private var selectedItem: Item?
    @State private var showSettings = false
    
    var body: some View {
        List(items) { item in
            Button(item.title) {
                selectedItem = item
            }
        }
        // Item-based (preferred)
        .sheet(item: $selectedItem) { item in
            ItemDetailView(item: item)
        }
        // Boolean-based
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}
```

### Confirmation Dialogs

```swift
struct ItemRow: View {
    @State private var showDeleteConfirmation = false
    let item: Item
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text(item.title)
            Spacer()
            Button("Delete", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
        .confirmationDialog(
            "Delete Item",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }
}
```

## Custom View Modifiers

### Basic Modifier

```swift
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
```

### Configurable Modifier

```swift
struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.5), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: phase)
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            phase = 200
                        }
                    }
                }
            }
            .clipped()
    }
}

extension View {
    func shimmer(isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}
```

## Preferences

### Reading Child Geometry

```swift
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

extension View {
    func readSize(_ onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geo.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

// Usage
struct DynamicView: View {
    @State private var childSize: CGSize = .zero
    
    var body: some View {
        VStack {
            ChildView()
                .readSize { childSize = $0 }
            
            Text("Child is \(Int(childSize.width))x\(Int(childSize.height))")
        }
    }
}
```

## Animations

### Explicit Animations

```swift
struct AnimatedCard: View {
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            content
        }
        .frame(height: isExpanded ? 300 : 100)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
        .onTapGesture {
            isExpanded.toggle()
        }
    }
}
```

### Transitions

```swift
struct ContentView: View {
    @State private var showDetail = false
    
    var body: some View {
        VStack {
            if showDetail {
                DetailView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut, value: showDetail)
    }
}
```

### Phased Animations (iOS 17+)

```swift
struct PulsatingButton: View {
    var body: some View {
        Button("Tap") {}
            .phaseAnimator([false, true]) { content, phase in
                content
                    .scaleEffect(phase ? 1.1 : 1.0)
                    .opacity(phase ? 0.8 : 1.0)
            } animation: { phase in
                .easeInOut(duration: 0.5)
            }
    }
}
```

## Previews

### Multi-Configuration Previews

```swift
#Preview("Light Mode") {
    ContentView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    ContentView()
        .preferredColorScheme(.dark)
}

#Preview("Large Text") {
    ContentView()
        .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("With Mock Data") {
    ContentView()
        .environment(MockDataStore())
}
```

### Interactive Previews

```swift
#Preview {
    @Previewable @State var isOn = false
    
    Toggle("Enable Feature", isOn: $isOn)
        .padding()
}
```
