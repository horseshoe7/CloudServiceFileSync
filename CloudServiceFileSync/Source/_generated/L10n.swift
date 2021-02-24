// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name
internal enum L10n {

  internal enum CloudServiceController {
    internal enum Sync {
      /// Preparing to sync...
      internal static let preparing = L10n.tr("CloudServiceKit", "CloudServiceController.Sync.preparing")
      /// Syncing...
      internal static let syncingFile = L10n.tr("CloudServiceKit", "CloudServiceController.Sync.syncingFile")
      internal enum CouldNotBegin {
        /// Unable to sync.  You aren't signed in to your cloud service.
        internal static let auth = L10n.tr("CloudServiceKit", "CloudServiceController.Sync.couldNotBegin.auth")
        /// Unable to sync.  The sync manager reports not being ready, perhaps because of a failure last time it tried to sync.
        internal static let other = L10n.tr("CloudServiceKit", "CloudServiceController.Sync.couldNotBegin.other")
      }
      internal enum Details {
        internal enum DeleteResult {
          internal enum Filename {
            /// %@ - DELETE - %@
            internal static func success(_ p1: String, _ p2: String) -> String {
              return L10n.tr("CloudServiceKit", "CloudServiceController.Sync.details.deleteResult.filename.success", p1, p2)
            }
          }
        }
        internal enum DownloadResult {
          internal enum Filename {
            /// %@ - DOWNLOAD - %@
            internal static func success(_ p1: String, _ p2: String) -> String {
              return L10n.tr("CloudServiceKit", "CloudServiceController.Sync.details.downloadResult.filename.success", p1, p2)
            }
          }
        }
        internal enum UploadResult {
          internal enum Filename {
            /// %@ - UPLOAD - %@
            internal static func success(_ p1: String, _ p2: String) -> String {
              return L10n.tr("CloudServiceKit", "CloudServiceController.Sync.details.uploadResult.filename.success", p1, p2)
            }
          }
        }
      }
    }
  }

  internal enum Words {
    /// Cancel
    internal static let cancel = L10n.tr("CloudServiceKit", "Words.Cancel")
    /// failed
    internal static let failed = L10n.tr("CloudServiceKit", "Words.failed")
    /// OK
    internal static let ok = L10n.tr("CloudServiceKit", "Words.OK")
    /// succeeded
    internal static let succeeded = L10n.tr("CloudServiceKit", "Words.succeeded")
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    // swiftlint:disable:next nslocalizedstring_key
    let format = NSLocalizedString(key, tableName: table, bundle: Bundle(for: BundleToken.self), comment: "")
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

private final class BundleToken {}
