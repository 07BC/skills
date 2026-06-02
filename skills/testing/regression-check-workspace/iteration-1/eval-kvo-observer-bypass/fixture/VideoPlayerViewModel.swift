//
//  VideoPlayerViewModel.swift
//  MyApp
//

import AVKit
import Combine
import Foundation

final class VideoPlayerViewModel: NSObject, ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isPaused = false

    @Published var videoResolutions: [VideoMetadata] = []
    @Published var previousItems: [MediaItem]?
    @Published var metadata: AVPlayerView.Metadata?
    @Published var hidePauseImage: Bool = false

    @Published var isFollowing: Bool?
    @Published var isSubscribed: Bool?

    @Published var liveTime: String?
    @Published var viewersCount: Int?
    @Published var username: String?

    private let apiClient: APIClientProtocol
    private let loginViewModel: any LoginViewModelProtocol
    private var dismiss: (() -> Void)?
    private var contentSlug: String?
    private var playbackUrl: URL?
    private var subscriptions: Set<AnyCancellable> = []
    private var observations: Set<AnyCancellable> = []

    init(
        player: AVPlayer? = nil,
        apiClient: APIClientProtocol = APIClient(),
        loginViewModel: any LoginViewModelProtocol = LoginViewModel(),
        dismiss: (() -> Void)? = nil
    ) {
        self.player = player
        self.apiClient = apiClient
        self.loginViewModel = loginViewModel
        self.dismiss = dismiss
    }

    func load(contentSlug: String, contentId: Int, playbackUrl: String) {
        Task {
            self.contentSlug = contentSlug
            do {
                let (_, requestedContent) = try await apiClient.fetchContent(slug: contentSlug)
                guard let requestedContent else {
                    dismiss?()
                    return
                }
                username = requestedContent.author?.user?.username
                let result = try await apiClient.fetchUserStatus(id: contentId)
                await MainActor.run {
                    isFollowing = result.isFollowing
                    isSubscribed = result.isSubscribed
                }
            } catch {
                Logger.shared.error(error)
                dismiss?()
            }
        }
        loadPlaybackUrl(playbackUrl)
    }

    func loadPlaybackUrl(_ playbackUrl: String) {
        guard let playbackurl = URL(string: playbackUrl) else {
            dismiss?()
            return
        }
        let asset = AVURLAsset(url: playbackurl)
        let item = AVPlayerItem(asset: asset)
        item.preferredMaximumResolution = .init(width: 1920, height: 1080)
        item.preferredForwardBufferDuration = 5
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true

        if let player {
            player.replaceCurrentItem(with: item)
            player.pause()
        } else {
            let newPlayer = AVPlayer(playerItem: item)
            player = newPlayer
            observePlayerStatus(newPlayer)
            startLiveTimeTimer()
        }

        self.playbackUrl = playbackurl

        item.getResolutions { [weak self] completion in
            switch completion {
            case let .success(videoMetadata):
                if let highestRes = videoMetadata.sorted(by: { left, right in
                    left.resolution.height > right.resolution.height
                }).first, let url = URL(string: highestRes.uri) {
                    let item = AVPlayerItem(asset: AVAsset(url: url))
                    item.preferredForwardBufferDuration = 5
                    self?.player?.replaceCurrentItem(with: item)
                }
                self?.videoResolutions = videoMetadata
            case .failure:
                self?.player?.play()
            }

        }?.store(in: &subscriptions)
    }

    func stopPlayer() {
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    func openItem(_ item: MediaItem, contentId _: Int) {
        if let source = item.source, !source.isEmpty {
            loadItemFromSource(item, url: source)
            return
        }
        PlaybackAPI.requestPlayback(
            item.id,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "",
            token: User.shared.token
        )
        .sink { completion in
            if case let .failure(error) = completion {
                Console.error(error)
                Logger.shared.error(error)
            }
        } receiveValue: { [weak self] result in
            self?.loadItemFromSource(item, url: result.playbackURL)
        }
        .store(in: &subscriptions)
    }

    private func loadItemFromSource(_ item: MediaItem, url: String) {
        metadata = AVPlayerView.Metadata(
            title: item.title,
            subtitle: item.contentSlug,
            image: item.thumbnail?.src,
            description: item.contentUsername,
            rating: item.isMature ? "18+" : nil,
            genre: item.category?.name
        )
        loadPlaybackUrl(url)
    }

    func observePlayerStatus(_ player: AVPlayer) {
        self.player = player
        if player.currentItem != nil {
            player.observe(keyPath: \.currentItem?.status) { oldValue, newValue in
                Console.log("AVPlayerItem.status \(oldValue?.debugDescription ?? "none") → \(newValue?.debugDescription ?? "none")")
                switch newValue {
                case .none:
                    player.pause()
                case .readyToPlay:
                    player.play()
                case .failed: break
                case .unknown: break
                @unknown default:
                    break
                }
            }
            .store(in: &observations)

            player.observe(keyPath: \.timeControlStatus) { [weak self] oldValue, newValue in
                guard oldValue != newValue else { return }
                switch (oldValue, newValue) {
                case (.playing, .paused):
                    self?.isPaused = true
                case (_, _):
                    self?.isPaused = false
                    self?.hidePauseImage = false
                }
            }
            .store(in: &observations)
        }
    }

    private func startLiveTimeTimer() {
        Timer.publish(every: 1, on: .main, in: .default)
            .autoconnect()
            .prepend(.now)
            .sink { [weak self] _ in
                guard let startTime = self?.metadata?.startTime else {
                    self?.liveTime = nil
                    return
                }

                let interval = Date.now.timeIntervalSince(startTime)

                let hours = Int(interval / 60 / 60)
                let minutes = Int(interval / 60) % 60
                let seconds = Int(interval) % 60

                if hours > 0 {
                    self?.liveTime = String(format: "%d:%02d:%02d", hours, minutes, seconds)
                } else {
                    self?.liveTime = String(format: "%02d:%02d", minutes, seconds)
                }
            }
            .store(in: &observations)
    }

    func pause(showPauseIcon: Bool = true) {
        hidePauseImage = !showPauseIcon
        player?.pause()
    }

    // MARK: - Background / Foreground

    private var wasPlayingBeforeBackground = false

    func handleBackground() {
        guard let player else {
            Console.warning("No Player")
            return
        }

        wasPlayingBeforeBackground = player.timeControlStatus == .playing
        player.pause()
    }

    func handleForeground() {
        guard let player else {
            Console.warning("No Player")
            return
        }

        guard wasPlayingBeforeBackground else { return }
        player.play()
    }

    func removeObservers() {
        observations.removeAll()
    }

    deinit {
        removeObservers()
        stopPlayer()
    }
}
