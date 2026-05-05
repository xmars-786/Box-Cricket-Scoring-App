import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../models/tournament_model.dart';
import '../models/match_model.dart';
import '../models/tournament_player_stats.dart';

class PdfTeamStanding {
  final String id;
  final String name;
  int matches = 0;
  int wins = 0;
  int losses = 0;
  int points = 0;
  int runsScored = 0;
  int ballsFaced = 0;
  int runsConceded = 0;
  int ballsBowled = 0;

  PdfTeamStanding(this.id, this.name);

  double get nrr {
    if (ballsFaced == 0 || ballsBowled == 0) return 0.0;
    double runRateScored = (runsScored * 6) / ballsFaced;
    double runRateConceded = (runsConceded * 6) / ballsBowled;
    return runRateScored - runRateConceded;
  }
}

class TournamentPdfService {
  static Future<void> generateAndShareTournamentReport({
    required TournamentModel tournament,
    required List<MatchModel> matches,
    required List<TournamentPlayerStats> leaderboard,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.outfitRegular();
    final fontBold = await PdfGoogleFonts.outfitBold();
    final emojiFont = await PdfGoogleFonts.notoColorEmoji();

    final dateFormat = DateFormat('dd MMM yyyy');

    // Filter matches to only include those where both teams are currently in the tournament
    final filteredMatches =
        matches.where((m) {
          final teamAIn =
              tournament.teamIds.contains(m.teamAId) ||
              tournament.teamNames.contains(m.teamAName);
          final teamBIn =
              tournament.teamIds.contains(m.teamBId) ||
              tournament.teamNames.contains(m.teamBName);
          return teamAIn && teamBIn;
        }).toList();

    // Filter leaderboard to only include players from teams currently in the tournament
    final filteredLeaderboard =
        leaderboard.where((s) {
          return tournament.teamNames.contains(s.teamName);
        }).toList();

    final standings = _calculatePdfStandings(tournament, filteredMatches);
    final winner = standings.isNotEmpty ? standings.first : null;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
          fontFallback: [emojiFont],
        ),
        build:
            (context) => [
              _buildHeader(tournament, dateFormat),
              pw.SizedBox(height: 30),
              _buildOverview(tournament, filteredMatches, winner),
              pw.SizedBox(height: 30),
              _buildPointsTable(standings),
              pw.SizedBox(height: 30),
              _buildLeaderboard(filteredLeaderboard),
              pw.SizedBox(height: 30),
              _buildMatchList(filteredMatches, dateFormat, filteredLeaderboard),
            ],
        footer:
            (context) => pw.Column(
              children: [
                pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Page ${context.pageNumber} of ${context.pagesCount}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'Powered by Apna Score',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
      ),
    );

    final String fileName =
        '${tournament.name.replaceAll(' ', '_')}_Report.pdf';
    await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
  }

  static List<PdfTeamStanding> _calculatePdfStandings(
    TournamentModel tournament,
    List<MatchModel> matches,
  ) {
    final standingsMap = <String, PdfTeamStanding>{};

    for (int i = 0; i < tournament.teamIds.length; i++) {
      standingsMap[tournament.teamIds[i]] = PdfTeamStanding(
        tournament.teamIds[i],
        tournament.teamNames[i],
      );
    }

    for (var match in matches.where((m) => m.isCompleted)) {
      final teamA = standingsMap[match.teamAId ?? ''];
      final teamB = standingsMap[match.teamBId ?? ''];

      if (teamA != null && teamB != null) {
        teamA.matches++;
        teamB.matches++;

        teamA.runsScored += match.teamAScore.runs;
        teamA.ballsFaced += match.teamBScore.totalBalls;
        teamA.runsConceded += match.teamBScore.runs;
        teamA.ballsBowled += match.teamAScore.totalBalls;

        teamB.runsScored += match.teamBScore.runs;
        teamB.ballsFaced += match.teamAScore.totalBalls;
        teamB.runsConceded += match.teamAScore.runs;
        teamB.ballsBowled += match.teamBScore.totalBalls;

        if (match.winnerId == teamA.id) {
          teamA.wins++;
          teamA.points += 2;
          teamB.losses++;
        } else if (match.winnerId == teamB.id) {
          teamB.wins++;
          teamB.points += 2;
          teamA.losses++;
        } else {
          teamA.points += 1;
          teamB.points += 1;
        }
      }
    }

    final list = standingsMap.values.toList();
    list.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      if (b.wins != a.wins) return b.wins.compareTo(a.wins);
      return b.nrr.compareTo(a.nrr);
    });

    return list;
  }

  static pw.Widget _buildHeader(
    TournamentModel tournament,
    DateFormat dateFormat,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          tournament.name.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.teal900,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'OFFICIAL TOURNAMENT REPORT',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
            letterSpacing: 1.5,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.teal, thickness: 1),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Date: ${dateFormat.format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Status: ${tournament.status.toUpperCase()}',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color:
                    tournament.status == 'completed'
                        ? PdfColors.green700
                        : PdfColors.orange700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildOverview(
    TournamentModel tournament,
    List<MatchModel> matches,
    PdfTeamStanding? winner,
  ) {
    final completedCount = matches.where((m) => m.isCompleted).length;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('SUMMARY'),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            _buildStatBox('MATCHES', '$completedCount / ${matches.length}'),
            pw.SizedBox(width: 15),
            _buildStatBox('TEAMS', '${tournament.teamIds.length}'),
          ],
        ),
        if (tournament.status == 'completed' && winner != null) ...[
          pw.SizedBox(height: 15),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.green700, width: 1),
            ),
            child: pw.Row(
              children: [
                pw.Text('🏆 ', style: pw.TextStyle(fontSize: 16)),
                pw.SizedBox(width: 8),
                pw.Text(
                  'TOURNAMENT WINNER: ',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                    fontSize: 12,
                  ),
                ),
                pw.Text(
                  winner.name.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildPointsTable(List<PdfTeamStanding> standings) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('POINTS TABLE'),
        pw.SizedBox(height: 10),
        _buildLeaderTable(
          '',
          ['Rank', 'Team', 'P', 'W', 'L', 'Pts', 'NRR'],
          List.generate(standings.length, (index) {
            final s = standings[index];
            return [
              '${index + 1}',
              s.name,
              '${s.matches}',
              '${s.wins}',
              '${s.losses}',
              '${s.points}',
              s.nrr.toStringAsFixed(3),
            ];
          }),
        ),
      ],
    );
  }

  static pw.Widget _buildLeaderboard(List<TournamentPlayerStats> leaderboard) {
    final topBatters = [...leaderboard];
    topBatters.sort((a, b) => b.runs.compareTo(a.runs));
    final displayBatters = topBatters.take(5).toList();

    final topBowlers = [...leaderboard];
    topBowlers.sort((a, b) => b.wickets.compareTo(a.wickets));
    final displayBowlers = topBowlers.take(5).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('TOP PERFORMANCES'),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _buildLeaderTable(
                'BATSMEN',
                ['Player', 'Runs', 'SR'],
                displayBatters
                    .map(
                      (s) => [
                        '${s.name} (${s.teamName})',
                        '${s.runs}',
                        s.strikeRate.toStringAsFixed(1),
                      ],
                    )
                    .toList(),
              ),
            ),
            pw.SizedBox(width: 15),
            pw.Expanded(
              child: _buildLeaderTable(
                'BOWLERS',
                ['Player', 'Wkts', 'Econ'],
                displayBowlers
                    .map(
                      (s) => [
                        '${s.name} (${s.teamName})',
                        '${s.wickets}',
                        s.economy.toStringAsFixed(1),
                      ],
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildMatchList(
    List<MatchModel> matches,
    DateFormat dateFormat,
    List<TournamentPlayerStats> leaderboard,
  ) {
    final completedMatches = matches.where((m) => m.isCompleted).toList();
    if (completedMatches.isEmpty) return pw.SizedBox.shrink();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('MATCH RESULTS'),
        pw.SizedBox(height: 10),
        ...completedMatches
            .map((match) => _buildMatchCard(match, dateFormat, leaderboard))
            .toList(),
      ],
    );
  }

  static pw.Widget _buildMatchCard(
    MatchModel match,
    DateFormat dateFormat,
    List<TournamentPlayerStats> leaderboard,
  ) {
    String momDisplay = match.manOfMatchName ?? 'Not Awarded';

    // Attempt to find player stats to get team name
    if (match.manOfMatch != null) {
      final stats = leaderboard.firstWhereOrNull(
        (s) => s.playerId == match.manOfMatch,
      );
      if (stats != null) {
        momDisplay = '${stats.name} (${stats.teamName})';
      } else {
        // Fallback: Check if we can identify team from match data
        if (match.teamAPlayers.contains(match.manOfMatch)) {
          momDisplay = '${match.manOfMatchName} (${match.teamAName})';
        } else if (match.teamBPlayers.contains(match.manOfMatch)) {
          momDisplay = '${match.manOfMatchName} (${match.teamBName})';
        }
      }
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Text('🏏 ', style: pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(width: 4),
                  pw.Text(
                    'MATCH ${match.matchNumber ?? ''}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.Text(
                dateFormat.format(match.createdAt),
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      match.teamAName,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.Text(
                      '${match.teamAScore.runs}/${match.teamAScore.wickets} (${match.teamAScore.oversDisplay})',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Text(
                'vs',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      match.teamBName,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.Text(
                      '${match.teamBScore.runs}/${match.teamBScore.wickets} (${match.teamBScore.oversDisplay})',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (match.result != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              match.result!,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal800,
              ),
            ),
          ],
          if (match.manOfMatchName != null &&
              match.manOfMatchName!.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                pw.Text('🎯 ', style: pw.TextStyle(fontSize: 10)),
                pw.SizedBox(width: 4),
                pw.Text(
                  'Man of the Match: ',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  momDisplay,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey900,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.teal700,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Container(width: 30, height: 1.5, color: PdfColors.teal),
      ],
    );
  }

  static pw.Widget _buildStatBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLeaderTable(
    String title,
    List<String> headers,
    List<List<String>> data,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              title,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: data,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 8,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: PdfColors.teal),
          cellStyle: pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),
      ],
    );
  }
}
