import 'package:flutter/widgets.dart';
import 'package:preview_config/preview_config.dart';

/// Abstract base class for preview configurations.
///
/// A [PreviewConfig] defines how to navigate to and set up a specific page
/// widget [T] for preview. Each page in your app should have a corresponding
/// [PreviewConfig] subclass.
///
/// **Important Design Principles:**
/// - The [execute] method should be **fast** - call helper methods on your
///   app's services/providers to set state
/// - Avoid network calls when possible; if necessary, make them **idempotent**
/// - Each execution should not affect subsequent runs
///
/// Example:
/// ```dart
/// class UserProfilePreviewConfig extends PreviewConfig<UserProfilePage> {
///   UserProfilePreviewConfig();
///
///   @override
///   Future<void> execute<P extends PreviewConfigParams<UserProfilePreviewConfig>>(
///     P params,
///   ) async {
///     final p = params as UserProfileConfigParams;
///     final previewManager = AppPreviewManager.instance;
///
///     // Call helper methods that manipulate your app's services
///     if (p.isLoggedIn) {
///       await previewManager.loginTestUser(p.userKey);
///     }
///     previewManager.setCartItemCount(p.cartItems);
///     previewManager.setSubscriptionTier(p.tier);
///
///     // Navigate to the page...
///   }
///
///   // ============================================================
///   // Preview Config Params
///   // ============================================================
///
///   UserProfileConfigParams get loggedInAdminParams =>
///       UserProfileConfigParams(isLoggedIn: true, userKey: 'admin');
///
///   UserProfileConfigParams get guestParams =>
///       UserProfileConfigParams(isLoggedIn: false, userKey: '');
/// }
/// ```
abstract class PreviewConfig<T extends Widget, S extends PreviewConfigParams> {
  PreviewConfig();

  BuildContext get navigatorContext => PreviewManager.navigatorContext;

  /// Executes the preview configuration with the given [params].
  ///
  /// This method should:
  /// 1. Call helper methods on your PreviewManager to set up app state
  /// 2. Navigate to the target page
  ///
  /// Override this method with the concrete [PreviewConfigParams] type for
  /// your page.
  Future<void> execute(S params);

  @protected
  Future<void> internalExecute(S params) async {
    try {
      PreviewManager.resetPageStateInfo<T>();
      await execute(params);
    } finally {
      PreviewManager.resetPageStateInfo<T>();
    }
  }
}
