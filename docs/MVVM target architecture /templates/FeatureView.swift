// MVVM TEMPLATE — replace FeatureName / Item with project types.
// FeatureScreen reads the repository from @Environment and passes it into FeatureView.
// FeatureView owns the ViewModel via @State — never register ViewModels in @Environment.
import SwiftUI

// MARK: - Screen (reads from @Environment, owns nothing)

struct FeatureScreen: View {
    @Environment(\.featureRepository) private var repository

    var body: some View {
        FeatureView(repository: repository)
    }
}

// MARK: - View (owns ViewModel)

struct FeatureView: View {

    @State private var viewModel: FeatureViewModel

    init(repository: any FeatureRepositoryProtocol) {
        _viewModel = State(initialValue: FeatureViewModel(repository: repository))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
            } else if let error = viewModel.error, viewModel.items.isEmpty {
                ErrorView(error: error)
            } else {
                content
            }
        }
        .task { viewModel.load() }
    }

    // MARK: - Private views

    private var content: some View {
        List {
            ForEach(viewModel.items) { item in
                ItemRow(item: item)
            }

            if viewModel.hasMore {
                ProgressView()
                    .onAppear { viewModel.loadNextPage() }
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
    let repo = MockFeatureRepository()
    repo.fetchResult = .success(PaginatedResponse(
        data: [.fixture(), .fixture()],
        currentPage: 1,
        hasNextPage: false
    ))
    return FeatureView(repository: repo)
}

#Preview("Loading") {
    let repo = MockFeatureRepository()
    repo.fetchDelay = .seconds(60)
    return FeatureView(repository: repo)
}

#Preview("Error") {
    let repo = MockFeatureRepository()
    repo.fetchResult = .failure(.unknown("Connection failed"))
    return FeatureView(repository: repo)
}
