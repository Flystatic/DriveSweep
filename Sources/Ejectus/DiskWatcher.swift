import DiskArbitration
import Foundation

/// Cleans a volume right before macOS unmounts it (Finder eject, drag to Trash, diskutil, ...).
/// The clean runs inside the unmount-approval callback, then we approve so the eject carries on.
final class DiskWatcher {
    private let session: DASession
    private let queue = DispatchQueue(label: "Ejectus.diskarbitration")
    private let isEnabled: () -> Bool
    private let onCleaned: (String, SweepResult) -> Void

    init(isEnabled: @escaping () -> Bool, onCleaned: @escaping (String, SweepResult) -> Void) {
        self.isEnabled = isEnabled
        self.onCleaned = onCleaned
        session = DASessionCreate(kCFAllocatorDefault)!
        DASessionSetDispatchQueue(session, queue)

        let context = Unmanaged.passUnretained(self).toOpaque()
        DARegisterDiskUnmountApprovalCallback(session, nil, { disk, context in
            Unmanaged<DiskWatcher>.fromOpaque(context!).takeUnretainedValue().willUnmount(disk)
            return nil  // nil = approve, eject continues
        }, context)
    }

    private func willUnmount(_ disk: DADisk) {
        guard isEnabled(),
              let desc = DADiskCopyDescription(disk) as? [CFString: Any],
              let url = desc[kDADiskDescriptionVolumePathKey] as? URL,
              Volumes.isEligible(url),
              !UserDefaults.standard.isSkipped(url)
        else { return }

        let result = Sweeper.fullClean(volume: url, deadline: Date().addingTimeInterval(15),
                                        emptyTrash: UserDefaults.standard.emptyDriveTrash)
        onCleaned(Volumes.name(of: url), result)
    }
}
