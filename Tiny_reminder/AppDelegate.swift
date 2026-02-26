import SwiftUI
import UIKit

// App delegate to control supported interface orientations
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // iPhone: portrait only; iPad: allow portrait and upside down (common practice)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return [.portrait, .portraitUpsideDown]
        } else {
            return [.portrait]
        }
    }
}
