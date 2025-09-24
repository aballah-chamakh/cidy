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

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    print("=================== fetch dashboard data");
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token == null) {
      // Handle not logged in
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
      print("=========== Response status: ${response.statusCode}");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _hasGroups = data['has_groups'];
          if (_hasGroups) {
            _dashboardData = data['dashboard'];
          }
        });
      } else {
        // Handle error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: ${response.reasonPhrase}')),
          );
        }
      }
    } catch (e) {
      // Handle exception
    } finally {
      setState(() {
        _isLoading = false;
      });
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasGroups
          ? _buildDashboard()
          : _buildNoGroupsWidget(),
    );
  }

  Widget _buildNoGroupsWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            "Vous n'avez aucun KPI de tableau de bord car vous n'avez aucun groupe.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateRangePicker(),
          const SizedBox(height: 20),
          _buildOverallPerformance(),
          const SizedBox(height: 20),
          _buildLevelsBreakdown(),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Sélectionnez la plage de dates",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: [
            ChoiceChip(
              label: const Text("Cette semaine"),
              selected: _selectedRange == 'this_week',
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedRange = 'this_week';
                    _startDate = null;
                    _endDate = null;
                  });
                  _fetchDashboardData();
                }
              },
            ),
            ChoiceChip(
              label: const Text("Ce mois-ci"),
              selected: _selectedRange == 'this_month',
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedRange = 'this_month';
                    _startDate = null;
                    _endDate = null;
                  });
                  _fetchDashboardData();
                }
              },
            ),
            ChoiceChip(
              label: const Text("Cette année"),
              selected: _selectedRange == 'this_year',
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedRange = 'this_year';
                    _startDate = null;
                    _endDate = null;
                  });
                  _fetchDashboardData();
                }
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.calendar_today),
              label: const Text("Personnalisé"),
              onPressed: () => _selectDateRange(context),
            ),
          ],
        ),
        if (_startDate != null && _endDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              "Plage personnalisée: ${DateFormat.yMMMd().format(_startDate!)} - ${DateFormat.yMMMd().format(_endDate!)}",
            ),
          ),
      ],
    );
  }

  Widget _buildOverallPerformance() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Performance globale",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildKpiRow(
              "Montant total payé",
              "${_dashboardData!['total_paid_amount']} DZD",
              Colors.green,
            ),
            _buildKpiRow(
              "Montant total impayé",
              "${_dashboardData!['total_unpaid_amount']} DZD",
              Colors.red,
            ),
            _buildKpiRow(
              "Étudiants actifs",
              _dashboardData!['total_active_students'].toString(),
              Colors.blue,
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
          "Répartition par niveaux",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...levels.entries.map((levelEntry) {
          final levelName = levelEntry.key;
          final levelData = levelEntry.value;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ExpansionTile(
              title: Text(
                levelName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      _buildKpiRow(
                        "Payé",
                        "${levelData['total_paid_amount']} DZD",
                        Colors.green,
                      ),
                      _buildKpiRow(
                        "Impayé",
                        "${levelData['total_unpaid_amount']} DZD",
                        Colors.red,
                      ),
                      _buildKpiRow(
                        "Étudiants actifs",
                        levelData['total_active_students'].toString(),
                        Colors.blue,
                      ),
                      if (levelData.containsKey('sections'))
                        _buildSectionsBreakdown(
                          levelData['sections'] as Map<String, dynamic>,
                        ),
                      if (levelData.containsKey('subjects') &&
                          !levelData.containsKey('sections'))
                        _buildSubjectsBreakdown(
                          levelData['subjects'] as Map<String, dynamic>,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSectionsBreakdown(Map<String, dynamic> sections) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections.entries.map((sectionEntry) {
          final sectionName = sectionEntry.key;
          final sectionData = sectionEntry.value;
          return ExpansionTile(
            title: Text(
              sectionName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    _buildKpiRow(
                      "Payé",
                      "${sectionData['total_paid_amount']} DZD",
                      Colors.green,
                    ),
                    _buildKpiRow(
                      "Impayé",
                      "${sectionData['total_unpaid_amount']} DZD",
                      Colors.red,
                    ),
                    _buildKpiRow(
                      "Étudiants actifs",
                      sectionData['total_active_students'].toString(),
                      Colors.blue,
                    ),
                    if (sectionData.containsKey('subjects'))
                      _buildSubjectsBreakdown(
                        sectionData['subjects'] as Map<String, dynamic>,
                      ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubjectsBreakdown(Map<String, dynamic> subjects) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: subjects.entries.map((subjectEntry) {
          final subjectName = subjectEntry.key;
          final subjectData = subjectEntry.value;
          return ExpansionTile(
            title: Text(subjectName),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    _buildKpiRow(
                      "Payé",
                      "${subjectData['total_paid_amount']} DZD",
                      Colors.green,
                    ),
                    _buildKpiRow(
                      "Impayé",
                      "${subjectData['total_unpaid_amount']} DZD",
                      Colors.red,
                    ),
                    _buildKpiRow(
                      "Étudiants actifs",
                      subjectData['total_active_students'].toString(),
                      Colors.blue,
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
