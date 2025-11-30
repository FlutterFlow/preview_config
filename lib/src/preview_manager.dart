import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:preview_config/preview_config.dart';

/// Abstract base class providing helper methods for manipulating app state during previews.
///
/// The [PreviewManager] provides utilities for manipulating your application's
/// existing state during previews, such as logging in test users or calling methods
/// on your app's services/providers.
///
/// **Important**: This class should NOT store any state itself. It only provides
/// helper methods that manipulate your app's existing state management (providers,
/// services, etc.).
///
/// **Design Principles:**
/// - The subclass should be a **singleton** initialized once in the preview entrypoint
/// - Methods should manipulate your app's existing state, not store state here
/// - Prefer fast, in-memory state changes in your app's services
/// - If network calls are necessary, they should be idempotent
///
/// Extend this class to add helper methods specific to your app:
///
/// ```dart
/// class AppPreviewManager extends PreviewManager {
///   AppPreviewManager._();
///
///   // Singleton instance
///   static final instance = AppPreviewManager._();
///
///   @override
///   Map<String, PreviewTestUser> get testUsers => {
///     'admin': PreviewTestUser(
///       email: 'admin@example.com',
///       passwordEnvVariable: 'TEST_ADMIN_PASSWORD',
///     ),
///     'guest': PreviewTestUser(
///       email: 'guest@example.com',
///       password: 'guest123',
///     ),
///   };
///
///   /// Calls the cart service to set item count.
///   void setCartItemCount(int count) {
///     final cartService = Provider.of<CartService>(appContext, listen: false);
///     cartService.setItemCount(count);
///   }
///
///   /// Calls the subscription service to set tier.
///   void setSubscriptionTier(String tier) {
///     final subscriptionService = Provider.of<SubscriptionService>(appContext, listen: false);
///     subscriptionService.setTier(tier);
///   }
/// }
/// ```
abstract class PreviewManager {
  /// Creates a preview manager instance.
  PreviewManager() {
    _instance = this;
    initialized = true;
  }

  /// The singleton instance of the preview manager.
  static late PreviewManager _instance;
  static bool initialized = false;
  void initialize({GlobalKey<NavigatorState>? navigatorKey}) {
    initialized = true;
    if (navigatorKey != null) {
      _instance._appNavigatorKey = navigatorKey;
    }
  }

  /// Navigator context management
  ///
  /// The app level [GlobalKey] (for the [NavigatorState]) is set during preview
  /// initialization, which is useful for navigation, and in some cases accessing
  /// app-level providers and services.

  GlobalKey<NavigatorState>? _appNavigatorKey;
  static void setNavigatorKey(GlobalKey<NavigatorState> key) =>
      initialized ? _instance._appNavigatorKey = key : null;
  static BuildContext get navigatorContext {
    if (!initialized) {
      throw StateError('Preview manager not initialized');
    }
    final context = _instance._appNavigatorKey?.currentContext;
    if (context == null) {
      throw StateError('App navigator key not set');
    }
    return context;
  }

  /// Page context and state management
  ///
  /// The page contexts are used during the [PreviewConfig.execute] method to
  /// access the page-level providers and services.

  final Map<Type, _PreviewPageState> _pageStateInfos = {};
  static _PreviewPageState _getPageStateInfo<T extends Widget>() =>
      _instance._pageStateInfos[T] ??= _PreviewPageState();
  Future<BuildContext> getPageContext<T extends Widget>() =>
      _getPageStateInfo<T>().getContext();
  Future<S> getPageState<T extends StatefulWidget, S extends State<T>>() =>
      _getPageStateInfo<T>().getState<S>();
  static void registerContext<T extends Widget>(BuildContext context) =>
      initialized ? _getPageStateInfo<T>().updateContext(context) : null;
  static void registerState<T extends StatefulWidget>(State<T> state) =>
      initialized ? _getPageStateInfo<T>().updateState(state) : null;
  static void resetPageStateInfo<T extends Widget>() {
    if (!initialized) return;
    _instance._pageStateInfos[T]?.resetCompleter();
    _instance._pageStateInfos.entries
        .where((e) => !e.value.isActive)
        .toList()
        .forEach((e) => _instance._pageStateInfos.remove(e.key));
  }

  /// Returns the map of test users available for preview authentication.
  ///
  /// Override this getter to define your test users:
  /// ```dart
  /// @override
  /// Map<String, PreviewTestUser> get testUsers => {
  ///   'admin': PreviewTestUser(
  ///     email: 'admin@example.com',
  ///     passwordEnvVariable: 'TEST_ADMIN_PASSWORD',
  ///   ),
  ///   'guest': PreviewTestUser(
  ///     email: 'guest@example.com',
  ///     password: 'guest123',
  ///   ),
  /// };
  /// ```
  Map<String, PreviewTestUser> get testUsers;

  /// Returns the test user associated with [key].
  ///
  /// Throws [ArgumentError] if no user exists for the given key.
  PreviewTestUser getTestUser(String key) {
    final user = testUsers[key];
    if (user == null) {
      throw ArgumentError(
        'No test user found for key "$key". '
        'Available keys: ${testUsers.keys.join(', ')}',
      );
    }
    return user;
  }

  /// Returns all available test user keys.
  Iterable<String> get testUserKeys => testUsers.keys;

  /// Logs in the test user associated with [key].
  ///
  /// Override this method to implement your app's login logic:
  /// ```dart
  /// @override
  /// Future<void> loginTestUser(String key) async {
  ///   final user = getTestUser(key);
  ///   await authService.signIn(user.email, user.resolvedPassword);
  /// }
  /// ```
  Future<void> loginTestUser(String key);

  /// Logs out the currently logged in test user.
  ///
  /// Override this method to implement your app's logout logic:
  /// ```dart
  /// @override
  /// Future<void> logoutTestUser() async {
  ///   await authService.signOut();
  /// }
  /// ```
  Future<void> logoutTestUser();
}

/// Class to hold the state of a preview page, including the current
/// build [context], the [state] of the widget (if applicable), and
/// a [completer] indicating that the page has been initialized.
class _PreviewPageState {
  _PreviewPageState() : completer = Completer<_PreviewPageState>();

  // Page context management
  BuildContext? _context;
  BuildContext get context => _context ?? state!.context;
  Future<BuildContext> getContext() => completer.future.then((_) => context);
  void updateContext(BuildContext context) {
    _context = context;
    _completePostFrame();
  }

  // Page state management
  State? state;
  Future<S> getState<S extends State>() =>
      completer.future.then((_) => state as S);
  void updateState(State state) {
    this.state = state;
    _completePostFrame();
  }

  // Completer that is completed after the page first builds.
  Completer<_PreviewPageState> completer;
  void resetCompleter() => completer = Completer<_PreviewPageState>();
  void _completePostFrame() {
    if (completer.isCompleted) {
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => completer.safeComplete(this),
    );
  }

  bool get isActive => _context?.mounted ?? state?.mounted ?? false;
}

extension _SafeCompleter<T> on Completer<T> {
  void safeComplete(T value) => isCompleted ? null : complete(value);
}
