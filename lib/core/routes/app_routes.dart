import 'package:get/get.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/match/screens/create_match_screen.dart';
import '../../features/history/screens/match_history_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/explore/screens/players_screen.dart';
import '../../features/scoring/screens/scoring_screen.dart';
import '../../features/team/screens/team_management_screen.dart';

/// Centralized route definitions for the application using GetX.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String home = '/home';
  static const String createMatch = '/create-match';
  static const String matchDetail = '/match-detail';
  static const String scoring = '/scoring';
  static const String scorecard = '/scorecard';
  static const String matchHistory = '/match-history';
  static const String profile = '/profile';
  static const String admin = '/admin';
  static const String players = '/players';
  static const String teams = '/teams';

  static List<GetPage> get pages => [
        GetPage(name: login, page: () => const LoginScreen()),
        GetPage(name: home, page: () => const HomeScreen()),
        GetPage(name: createMatch, page: () => const CreateMatchScreen()),
        GetPage(
          name: scoring,
          page: () => ScoringScreen(matchId: Get.arguments as String),
    ),
    GetPage(name: matchHistory, page: () => const MatchHistoryScreen()),
    GetPage(name: profile, page: () => const ProfileScreen()),
    GetPage(name: admin, page: () => AdminDashboardScreen()),
    GetPage(name: players, page: () => const PlayersScreen()),
    GetPage(name: teams, page: () => const TeamManagementScreen()),
  ];
}
