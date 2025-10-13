import 'package:flutter/material.dart';
import 'package:cidy/app_styles.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cidy/config.dart';
import 'package:cidy/authentication/login.dart';
import '../widgets/teacher_layout.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  bool _isLoading = true;
  bool _hasLevels = false;
  bool _isFetchingData = false;
  Map<String, dynamic>? _dashboardData;
  String _selectedRange = '';
  DateTime? _startDate;
  DateTime? _endDate;

  // UI Colors
  static const Color paidColor = Color(0xFF27AE60);
  static const Color unpaidColor = Color(0xFFC0392B);
  static const Color studentsColor = Color(0xFF2980B9);
  static const Color cardBackgroundColor = Colors.white;
  static const Color scaffoldBackgroundColor = Color(0xFFF5F7FA);

  Color get _primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _initializeLocaleAndData();
  }

  Future<void> _initializeLocaleAndData() async {
    try {
      await initializeDateFormatting('fr_FR', null);
    } catch (_) {
      // If initialization fails, continue with default formatting.
    } finally {
      if (mounted) {
        _fetchDashboardData(showLoadingOverlay: true);
      }
    }
  }

  Future<void> _fetchDashboardData({bool showLoadingOverlay = false}) async {
    setState(() {
      if (showLoadingOverlay) {
        _isLoading = true;
      }
      _isFetchingData = true;
    });

    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (!mounted) return;

    if (token == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
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
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _hasLevels = data['has_levels'];
          if (_hasLevels) {
            _dashboardData = data['dashboard'];
          }
        });
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${response.reasonPhrase}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Une erreur est survenue: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (showLoadingOverlay) {
            _isLoading = false;
          }
          _isFetchingData = false;
        });
      }
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _primaryColor,
              onPrimary: Colors.white,
            ),
            // Fix text overflow issues with more conservative font sizes
            textTheme: Theme.of(context).textTheme.copyWith(
              headlineSmall: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(
                    fontSize:
                        18, // Further reduce font size to prevent overflow
                  ),
              titleMedium: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 13, // Reduce font size for date labels
              ),
              bodyLarge: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 13, // Reduce font size for input fields
              ),
              labelLarge: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 12, // Reduce button text size
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted) return;

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedRange = ''; // Custom range
      });
      _fetchDashboardData();
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedRange = ''; // Reset to default
    });
    _fetchDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return TeacherLayout(
      title: "Tableau de bord",
      body: Container(
        color: scaffoldBackgroundColor,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : _hasLevels
            ? _buildDashboard()
            : _buildNoLevelsWidget(),
      ),
    );
  }

  Widget _buildNoLevelsWidget() {
    final primaryColor = _primaryColor;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_outlined, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
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
              "Il semble que vous n’ayez pas encore ajouté de niveau. Créez-en un pour commencer à suivre vos performances.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final primaryColor = _primaryColor;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: _buildDateRangePicker(),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _fetchDashboardData(),
            color: primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverallPerformance(),
                  const SizedBox(height: 24),
                  _buildLevelsBreakdown(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangePicker() {
    final primaryColor = _primaryColor;
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
              "Filtrer par date",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            if (_isFetchingData)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: primaryColor,
                  backgroundColor: const Color(0xFFE8EAF0),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDateRange(context),
                    icon: Icon(
                      Icons.calendar_today,
                      color: primaryColor,
                      size: 18,
                    ),
                    label: const Text("Personnalisé"),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            if (_startDate != null && _endDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF2F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          "${DateFormat.yMMMd('fr_FR').format(_startDate!)} → ${DateFormat.yMMMd('fr_FR').format(_endDate!)}",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _clearDateRange,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.red[600],
                          ),
                        ),
                      ),
                    ],
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
    final primaryColor = _primaryColor;
    final isSelected = _selectedRange == range;
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            // Toggle off if already selected
            if (isSelected) {
              _selectedRange = '';
            } else {
              _selectedRange = range;
              _startDate = null;
              _endDate = null;
            }
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
    final primaryColor = _primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
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
                "${_dashboardData!['total_paid_amount']} DT",
                paidColor,
                Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                "Montant Impayé",
                "${_dashboardData!['total_unpaid_amount']} DT",
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
          const BoxShadow(
            color: Color.fromRGBO(158, 158, 158, 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelsBreakdown() {
    final levels = _dashboardData!['levels'] as Map<String, dynamic>;
    final primaryColor = _primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
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
    final primaryColor = _primaryColor;
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
              style: TextStyle(
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
                primaryColor,
              ),
            if (!levelData.containsKey('sections') &&
                levelData.containsKey('subjects'))
              _buildSubjectsCollapse(
                levelData['subjects'] as Map<String, dynamic>,
                primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  // Collapsible list for Sections inside a Level card
  Widget _buildSectionsCollapse(
    Map<String, dynamic> sections,
    Color primaryColor,
  ) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
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
    final primaryColor = _primaryColor;
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
                primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  // Collapsible list for Subjects inside a Section or Level card
  Widget _buildSubjectsCollapse(
    Map<String, dynamic> subjects,
    Color primaryColor,
  ) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
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
            value: "${data['total_paid_amount']} DT",
            color: paidColor,
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMiniKpi(
            label: 'Impayé',
            value: "${data['total_unpaid_amount']} DT",
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
        border: Border.all(color: const Color.fromRGBO(158, 158, 158, 0.15)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
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
