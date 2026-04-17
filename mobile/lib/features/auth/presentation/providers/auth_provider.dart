import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart' hide GoogleSignIn;
import 'package:google_sign_in/google_sign_in.dart' as google;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/notification_service.dart';

class AuthState {
  final User? user;
  final Session? session;
  final Map<String, dynamic>? profile;
  final bool isLoading;
  final String? error;
  final bool isGuest;

  AuthState({
    this.user,
    this.session,
    this.profile,
    this.isLoading = false,
    this.error,
    this.isGuest = false,
  });

  AuthState copyWith({
    User? user,
    Session? session,
    Map<String, dynamic>? profile,
    bool? isLoading,
    String? error,
    bool? isGuest,
  }) {
    return AuthState(
      user: user ?? this.user,
      session: session ?? this.session,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseClient _client = Supabase.instance.client;
  final google.GoogleSignIn _googleSignIn = google.GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/userinfo.profile'],
    serverClientId:
        '338951819687-4s43r1u97ecuco9g0b486nb9klff8ukq.apps.googleusercontent.com',
  );

  AuthNotifier() : super(AuthState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    final session = _client.auth.currentSession;
    if (session != null) {
      await fetchProfile(session.user.id);
      state = state.copyWith(
        user: session.user,
        session: session,
        isLoading: false,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }

    _client.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        await fetchProfile(session.user.id);
        state = state.copyWith(
          user: session.user,
          session: session,
          isLoading: false,
        );
      } else if (event == AuthChangeEvent.signedOut) {
        state = AuthState();
      }
    });
  }

  Future<void> fetchProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      if (response != null) {
        state = state.copyWith(profile: response);
        
        // Populate local storage with synced data
        await StorageService.saveProfile(response);
        
        if (response['macro_plan'] != null) {
          await StorageService.saveMacroPlan(Map<String, dynamic>.from(response['macro_plan']));
        }
        if (response['meal_plan'] != null) {
          await StorageService.saveMealPlanResponse(response['meal_plan']);
        }
        if (response['workout_schedule'] != null) {
          await StorageService.save6DayPlan(List<dynamic>.from(response['workout_schedule']));
        }
      }
    } catch (e) {
      print("Profile fetch error: $e");
    }
  }

  // New method to sync all local data to Supabase
  Future<void> syncUserData() async {
    final user = _client.auth.currentUser;
    if (user == null || state.isGuest) return;

    try {
      final profile = StorageService.getProfile();
      final macroPlan = StorageService.getMacroPlan();
      final mealPlan = StorageService.getMealPlanResponse();
      final workoutSchedule = StorageService.get6DayPlan();

      final data = {
        'id': user.id,
        ...profile,
        'macro_plan': macroPlan,
        'meal_plan': mealPlan,
        'workout_schedule': workoutSchedule,
      };
      
      // We upsert ONLY what the DB supports (id, name, age, gender, etc. from profile)
      // but we keep the full data in the app state
      final dbData = {
         'id': user.id,
         ...profile,
      };

      await _client.from('profiles').upsert(dbData);
      state = state.copyWith(profile: data);
      await StorageService.saveProfile(data);
    } catch (e) {
      print("Sync error: $e");
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session != null) {
        await fetchProfile(response.session!.user.id);
        state = state.copyWith(
          user: response.user,
          session: response.session,
          isLoading: false,
        );
        NotificationService.requestAndSchedule();
      } else {
        state = state.copyWith(isLoading: false);
      }
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "An unexpected error occurred.",
      );
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      if (response.session != null) {
        await fetchProfile(response.session!.user.id);
        state = state.copyWith(
          user: response.user,
          session: response.session,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: "Signup successful! Please confirm your email address.",
        );
      }
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "An unexpected error occurred.",
      );
    }
  }

  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'gymai://callback',
      );
      state = state.copyWith(
        isLoading: false,
        error: "If an account with that email exists, a reset link has been sent.", // using error toast for success msg
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to send reset link: ${e.toString()}",
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 1. Trigger Native Google Sign-In
      print("AuthNotifier: Starting Google Sign-In...");
      final google.GoogleSignInAccount? googleUser = await _googleSignIn
          .signIn();
      if (googleUser == null) {
        print("AuthNotifier: Google Sign-In cancelled by user.");
        state = state.copyWith(isLoading: false);
        return;
      }

      print(
        "AuthNotifier: Google user found: ${googleUser.email}. Retrieving authentication...",
      );

      // 2. Get tokens
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      print(
        "AuthNotifier: Tokens retrieved. idToken is null: ${idToken == null}, accessToken is null: ${accessToken == null}",
      );

      if (idToken == null) {
        print(
          "AuthNotifier: Error - idToken is null. This usually means the SHA-1 is not registered in the Google Cloud Console OR the Client ID is wrong.",
        );
        state = state.copyWith(
          isLoading: false,
          error: "could not retrieve google token id",
        );
        return;
      }

      print("AuthNotifier: Signing in to Supabase with idToken...");
      // 3. Sign in to Supabase with ID Token
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      print("AuthNotifier: Supabase sign-in call completed.");

      if (response.session != null) {
        await fetchProfile(response.session!.user.id);
        state = state.copyWith(
          user: response.user,
          session: response.session,
          isLoading: false,
        );
        NotificationService.requestAndSchedule();
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      print("Native Google Sign-In Error: $e");
      state = state.copyWith(
        isLoading: false,
        error: "Google Sign-In Error: ${e.toString()}",
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      await _googleSignIn.signOut();
      await StorageService.clear();
      state = AuthState();
    } catch (e) {
      print("Sign Out Error: $e");
      state = state.copyWith(error: "Sign out failed: $e");
    }
  }

  Future<void> saveProfile(Map<String, dynamic> profileData) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      // Get current local state for plans
      final macroPlan = StorageService.getMacroPlan();
      final mealPlan = StorageService.getMealPlanResponse();
      final workoutSchedule = StorageService.get6DayPlan();

      final data = {
        'id': user.id,
        ...profileData,
        'macro_plan': macroPlan,
        'meal_plan': mealPlan,
        'workout_schedule': workoutSchedule,
      };
      
      final dbData = {
         'id': user.id,
         'avatar_url': profileData['avatar_url'], // Explicitly map to ensure it's there
         ...profileData,
      };

      await _client.from('profiles').upsert(dbData);
      state = state.copyWith(profile: data);
      await StorageService.saveProfile(data);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void continueAsGuest() {
    state = state.copyWith(isGuest: true, user: null, session: null, profile: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
