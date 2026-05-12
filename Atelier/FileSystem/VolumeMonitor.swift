import Foundation
import AppKit

final class VolumeMonitor: @unchecked Sendable {
    var onMount: ((URL) -> Void)?
    var onUnmount: ((URL) -> Void)?

    private var mountObserver: NSObjectProtocol?
    private var unmountObserver: NSObjectProtocol?

    func start() {
        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter

        mountObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
            self.onMount?(url)
        }

        unmountObserver = notificationCenter.addObserver(
            forName: NSWorkspace.willUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
            self.onUnmount?(url)
        }
    }

    func stop() {
        if let observer = mountObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = unmountObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
