import 'package:get/get.dart';
import 'package:x_cricket/features/match/screens/match_detail_screen.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/match/screens/create_match_screen.dart';
import '../../features/history/screens/match_history_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/explore/screens/players_screen.dart';
import '../../features/scoring/screens/scoring_screen.dart';
import '../../features/team/screens/team_management_screen.dart';
import '../../features/tournament/screens/tournament_list_screen.dart';
import '../../features/tournament/screens/create_tournament_screen.dart';
import '../../features/tournament/screens/tournament_detail_screen.dart';
import '../../features/explore/screens/hot_record_screen.dart';

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
  static const String tournaments = '/tournaments';
  static const String createTournament = '/create-tournament';
  static const String tournamentDetail = '/tournament-detail';
  static const String hotRecord = '/hot-record';

  static List<GetPage> get pages => [
    GetPage(
      name: login,
      page: () => const LoginScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: home,
      page: () => const HomeScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: createMatch,
      page: () => const CreateMatchScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: scoring,
      page: () => ScoringScreen(matchId: Get.arguments as String),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: matchHistory,
      page: () => const MatchHistoryScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: profile,
      page: () => const ProfileScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: admin,
      page: () => AdminDashboardScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: players,
      page: () => const PlayersScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: teams,
      page: () => const TeamManagementScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: tournaments,
      page: () => const TournamentListScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: createTournament,
      page: () => const CreateTournamentScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: tournamentDetail,
      page: () => const TournamentDetailScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: hotRecord,
      page: () => const HotRecordScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: matchDetail,
      page: () => MatchDetailScreen(matchId: Get.arguments as String),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),
    ),
  ];
}
