import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:cidy/config.dart';
import '../widgets/teacher_layout.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  bool _isLoading = true;
  bool _hasGroups = false;
  Map<String, dynamic>? _dashboardData;
  String _selectedRange = 'this_month';
  DateTime? _startDate;
  DateTime? _endDate;

  // UI Colors
  static const Color primaryColor = Color(0xFF384059);
  static const Color paidColor = Color(0xFF27AE60);
  static const Color unpaidColor = Color(0xFFC0392B);
  static const Color studentsColor = Color(0xFF2980B9);
  static const Color cardBackgroundColor = Colors.white;
  static const Color scaffoldBackgroundColor = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
    });
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    String url;
    if (_startDate != null && _endDate != null) {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);
      url =
          '${Config.backendUrl}/api/teacher/get_dashboard_data/?start_date=$startDateStr&end_date=$endDateStr';
    } else {
      url =
          '${Config.backendUrl}/api/teacher/get_dashboard_data/?date_range=$_selectedRange';
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (mounted) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _hasGroups = data['has_groups'];
            if (_hasGroups) {
              _dashboardData = data['dashboard'];
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${response.reasonPhrase}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Une erreur est survenue: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = DateTimeRange(
      start: _startDate ?? DateTime.now(),
      end: _endDate ?? DateTime.now(),
    );
    final newDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initialDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primaryColor),
            ),
          ),
          child: child!,
        );
      },
    );

    if (newDateRange != null) {
      setState(() {
        _startDate = newDateRange.start;
        _endDate = newDateRange.end;
        _selectedRange = ''; // Custom range
      });
      _fetchDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TeacherLayout(
      title: "Tableau de bord",
      body: Container(
        color: scaffoldBackgroundColor,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              )
            : _hasGroups
            ? _buildDashboard()
            : _buildNoGroupsWidget(),
      ),
    );
  }

  Widget _buildNoGroupsWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sentiment_dissatisfied_outlined,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            const Text(
              "Aucune donnée de tableau de bord",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Il semble que vous n'ayez encore aucun groupe. Créez un groupe pour commencer à suivre vos performances.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      color: primaryColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateRangePicker(),
            const SizedBox(height: 24),
            _buildOverallPerformance(),
            const SizedBox(height: 24),
            _buildLevelsBreakdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Card(
      elevation: 2,
      color: cardBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Filtrer par date",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _selectDateRange(context),
                icon: const Icon(
                  Icons.calendar_today,
                  color: primaryColor,
                  size: 18,
                ),
                label: const Text("Personnalisé"),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: primaryColor,
                ),
              ),
            ),
            if (_startDate != null && _endDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF2F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${DateFormat.yMMMd('fr_FR').format(_startDate!)} → ${DateFormat.yMMMd('fr_FR').format(_endDate!)}",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 5,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: SizedBox.expand(
                      child: _buildChoiceChip("Cette semaine", 'this_week'),
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: SizedBox.expand(
                      child: _buildChoiceChip("Ce mois-ci", 'this_month'),
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: SizedBox.expand(
                      child: _buildChoiceChip("Cette année", 'this_year'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, String range) {
    final isSelected = _selectedRange == range;
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _selectedRange = range;
            _startDate = null;
            _endDate = null;
          });
          _fetchDashboardData();
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isSelected ? primaryColor : Colors.grey[300]!,
          ),
          backgroundColor: isSelected ? primaryColor : Colors.white,
          foregroundColor: isSelected ? Colors.white : primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          padding: EdgeInsets.zero,
        ),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _buildOverallPerformance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Performance globale",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                "Montant Payé",
                "${_dashboardData!['total_paid_amount']} DZD",
                paidColor,
                Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                "Montant Impayé",
                "${_dashboardData!['total_unpaid_amount']} DZD",
                unpaidColor,
                Icons.hourglass_empty_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                "Étudiants Actifs",
                _dashboardData!['total_active_students'].toString(),
                studentsColor,
                Icons.people_outline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelsBreakdown() {
    final levels = _dashboardData!['levels'] as Map<String, dynamic>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Performances des niveaux",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        // List of level cards (non-collapsible)
        Column(
          children: levels.entries.map((levelEntry) {
            final levelName = levelEntry.key;
            final levelData = levelEntry.value as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildLevelCard(levelName, levelData),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Card for a Level with KPIs row and optional collapsed Sections/Subjects
  Widget _buildLevelCard(String levelName, Map<String, dynamic> levelData) {
    return Card(
      elevation: 2,
      color: cardBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              levelName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildMiniKpisRow(levelData),
            const SizedBox(height: 8),
            if (levelData.containsKey('sections'))
              _buildSectionsCollapse(
                levelData['sections'] as Map<String, dynamic>,
              ),
            if (!levelData.containsKey('sections') &&
                levelData.containsKey('subjects'))
              _buildSubjectsCollapse(
                levelData['subjects'] as Map<String, dynamic>,
              ),
          ],
        ),
      ),
    );
  }

  // Collapsible list for Sections inside a Level card
  Widget _buildSectionsCollapse(Map<String, dynamic> sections) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        'Sections',
        style: TextStyle(fontWeight: FontWeight.w600, color: primaryColor),
      ),
      collapsedIconColor: primaryColor,
      iconColor: primaryColor,
      children: [
        const SizedBox(height: 4),
        Column(
          children: sections.entries.map((sectionEntry) {
            final sectionName = sectionEntry.key;
            final sectionData = sectionEntry.value as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildSectionCard(sectionName, sectionData),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Card for a Section with KPIs row and optional collapsed Subjects
  Widget _buildSectionCard(
    String sectionName,
    Map<String, dynamic> sectionData,
  ) {
    return Card(
      elevation: 1,
      color: cardBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sectionName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF555555),
              ),
            ),
            const SizedBox(height: 12),
            _buildMiniKpisRow(sectionData),
            const SizedBox(height: 8),
            if (sectionData.containsKey('subjects'))
              _buildSubjectsCollapse(
                sectionData['subjects'] as Map<String, dynamic>,
              ),
          ],
        ),
      ),
    );
  }

  // Collapsible list for Subjects inside a Section or Level card
  Widget _buildSubjectsCollapse(Map<String, dynamic> subjects) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        'Matières',
        style: TextStyle(fontWeight: FontWeight.w600, color: primaryColor),
      ),
      collapsedIconColor: primaryColor,
      iconColor: primaryColor,
      children: [
        const SizedBox(height: 4),
        Column(
          children: subjects.entries.map((subjectEntry) {
            final subjectName = subjectEntry.key;
            final subjectData = subjectEntry.value as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildSubjectCard(subjectName, subjectData),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Card for a Subject with KPIs row (no further collapse)
  Widget _buildSubjectCard(
    String subjectName,
    Map<String, dynamic> subjectData,
  ) {
    return Card(
      elevation: 1,
      color: cardBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subjectName,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 12),
            _buildMiniKpisRow(subjectData),
          ],
        ),
      ),
    );
  }

  // Shared 3-KPI row used inside Level/Section/Subject cards
  Widget _buildMiniKpisRow(Map<String, dynamic> data) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniKpi(
            label: 'Payé',
            value: "${data['total_paid_amount']} DZD",
            color: paidColor,
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMiniKpi(
            label: 'Impayé',
            value: "${data['total_unpaid_amount']} DZD",
            color: unpaidColor,
            icon: Icons.hourglass_empty_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMiniKpi(
            label: 'Étudiants actifs',
            value: data['total_active_students'].toString(),
            color: studentsColor,
            icon: Icons.people_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniKpi({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
