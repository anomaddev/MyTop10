import Foundation
import SwiftUI
import UIKit
import GoogleMobileAds

enum AdMobService {
    static func start() {
        MobileAds.shared.start(completionHandler: nil)
    }

    static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

struct BannerAdView: UIViewRepresentable {
    let unitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = unitID
        banner.rootViewController = AdMobService.rootViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}

@MainActor
final class InterstitialAdCoordinator: NSObject, FullScreenContentDelegate {
    private var interstitial: InterstitialAd?
    private let unitID: String

    init(unitID: String = AppConfig.admobInterstitialUnitID) {
        self.unitID = unitID
        super.init()
        load()
    }

    func load() {
        InterstitialAd.load(with: unitID, request: Request()) { [weak self] ad, _ in
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
        }
    }

    func showIfReady() {
        guard let interstitial, let root = AdMobService.rootViewController() else { return }
        interstitial.present(from: root)
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        load()
    }
}
