import 'preview_config_base.dart';

/// Abstract base class for preview configuration parameters.
///
/// A [PreviewConfigParams] contains the parameters needed to configure a
/// specific preview state for a [PreviewConfig]. Each [PreviewConfig] should
/// have a corresponding [PreviewConfigParams] subclass.
///
/// Example:
/// ```dart
/// class UserProfileConfigParams extends PreviewConfigParams<UserProfilePreviewConfig> {
///   const UserProfileConfigParams({
///     required this.isLoggedIn,
///     required this.userKey,
///     this.cartItemCount = 0,
///   });
///
///   /// Whether a user should be logged in for this preview.
///   final bool isLoggedIn;
///
///   /// The key identifying which test user to use.
///   final String userKey;
///
///   /// Number of items to populate in the cart.
///   final int cartItemCount;
/// }
/// ```
///
/// Parameters are typically accessed via getter methods on the [PreviewConfig]:
/// ```dart
/// class UserProfilePreviewConfig extends PreviewConfig<UserProfilePage> {
///   // ...
///
///   UserProfileConfigParams get loggedInAdminParams =>
///       UserProfileConfigParams(isLoggedIn: true, userKey: 'admin');
///
///   UserProfileConfigParams get guestWithCartParams =>
///       UserProfileConfigParams(
///         isLoggedIn: false,
///         userKey: '',
///         cartItemCount: 3,
///       );
/// }
/// ```
abstract class PreviewConfigParams {
  /// Creates a preview config params instance.
  const PreviewConfigParams();
}
