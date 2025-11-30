# Preview Config

A Flutter package for creating isolated preview environments with configurable application state for page-level component testing.

## Overview

Preview Config provides a structured way to create isolated preview environments for pages in a Flutter app. It allows you to display pages in different application states (logged in/out, admin user, populated cart, etc.) by defining reusable configuration classes.

## Core Concepts

### PreviewConfig

A `PreviewConfig<T, S>` represents the configuration for previewing a specific page widget `T` with parameters `S`. It defines:
- How to navigate to the page
- How to set up the required application state

```dart
class UserProfilePreviewConfig 
    extends PreviewConfig<UserProfilePage, UserProfileConfigParams> {
  @override
  Future<void> execute(UserProfileConfigParams params) async {
    final previewManager = AppPreviewManager.instance;
    
    // Set up application state
    if (params.isLoggedIn) {
      await previewManager.loginTestUser(params.userKey);
    }
    
    if (params.cartItemCount > 0) {
      previewManager.setCartItemCount(params.cartItemCount);
    }
    
    // Navigate to the page
    Navigator.of(navigatorContext).push(
      MaterialPageRoute(builder: (_) => const UserProfilePage()),
    );
  }

  // ============================================================
  // Preview Config Params
  // ============================================================

  UserProfileConfigParams get loggedInAdminParams => UserProfileConfigParams(
    isLoggedIn: true,
    userKey: 'admin',
  );

  UserProfileConfigParams get guestWithCartParams => UserProfileConfigParams(
    isLoggedIn: false,
    userKey: '',
    cartItemCount: 3,
  );

  UserProfileConfigParams get premiumUserParams => UserProfileConfigParams(
    isLoggedIn: true,
    userKey: 'premium',
    cartItemCount: 0,
  );
}
```

### Accessing Page State

For pages embedded within other pages (e.g., a tab inside a tab bar), you can access and manipulate the parent page's state:

```dart
class ProfileScreenPreviewConfig 
    extends PreviewConfig<ProfileScreen, ProfileScreenConfigParams> {
  @override
  Future<void> execute(ProfileScreenConfigParams params) async {
    final previewManager = AppPreviewManager.instance;
    
    if (params.isLoggedIn) {
      await previewManager.loginTestUser(params.userKey);
    }
    
    // Navigate to parent page containing the tabs
    Navigator.of(navigatorContext).pushNamedAndRemoveUntil('/home', (route) => false);
    
    // Wait for HomeScreen to build, then access its state
    final homeState = await previewManager.getPageState<HomeScreen, HomeScreenState>();
    
    // Directly call setState on the state object
    // ignore: invalid_use_of_protected_member
    homeState.setState(() {
      homeState.selectedIndex = 3; // Switch to Profile tab
    });
  }
  
  // ...params...
}
```

**Note**: The widget's State class must be public (e.g., `HomeScreenState` not `_HomeScreenState`), and any fields you modify must also be public. The codegen system handles making State classes public and registering them.

### PreviewConfigParams

A `PreviewConfigParams` contains the parameters for a specific preview state. Each `PreviewConfig` has a corresponding params class:

```dart
class UserProfileConfigParams extends PreviewConfigParams {
  const UserProfileConfigParams({
    required this.isLoggedIn,
    required this.userKey,
    this.cartItemCount = 0,
  });

  /// Whether a user should be logged in for this preview.
  final bool isLoggedIn;

  /// The key identifying which test user to use.
  final String userKey;

  /// Number of items to populate in the cart.
  final int cartItemCount;
}
```

Parameters are exposed as getter methods on the `PreviewConfig` class, making it easy to define named configurations for different states.

### PreviewManager

The `PreviewManager` is an abstract class that you extend as a **singleton** to provide helper methods for manipulating your app's existing state. **Important**: This class should NOT store any state itself - it only provides helper methods that call your app's services/providers.

```dart
class AppPreviewManager extends PreviewManager {
  AppPreviewManager._();

  // Singleton instance - initialized once in preview entrypoint
  static final instance = AppPreviewManager._();

  @override
  Map<String, PreviewTestUser> get testUsers => {
    'admin': PreviewTestUser(
      email: 'admin@example.com',
      password: 'admin123',
    ),
    'premium': PreviewTestUser(
      email: 'premium@example.com',
      password: 'premium123',
    ),
    'guest': PreviewTestUser(
      email: 'guest@example.com',
      password: 'guest123',
    ),
  };

  @override
  Future<void> loginTestUser(String key) async {
    final user = getTestUser(key);
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: user.email,
      password: user.password,
    );
  }

  @override
  Future<void> logoutTestUser() async {
    await FirebaseAuth.instance.signOut();
  }

  // ============================================================
  // Helper Methods (call your app's services/providers)
  // ============================================================

  /// Calls the cart service to set item count.
  void setCartItemCount(int count) {
    final cartService = Provider.of<CartService>(navigatorContext, listen: false);
    cartService.setItemCount(count);
  }

  /// Calls the subscription service to set tier.
  void setSubscriptionTier(String tier) {
    final subscriptionService = Provider.of<SubscriptionService>(navigatorContext, listen: false);
    subscriptionService.setTier(tier);
  }
}
```

### PreviewTestUser

A `PreviewTestUser` stores credentials for test accounts:

```dart
final testUser = PreviewTestUser(
  email: 'guest@example.com',
  password: 'guest123',
);

// Access the credentials
print(testUser.email);    // guest@example.com
print(testUser.password); // guest123
```

**Note**: Test user passwords are stored directly in code. For production apps, consider loading sensitive credentials from environment variables or secure storage in your `PreviewManager.loginTestUser()` implementation.

## Setup

### 1. Add the dependency

```yaml
dependencies:
  preview_config: ^0.0.1
```

### 2. Create your preview manager

Create a file at `lib/previews/preview_manager.dart`:

```dart
import 'package:preview_config/preview_config.dart';

class AppPreviewManager extends PreviewManager {
  AppPreviewManager._();

  // Singleton instance - initialized once in preview entrypoint
  static final instance = AppPreviewManager._();

  @override
  Map<String, PreviewTestUser> get testUsers => {
    'admin': PreviewTestUser(
      email: 'admin@example.com',
      password: 'admin123',
    ),
    'guest': PreviewTestUser(
      email: 'guest@example.com',
      password: 'guest123',
    ),
  };

  @override
  Future<void> loginTestUser(String key) async {
    final user = getTestUser(key);
    // Implement your login logic, e.g.:
    // await FirebaseAuth.instance.signInWithEmailAndPassword(
    //   email: user.email,
    //   password: user.password,
    // );
  }

  @override
  Future<void> logoutTestUser() async {
    // Implement your logout logic, e.g.:
    // await FirebaseAuth.instance.signOut();
  }

  // Add custom helper methods that call your app's services...
}
```

### 3. Create preview configs for your pages

For each page you want to preview, create a config class:

```dart
import 'package:flutter/material.dart';
import 'package:preview_config/preview_config.dart';
import 'package:my_app/previews/preview_manager.dart';
import 'package:my_app/pages/settings_page.dart';

class SettingsPagePreviewConfig 
    extends PreviewConfig<SettingsPage, SettingsPageConfigParams> {
  @override
  Future<void> execute(SettingsPageConfigParams params) async {
    final previewManager = AppPreviewManager.instance;
    
    if (params.isLoggedIn) {
      await previewManager.loginTestUser(params.userKey);
    }
    
    // Navigate to settings page
    Navigator.of(navigatorContext).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  // ============================================================
  // Preview Config Params
  // ============================================================

  SettingsPageConfigParams get defaultParams => SettingsPageConfigParams(
    isLoggedIn: true,
    userKey: 'guest',
  );

  SettingsPageConfigParams get adminParams => SettingsPageConfigParams(
    isLoggedIn: true,
    userKey: 'admin',
  );
}

class SettingsPageConfigParams extends PreviewConfigParams {
  const SettingsPageConfigParams({
    required this.isLoggedIn,
    required this.userKey,
  });

  final bool isLoggedIn;
  final String userKey;
}
```

## Usage

```dart
// Get the preview config
final config = SettingsPagePreviewConfig();

// Execute a specific preview configuration
await config.execute(config.adminParams);
```

## Minimal Widget Changes

When setting up preview configs, you may need to make small changes to widgets to expose their state:

**DO**:
- Make private State classes public: `_HomeScreenState` → `HomeScreenState`
- Make private fields public: `int _selectedIndex` → `int selectedIndex`

**DON'T**:
- Add new methods like `setSelectedIndex(int index)`
- Add setters that wrap setState
- Refactor the widget structure
- Add new dependencies or providers

The goal is the absolute minimum change needed to expose the state for preview manipulation.

## Best Practices

1. **Handle sensitive passwords carefully** - While test user passwords are stored directly in code, consider loading real credentials from environment variables or secure storage in your `loginTestUser()` implementation.

2. **Keep params classes simple** - They should only contain data, not logic.

3. **Group related params together** - Use the commented section in the `PreviewConfig` class to organize param getters.

4. **Name params descriptively** - Use names like `loggedInAdminParams` rather than just `adminParams`.

5. **PreviewManager should be a singleton** - Initialize once in the preview entrypoint.

6. **PreviewManager should NOT store state** - Only provide helper methods that call your app's existing services/providers.

7. **Strongly prefer fast state changes** - The `execute()` method should be quick by calling your app's services directly.

8. **If network calls are necessary, make them idempotent** - Either don't persist changes, or query current state first and only make changes to match intended state.

9. **Make only minimal widget changes** - Just publicize existing fields, don't add new code.

## File Organization

Recommended structure:
```
lib/
├── previews/
│   ├── preview_manager.dart          # Your AppPreviewManager subclass
│   └── configs/
│       ├── user_profile_config.dart  # PreviewConfig + PreviewConfigParams
│       ├── settings_config.dart
│       └── cart_config.dart
```

## API Reference

### PreviewConfig<T, S>

| Member | Description |
|--------|-------------|
| `PreviewConfig()` | Constructor |
| `execute(S params)` | Executes the preview with given params |
| `navigatorContext` | Static getter for the app navigator's BuildContext |

### PreviewConfigParams

| Member | Description |
|--------|-------------|
| `PreviewConfigParams()` | Const constructor |

### PreviewManager

| Member | Description |
|--------|-------------|
| `setNavigatorKey(GlobalKey<NavigatorState>)` | Static method to set the app's navigator key (called during initialization) |
| `navigatorContext` | Static getter for the app navigator's BuildContext |
| `getPageContext<T>()` | Gets the BuildContext for a specific page widget type |
| `getPageState<T, S>()` | Gets the State<T> for a StatefulWidget (T=Widget, S=State) |
| `registerContext<T>(BuildContext)` | Static method to register the context for a specific page type |
| `registerState<T>(State)` | Static method to register the state for a StatefulWidget |
| `testUsers` | Map of test user credentials (override this getter) |
| `getTestUser(String key)` | Returns the test user for the given key |
| `testUserKeys` | Returns all available test user keys |
| `loginTestUser(String key)` | Logs in the specified test user (override to implement) |
| `logoutTestUser()` | Logs out the current test user (override to implement) |

### PreviewTestUser

| Member | Description |
|--------|-------------|
| `PreviewTestUser({required email, required password})` | Constructor |
| `email` | The test user's email |
| `password` | The test user's password |
