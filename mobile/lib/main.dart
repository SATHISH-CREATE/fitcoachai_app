import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/services/storage_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/notification_service.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/onboarding/presentation/screens/landing_video_screen.dart';
import 'features/setup/presentation/screens/setup_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/dashboard/presentation/screens/steps_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/exercises/presentation/screens/exercises_screen.dart';
import 'features/workout/presentation/screens/workout_screen.dart';
import 'features/workout/presentation/screens/warmup_screen.dart';
import 'features/workout/presentation/screens/workout_summary_screen.dart';
import 'features/library/presentation/screens/library_screen.dart';
import 'features/calculators/presentation/screens/calculators_screen.dart';
import 'features/gyms/presentation/screens/gyms_screen.dart';
import 'features/schedules/presentation/screens/schedules_screen.dart';
import 'shared/widgets/main_layout.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    await StorageService.init();
    await SupabaseService.init();
    await NotificationService.init();
    
    // Global font pre-warming (Triggers lazy loading early)
    // This removes the "stuck" feeling when new font weights are first used
    for (var weight in [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800, FontWeight.w900]) {
      GoogleFonts.outfit(fontWeight: weight);
    }
    
    runApp(const ProviderScope(child: GymAIApp()));
  } catch (e) {
    print("CRASH ERROR: $e");
    // Still run the app but showing the error if possible
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text("Startup Error: $e")))));
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/loading',
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoading = authState.isLoading;
      final isLoggedIn = authState.session != null;
      final isGuest = authState.isGuest;
      final hasProfile = authState.profile != null;
      
      final currentPath = state.uri.path;
      final isLoggingIn = currentPath == '/login';
      final isSettingUp = currentPath == '/setup';
      final isLanding = currentPath == '/landing';
      final isLoadingScreen = currentPath == '/loading';

      // 1. IF loading, stay on /loading (unless currently on login mid-network request)
      if (isLoading) {
        if (isLoggingIn || isSettingUp) return null;
        return '/loading';
      }
      
      // 2. IF Logged In
      if (isLoggedIn) {
        if (!hasProfile) {
          if (!isSettingUp) return '/setup';
        } else {
          // Allow /setup if explicitly navigated to (for editing profile)
          if (isLanding || isLoggingIn || isLoadingScreen) return '/';
        }
      }
      
      // 3. IF Guests
      else if (isGuest) {
        if (isLanding || isLoggingIn || isLoadingScreen) return '/';
      }
      
      // 4. IF Not Logged In and Not Guest
      else if (!isLoggedIn && !isGuest) {
        if (!isLanding && !isLoggingIn) return '/landing';
      }
      return null;
    },
    errorBuilder: (context, state) => Scaffold(body: Center(child: Text('Page not found: ${state.uri.path}'))),
    routes: [
      GoRoute(path: '/loading', builder: (c, s) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(
        path: '/login', 
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      GoRoute(path: '/landing', builder: (c, s) => const LandingVideoScreen()),
      GoRoute(path: '/setup', builder: (c, s) => const SetupScreen()),
      GoRoute(path: '/warmup', builder: (c, s) => WarmUpScreen(exercise: s.uri.queryParameters['exercise'] ?? 'Push-ups')),
      GoRoute(path: '/workout', builder: (c, s) => WorkoutScreen(exercise: s.uri.queryParameters['exercise'] ?? 'Push-ups')),
      GoRoute(path: '/steps', builder: (c, s) => const StepsScreen()),
      GoRoute(
        path: '/workout-summary', 
        builder: (c, s) {
          final data = s.extra as Map<String, dynamic>? ?? {};
          return WorkoutSummaryScreen(
            exercise: data['exercise'] ?? 'Workout',
            reps: int.tryParse(data['reps']?.toString() ?? '0') ?? 0,
            duration: data['duration']?.toString() ?? '0:00',
            accuracy: double.tryParse(data['accuracy']?.toString() ?? '0') ?? 0,
            calories: int.tryParse(data['calories']?.toString() ?? '0') ?? 0,
          );
        }
      ),
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(path: '/', builder: (c, s) => const DashboardScreen()),
          GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
          GoRoute(path: '/exercises', builder: (c, s) => ExercisesScreen(category: s.uri.queryParameters['category'] ?? 'Chest')),
          GoRoute(path: '/schedules', builder: (c, s) => const SchedulesScreen()),
          GoRoute(path: '/history', builder: (c, s) => const WorkoutScreen(exercise: 'Push-Ups')),
          GoRoute(path: '/library', builder: (c, s) => const LibraryScreen()),
          GoRoute(path: '/calculators', builder: (c, s) => const CalculatorsScreen()),
          GoRoute(path: '/gyms', builder: (c, s) => const GymsScreen()),
        ],
      ),
    ],
  );
});

class GymAIApp extends ConsumerStatefulWidget {
  const GymAIApp({super.key});
  @override
  ConsumerState<GymAIApp> createState() => _GymAIAppState();
}

class _GymAIAppState extends ConsumerState<GymAIApp> {
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    
    // We listen to auth changes and trigger a router refresh!
    ref.listen(authProvider, (previous, next) {
      final statusChanged = previous?.isLoading != next.isLoading || 
                            previous?.session != next.session || 
                            previous?.isGuest != next.isGuest ||
                            (previous?.profile == null) != (next.profile == null);
                            
      if (statusChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          router.refresh();
        });
      }
    });

    return MaterialApp.router(
      title: 'FitCoach AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.iOSTheme,
      routerConfig: router,
    );
  }
}

