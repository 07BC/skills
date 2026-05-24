// TEMPLATE — replace FeatureName / Item with project types.
import SwiftUI

struct FeatureView: View {

    @Environment(\.featureService) private var service

    var body: some View {
        Group {
            if service.isLoading && service.items.isEmpty {
                ProgressView()
            } else if let error = service.error, service.items.isEmpty {
                ErrorView(error: error)
            } else {
                content
            }
        }
        .task { service.load() }
    }

    // MARK: - Private views

    private var content: some View {
        List {
            ForEach(service.items) { item in
                ItemRow(item: item)
            }

            if service.hasMore {
                ProgressView()
                    .onAppear { service.loadNextPage() }
            }
        }
    }
}

// MARK: - Row (separate file in production)

struct ItemRow: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
            Text(item.title)
                .font(.headline)
        }
        .padding(UIConstants.Padding.card)
    }
}

// MARK: - Error view (shared component)

struct ErrorView: View {
    let error: AppError

    var body: some View {
        VStack(spacing: UIConstants.Spacing.medium) {
            Text("Something went wrong")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(UIConstants.Padding.screen)
    }
}

// MARK: - Previews

#Preview("Loaded") {
    FeatureView()
        .environment(\.featureService, {
            let mock = MockFeatureService()
            mock.items = [.fixture(), .fixture()]
            return mock
        }())
}

#Preview("Loading") {
    FeatureView()
        .environment(\.featureService, {
            let mock = MockFeatureService()
            mock.isLoading = true
            return mock
        }())
}

#Preview("Error") {
    FeatureView()
        .environment(\.featureService, {
            let mock = MockFeatureService()
            mock.error = .unknown("Connection failed")
            return mock
        }())
}
