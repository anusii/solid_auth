import 'package:flutter_test/flutter_test.dart';
import 'package:oidc/oidc.dart';
import 'package:solid_auth/src/oidc/solid_oidc_user_manager.dart';

void main() {
  group('SolidOidcUserManager', () {
    late SolidOidcUserManager userManager;
    late SolidOidcUserManagerSettings settings;

    setUp(() {
      settings = SolidOidcUserManagerSettings(
        redirectUri: Uri.parse('https://example.com/callback'),
      );

      userManager = SolidOidcUserManager(
        clientId: 'https://example.com/client-profile.jsonld',
        webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
        store: OidcMemoryStore(),
        settings: settings,
      );
    });

    group('getEffectivePrompts', () {
      test(
          'should automatically add consent prompt when offline_access is in default scopes',
          () {
        // Given: Default settings (which include offline_access by default)
        final scopes = userManager.getEffectiveScopes();
        final prompts = userManager.getEffectivePrompts(scopes);

        // Then: consent should be automatically added
        expect(prompts, contains('consent'));
      });

      test('should preserve custom prompts and add consent', () {
        // Given: Custom prompts configured
        final customSettings = SolidOidcUserManagerSettings(
          redirectUri: Uri.parse('https://example.com/callback'),
          prompt: ['login', 'select_account'],
        );

        final customUserManager = SolidOidcUserManager(
          clientId: 'https://example.com/client-profile.jsonld',
          webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
          store: OidcMemoryStore(),
          settings: customSettings,
        );

        // When: Getting effective prompts
        final scopes = customUserManager.getEffectiveScopes();
        final prompts = customUserManager.getEffectivePrompts(scopes);

        // Then: Should contain both custom prompts and consent
        expect(prompts, containsAll(['login', 'select_account', 'consent']));
      });

      test('should not duplicate consent prompt if already specified', () {
        // Given: Consent already in custom prompts
        final customSettings = SolidOidcUserManagerSettings(
          redirectUri: Uri.parse('https://example.com/callback'),
          prompt: ['consent', 'login'],
        );

        final customUserManager = SolidOidcUserManager(
          clientId: 'https://example.com/client-profile.jsonld',
          webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
          store: OidcMemoryStore(),
          settings: customSettings,
        );

        // When: Getting effective prompts
        final scopes = customUserManager.getEffectiveScopes();
        final prompts = customUserManager.getEffectivePrompts(scopes);

        // Then: Should contain consent only once
        expect(prompts.where((p) => p == 'consent').length, equals(1));
        expect(prompts, containsAll(['consent', 'login']));
      });

      test(
          'should not add consent prompt if offline_access is not in effective scopes',
          () {
        // Given: Settings without offline_access scope in default scopes
        final customSettings = SolidOidcUserManagerSettings(
          redirectUri: Uri.parse('https://example.com/callback'),
          defaultScopes: ['openid', 'webid'], // No offline_access
          prompt: ['login'],
        );

        final customUserManager = SolidOidcUserManager(
          clientId: 'https://example.com/client-profile.jsonld',
          webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
          store: OidcMemoryStore(),
          settings: customSettings,
        );

        // When: Getting effective prompts
        final scopes = customUserManager.getEffectiveScopes();
        final prompts = customUserManager.getEffectivePrompts(scopes);

        // Then: Should not contain consent since offline_access is not in scopes
        expect(scopes, isNot(contains('offline_access')));
        expect(prompts, isNot(contains('consent')));
        expect(prompts, contains('login'));
      });

      test('should return sorted and deduplicated prompts', () {
        // Given: Settings with duplicate and unsorted prompts
        final customSettings = SolidOidcUserManagerSettings(
          redirectUri: Uri.parse('https://example.com/callback'),
          prompt: [
            'select_account',
            'login',
            'select_account'
          ], // Duplicates and unsorted
        );

        final customUserManager = SolidOidcUserManager(
          clientId: 'https://example.com/client-profile.jsonld',
          webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
          store: OidcMemoryStore(),
          settings: customSettings,
        );

        // When: Getting effective prompts
        final scopes = customUserManager.getEffectiveScopes();
        final prompts = customUserManager.getEffectivePrompts(scopes);

        // Then: Should be sorted and deduplicated
        final expected = [
          'consent',
          'login',
          'select_account'
        ]; // Sorted alphabetically
        expect(prompts, equals(expected));
      });
    });

    group('getEffectiveScopes', () {
      test('should include default scopes', () {
        // When: Getting effective scopes
        final scopes = userManager.getEffectiveScopes();

        // Then: Should include all default scopes
        expect(scopes, containsAll(['openid', 'webid', 'offline_access']));
      });

      test('should use custom default scopes when specified', () {
        // Given: Settings with custom default scopes
        final customSettings = SolidOidcUserManagerSettings(
          redirectUri: Uri.parse('https://example.com/callback'),
          defaultScopes: ['openid', 'webid'], // No offline_access
        );

        final customUserManager = SolidOidcUserManager(
          clientId: 'https://example.com/client-profile.jsonld',
          webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
          store: OidcMemoryStore(),
          settings: customSettings,
        );

        // When: Getting effective scopes
        final scopes = customUserManager.getEffectiveScopes();

        // Then: Should include only custom default scopes
        expect(scopes, equals(['openid', 'webid']));
        expect(scopes, isNot(contains('offline_access')));
      });

      test('should combine default and extra scopes', () {
        // Given: Settings with extra scopes
        final customSettings = SolidOidcUserManagerSettings(
          redirectUri: Uri.parse('https://example.com/callback'),
          extraScopes: ['profile', 'email'],
        );

        final customUserManager = SolidOidcUserManager(
          clientId: 'https://example.com/client-profile.jsonld',
          webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
          store: OidcMemoryStore(),
          settings: customSettings,
        );

        // When: Getting effective scopes
        final scopes = customUserManager.getEffectiveScopes();

        // Then: Should include both default and extra scopes
        expect(
            scopes,
            containsAll(
                ['openid', 'webid', 'offline_access', 'profile', 'email']));
      });

      test('should combine custom default scopes with extra scopes', () {
        // Given: Settings with both custom default scopes and extra scopes
        final customSettings = SolidOidcUserManagerSettings(
          redirectUri: Uri.parse('https://example.com/callback'),
          defaultScopes: [
            'openid',
            'webid'
          ], // Custom defaults without offline_access
          extraScopes: ['profile', 'email'], // Extra scopes
        );

        final customUserManager = SolidOidcUserManager(
          clientId: 'https://example.com/client-profile.jsonld',
          webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
          store: OidcMemoryStore(),
          settings: customSettings,
        );

        // When: Getting effective scopes
        final scopes = customUserManager.getEffectiveScopes();

        // Then: Should include both custom defaults and extra scopes
        expect(scopes, containsAll(['openid', 'webid', 'profile', 'email']));
        expect(scopes, isNot(contains('offline_access')));
        expect(scopes.length, equals(4));
      });

      test('should return sorted and deduplicated scopes', () {
        // Given: Settings with duplicate scopes
        final customSettings = SolidOidcUserManagerSettings(
          redirectUri: Uri.parse('https://example.com/callback'),
          extraScopes: ['openid', 'profile'], // openid is already in defaults
        );

        final customUserManager = SolidOidcUserManager(
          clientId: 'https://example.com/client-profile.jsonld',
          webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
          store: OidcMemoryStore(),
          settings: customSettings,
        );

        // When: Getting effective scopes
        final scopes = customUserManager.getEffectiveScopes();

        // Then: Should be sorted and deduplicated
        expect(scopes.where((s) => s == 'openid').length, equals(1));
        expect(scopes, equals(scopes.toList()..sort())); // Should be sorted
      });
    });

    group('calculateEffectivePrompts configuration', () {
      test('should use custom prompt calculation function when provided', () {
        // Given: Custom prompt calculation function
        List<String> customPromptCalculation(
            List<String> configuredPrompts, List<String> effectiveScopes) {
          final prompts = <String>[...configuredPrompts];

          // Custom logic: add 'login' for any scopes containing 'profile'
          if (effectiveScopes.any((scope) => scope.contains('profile'))) {
            prompts.add('login');
          }

          // Custom logic: add 'select_account' for offline_access
          if (effectiveScopes.contains('offline_access')) {
            prompts.add('select_account');
          }

          return prompts.toSet().toList()..sort();
        }

        final customSettings = SolidOidcUserManagerSettings(
          redirectUri: Uri.parse('https://example.com/callback'),
          extraScopes: ['profile', 'offline_access'],
          prompt: ['consent'],
          calculateEffectivePrompts: customPromptCalculation,
        );

        final customUserManager = SolidOidcUserManager(
          clientId: 'https://example.com/client-profile.jsonld',
          webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
          store: OidcMemoryStore(),
          settings: customSettings,
        );

        // When: Getting effective prompts
        final effectiveScopes = customUserManager.getEffectiveScopes();
        final prompts = customUserManager.getEffectivePrompts(effectiveScopes);

        // Then: Should use custom calculation (no default consent, but custom login and select_account)
        expect(prompts, containsAll(['consent', 'login', 'select_account']));
        expect(prompts.length, equals(3));
        expect(prompts, equals(prompts.toList()..sort())); // Should be sorted
      });

      test(
          'should pass correct parameters to custom prompt calculation function',
          () {
        // Given: Mock function to capture parameters
        List<String>? capturedConfiguredPrompts;
        List<String>? capturedEffectiveScopes;

        List<String> mockPromptCalculation(
            List<String> configuredPrompts, List<String> effectiveScopes) {
          capturedConfiguredPrompts = configuredPrompts;
          capturedEffectiveScopes = effectiveScopes;
          return ['mock_prompt'];
        }

        final customSettings = SolidOidcUserManagerSettings(
          redirectUri: Uri.parse('https://example.com/callback'),
          extraScopes: ['profile', 'email'],
          prompt: ['consent', 'login'],
          calculateEffectivePrompts: mockPromptCalculation,
        );

        final customUserManager = SolidOidcUserManager(
          clientId: 'https://example.com/client-profile.jsonld',
          webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
          store: OidcMemoryStore(),
          settings: customSettings,
        );

        // When: Getting effective prompts
        final effectiveScopes = customUserManager.getEffectiveScopes();
        final prompts = customUserManager.getEffectivePrompts(effectiveScopes);

        // Then: Should pass correct parameters
        expect(capturedConfiguredPrompts, equals(['consent', 'login']));
        expect(capturedEffectiveScopes, isNotNull);
        expect(
            capturedEffectiveScopes,
            containsAll(
                ['openid', 'webid', 'offline_access', 'profile', 'email']));
        expect(prompts, equals(['mock_prompt']));
      });

      test(
          'should fall back to default behavior when no custom function provided',
          () {
        // Given: Settings without custom prompt calculation
        final defaultSettings = SolidOidcUserManagerSettings(
          redirectUri: Uri.parse('https://example.com/callback'),
          extraScopes: ['offline_access'],
          prompt: ['login'],
        );

        final defaultUserManager = SolidOidcUserManager(
          clientId: 'https://example.com/client-profile.jsonld',
          webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
          store: OidcMemoryStore(),
          settings: defaultSettings,
        );

        // When: Getting effective prompts
        final effectiveScopes = defaultUserManager.getEffectiveScopes();
        final prompts = defaultUserManager.getEffectivePrompts(effectiveScopes);

        // Then: Should use default behavior (automatic consent for offline_access)
        expect(prompts, containsAll(['login', 'consent']));
        expect(prompts.length, equals(2));
      });

      test('should handle custom function returning empty list', () {
        // Given: Custom function that returns empty list
        List<String> emptyPromptCalculation(
            List<String> configuredPrompts, List<String> effectiveScopes) {
          return [];
        }

        final customSettings = SolidOidcUserManagerSettings(
          redirectUri: Uri.parse('https://example.com/callback'),
          extraScopes: ['offline_access'],
          prompt: ['consent', 'login'],
          calculateEffectivePrompts: emptyPromptCalculation,
        );

        final customUserManager = SolidOidcUserManager(
          clientId: 'https://example.com/client-profile.jsonld',
          webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
          store: OidcMemoryStore(),
          settings: customSettings,
        );

        // When: Getting effective prompts
        final effectiveScopes = customUserManager.getEffectiveScopes();
        final prompts = customUserManager.getEffectivePrompts(effectiveScopes);

        // Then: Should return empty list as specified by custom function
        expect(prompts, isEmpty);
      });

      test('should handle custom function with complex logic', () {
        // Given: Custom function with conditional logic
        List<String> complexPromptCalculation(
            List<String> configuredPrompts, List<String> effectiveScopes) {
          final prompts = <String>[];

          // Always include configured prompts
          prompts.addAll(configuredPrompts);

          // Conditional logic based on scope combinations
          if (effectiveScopes.contains('offline_access') &&
              effectiveScopes.contains('profile')) {
            prompts.addAll(['consent', 'select_account']);
          } else if (effectiveScopes.contains('offline_access')) {
            prompts.add('consent');
          }

          // Add login prompt for webid scope
          if (effectiveScopes.contains('webid')) {
            prompts.add('login');
          }

          return prompts.toSet().toList()..sort();
        }

        final customSettings = SolidOidcUserManagerSettings(
          redirectUri: Uri.parse('https://example.com/callback'),
          extraScopes: ['profile', 'offline_access'],
          prompt: ['none'],
          calculateEffectivePrompts: complexPromptCalculation,
        );

        final customUserManager = SolidOidcUserManager(
          clientId: 'https://example.com/client-profile.jsonld',
          webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
          store: OidcMemoryStore(),
          settings: customSettings,
        );

        // When: Getting effective prompts
        final effectiveScopes = customUserManager.getEffectiveScopes();
        final prompts = customUserManager.getEffectivePrompts(effectiveScopes);

        // Then: Should follow custom logic
        expect(prompts,
            containsAll(['none', 'consent', 'select_account', 'login']));
        expect(prompts.length, equals(4));
        expect(prompts, equals(prompts.toList()..sort())); // Should be sorted
      });
    });
  });
}
