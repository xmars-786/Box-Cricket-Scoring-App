import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../models/team_model.dart';
import '../utils/ui_utils.dart';

class TeamController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  final RxList<TeamModel> teams = <TeamModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    listenToTeams();
  }

  void listenToTeams() {
    _firestore.collection('teams').snapshots().listen((snapshot) {
      teams.value = snapshot.docs.map((doc) => TeamModel.fromFirestore(doc)).toList();
    });
  }

  Future<bool> createTeam(String name, List<String> playerIds, String createdBy) async {
    try {
      isLoading.value = true;
      final teamId = _uuid.v4();
      final team = TeamModel(
        id: teamId,
        name: name,
        playerIds: playerIds,
        createdBy: createdBy,
      );
      
      await _firestore.collection('teams').doc(teamId).set(team.toFirestore());
      isLoading.value = false;
      return true;
    } catch (e) {
      isLoading.value = false;
      UIUtils.showError('Failed to create team: $e');
      return false;
    }
  }

  Future<bool> updateTeam(String teamId, String name, List<String> playerIds) async {
    try {
      isLoading.value = true;
      await _firestore.collection('teams').doc(teamId).update({
        'name': name,
        'player_ids': playerIds,
      });
      isLoading.value = false;
      return true;
    } catch (e) {
      isLoading.value = false;
      UIUtils.showError('Failed to update team: $e');
      return false;
    }
  }

  Future<void> deleteTeam(String teamId) async {
    try {
      await _firestore.collection('teams').doc(teamId).delete();
      // UIUtils.showSuccess('Team deleted successfully');
    } catch (e) {
      UIUtils.showError('Failed to delete team: $e');
    }
  }
}
