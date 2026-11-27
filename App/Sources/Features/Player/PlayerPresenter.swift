import AVFoundation
import AVKit
import JellyfinAPI
import UIKit

/// Full-screen player using Apple's own controls (AVPlayerViewController), presented over the app.
/// Native presentation gives the Done button and swipe-to-dismiss on iPhone/iPad and the Menu/Back
/// button on Apple TV, and lets us report the stop position when it closes.
@MainActor
final class PlayerPresenter {
    static let shared = PlayerPresenter()

    private var current: PlayerController?

    func play(_ session: PlaybackSession, onFinish: @escaping () -> Void) async throws {
        configureAudioSession()
        let playerItem = try await session.makePlayerItem()
        let controller = PlayerController(session: session, playerItem: playerItem) { [weak self] in
            self?.current = nil
            onFinish()
        }
        current = controller
        guard let presenter = Self.topViewController() else { return }
        presenter.present(controller, animated: true) {
            controller.start()
        }
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// AVPlayerViewController that owns one playback session's lifecycle.
final class PlayerController: AVPlayerViewController {
    private let session: PlaybackSession
    private let playerItem: AVPlayerItem
    private let onFinish: () -> Void

    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var lastReported = Date.distantPast
    private var started = false
    private var finished = false

    init(session: PlaybackSession, playerItem: AVPlayerItem, onFinish: @escaping () -> Void) {
        self.session = session
        self.playerItem = playerItem
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @MainActor
    func start() {
        let player = AVPlayer(playerItem: playerItem)
        // Stop AVPlayer choosing subtitles from the file's flags or the system caption setting.
        // Tracks are chosen from the user's defaults in applySubtitleSelection instead.
        player.appliesMediaSelectionCriteriaAutomatically = false
        self.player = player

        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            Task { @MainActor in await self?.itemReady() }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 1),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
    }

    @MainActor
    private func itemReady() async {
        guard !started, let player else { return }
        started = true
        statusObservation = nil

        await session.applySubtitleSelection(to: playerItem)

        let start = session.startSeconds
        if start > 0 {
            _ = await player.seek(to: CMTime(seconds: start, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        player.play()
        await session.reportStart(positionSeconds: start)
    }

    /// Reports progress every 10 seconds while playing, and straight away on pause.
    @MainActor
    private func tick() async {
        guard started, !finished, let player else { return }
        let isPaused = player.timeControlStatus == .paused
        guard Date().timeIntervalSince(lastReported) >= 10 || isPaused else { return }
        if isPaused, lastReported > Date().addingTimeInterval(-10) { return }
        lastReported = Date()
        await session.reportProgress(positionSeconds: player.currentTime().seconds, isPaused: isPaused)
    }

    @MainActor
    private func close() {
        if presentingViewController != nil, !isBeingDismissed {
            dismiss(animated: true)
        } else {
            finish()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil {
            finish()
        }
    }

    @MainActor
    private func finish() {
        guard !finished else { return }
        finished = true
        let position = player?.currentTime().seconds ?? 0
        player?.pause()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
        let session = session
        let onFinish = onFinish
        Task { @MainActor in
            await session.reportStopped(positionSeconds: position)
            onFinish()
        }
    }
}
