import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:cidy/app_styles.dart';
import 'package:cidy/authentication/login.dart';
import 'package:cidy/config.dart';
import 'package:cidy/app_tools.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_layout.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_student_detail_screen/delete_student_popup.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_student_detail_screen/edit_student_popup.dart';

class TeacherStudentDetailScreen extends StatefulWidget {
  final int studentId;
  const TeacherStudentDetailScreen({super.key, required this.studentId});

  @override
  State<TeacherStudentDetailScreen> createState() =>
      _TeacherStudentDetailScreenState();
}

class _TeacherStudentDetailScreenState
    extends State<TeacherStudentDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _student;

  int? _selectedGroupId;
  Map<String, dynamic> _levelSectionOptions = {};
  bool _canEditLevelSection = false;

  final ScrollController _pageScrollController = ScrollController();

  // Calendar state
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final List<String> _monthNames = const [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  @override
  void initState() {
    super.initState();
    _fetchStudentDetail();
  }

  @override
  void dispose() {
    _pageScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudentDetail({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = null;
      });
    }

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (!mounted) return;

      if (token == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/students/${widget.studentId}/',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        setState(() {
          _student = data['student_detail'];
          _levelSectionOptions =
              data['teacher_levels_sections_subjects_hierarchy'];
          _canEditLevelSection = data['student_detail']['groups'].isEmpty;
          if (data['student_detail']['groups'].isNotEmpty) {
            _selectedGroupId = _resolveGroupId(
              data['student_detail']['groups'][0]['id'],
            );
          } else {
            _selectedGroupId = null;
          }
        });
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        setState(() {
          _errorMessage = "Échec du chargement de l'élève.";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Échec du chargement de l'élève.";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildSquareButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: primaryColor),
        ),
      ),
    );
  }

  void _showEditStudentDialog() {
    if (_student == null) return;
    final student = _student!;
    final genderValue = _stringOrEmpty(student['gender']);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditStudentPopup(
          studentId: student['id'] as int,
          initialFullname: _stringOrEmpty(student['fullname']),
          initialPhoneNumber: _stringOrEmpty(student['phone_number']),
          initialGender: genderValue.isEmpty ? 'M' : genderValue,
          initialLevel: _stringOrEmpty(student['level']),
          initialSection: _stringOrNull(student['section']),
          initialImage: _stringOrNull(student['image']),
          filterOptions: _levelSectionOptions,
          canEditLevelSection: _canEditLevelSection,
          onStudentUpdated: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showSuccess('Élève modifié avec succès');
            _fetchStudentDetail(showLoading: true);
          },
          onServerError: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showError('Erreur du serveur (500).');
            _fetchStudentDetail(showLoading: true);
          },
        );
      },
    );
  }

  Future<void> _showDeleteStudentConfirmationDialog() async {
    if (_student == null) return;
    final studentName = _stringOrEmpty(_student!['fullname']);

    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return DeleteStudentPopup(
          studentId: widget.studentId,
          studentName: studentName.isEmpty ? 'cet élève' : studentName,
          onStudentDeleted: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
          onServerError: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showError('Erreur du serveur (500).');
          },
        );
      },
    );
  }

  Map<String, dynamic>? _selectedGroup() {
    final groups = _studentGroups();
    final selectedId = _selectedGroupId;
    if (selectedId == null) return null;
    for (final entry in groups) {
      final id = _resolveGroupId(entry['id']);
      if (id != null && id == selectedId) {
        return entry;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TeacherLayout(
      title: _student != null ? 'Élève : ${_student!['fullname']}' : '...',
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (_errorMessage != null) {
      return Center(child: Text('Erreur : $_errorMessage'));
    }

    if (_student == null) {
      return const Center(child: Text('Élève introuvable.'));
    }

    return RefreshIndicator(
      onRefresh: () => _fetchStudentDetail(showLoading: false),
      child: SingleChildScrollView(
        controller: _pageScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderCard(),
            _buildGlobalKpisRow(),
            const SizedBox(height: 12),
            _buildGroupSelectorCard(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final student = _student!;
    final imageUrl = _stringOrNull(student['image']);
    final fullImageUrl = imageUrl != null
        ? '${Config.backendUrl}$imageUrl'
        : null;
    final fullname = _stringOrEmpty(student['fullname']);
    final level = _stringOrEmpty(student['level']);
    final section = _stringOrNull(student['section']);
    final phone = _stringOrEmpty(student['phone_number']);

    final levelParts = <String>[];
    if (level.isNotEmpty) levelParts.add(level);
    if (section != null && section.isNotEmpty) levelParts.add(section);
    final levelSection = levelParts.join(' - ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 70,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: fullImageUrl != null
                    ? NetworkImage(fullImageUrl)
                    : null,
                child: fullImageUrl == null
                    ? Icon(Icons.person, size: 70, color: Colors.grey.shade600)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                fullname.isEmpty ? '--' : fullname,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (levelSection.isNotEmpty)
                Text(
                  levelSection,
                  style: const TextStyle(fontSize: mediumFontSize),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              Text(
                phone.isEmpty ? '--' : phone,
                style: const TextStyle(fontSize: mediumFontSize),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  _buildSquareButton(Icons.edit, _showEditStudentDialog),
                  _buildSquareButton(
                    Icons.delete,
                    _showDeleteStudentConfirmationDialog,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalKpisRow() {
    final paidAmount = formatToK(_student!['paid_amount']);
    final unpaidAmount = formatToK(_student!['unpaid_amount']);

    return Row(
      children: [
        Expanded(child: _buildKpiCard(paidAmount, 'payé', Colors.green)),
        Expanded(child: _buildKpiCard(unpaidAmount, 'impayé', Colors.red)),
      ],
    );
  }

  Widget _buildGroupSelectorCard() {
    final groups = _studentGroups();
    final dropdownItems = <DropdownMenuItem<int>>[];

    for (final entry in groups) {
      final id = _resolveGroupId(entry['id']);
      if (id != null) {
        final label = _groupOptionLabel(entry);
        dropdownItems.add(
          DropdownMenuItem<int>(
            value: id,
            child: Text(label.isEmpty ? 'Group $id' : label),
          ),
        );
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey.shade200,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Groupes'),
            const Divider(height: 24),
            const Text(
              'Groupe',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            if (dropdownItems.isEmpty)
              const Text('Aucun groupe attribué à cet élève.')
            else
              DropdownButtonFormField<int>(
                value: _selectedGroupId,
                items: dropdownItems,
                onChanged: (val) {
                  setState(() {
                    _selectedGroupId = val;
                  });
                },
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _buildGroupKpisRow(),
            const SizedBox(height: 24),
            _buildSectionHeader('Calendrier'),
            const Divider(height: 24),
            _buildCalendarHeader(),
            const SizedBox(height: 12),
            _buildCalendarGrid(),
            const SizedBox(height: 8),
            _buildCalendarLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupKpisRow() {
    final group = _selectedGroup();
    final paidAmount = formatToK(group != null ? group['paid_amount'] : null);
    final unpaidAmount = formatToK(
      group != null ? group['unpaid_amount'] : null,
    );
    final groupLabel = group != null ? _groupNameLabel(group) : 'Groupe';

    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            '$paidAmount',
            '$groupLabel - payé',
            Colors.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKpiCard(
            '$unpaidAmount',
            '$groupLabel - impayé',
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String value, String label, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey.shade200,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(
                _focusedMonth.year,
                _focusedMonth.month - 1,
              );
            });
          },
        ),
        Expanded(
          child: Center(
            child: Text(
              '${_monthNames[_focusedMonth.month - 1]} ${_focusedMonth.year}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(
                _focusedMonth.year,
                _focusedMonth.month + 1,
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildCalendarLegend() {
    Widget colorSquare(Color c) => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        Row(
          children: [
            colorSquare(_colorForStatus('attended_and_paid') ?? Colors.green),
            const SizedBox(width: 6),
            const Text('Présent et payé'),
          ],
        ),
        Row(
          children: [
            colorSquare(
              _colorForStatus('attended_and_payment_due') ?? Colors.red,
            ),
            const SizedBox(width: 6),
            const Text('Présent et paiement en retard'),
          ],
        ),
        Row(
          children: [
            colorSquare(
              _colorForStatus('attended_and_payment_not_due') ?? Colors.orange,
            ),
            const SizedBox(width: 6),
            const Text('Présent et paiement non exigible'),
          ],
        ),
        Row(
          children: [
            colorSquare(_colorForStatus('absent') ?? Colors.blueGrey),
            const SizedBox(width: 6),
            const Text('Absent'),
          ],
        ),
        Row(
          children: [
            colorSquare(Colors.grey),
            const SizedBox(width: 6),
            const Text('Cours planifié'),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: mediumFontSize,
        fontWeight: FontWeight.bold,
        color: primaryColor,
      ),
    );
  }

  List<Map<String, dynamic>> _extractGroups(dynamic raw) {
    if (raw is List) {
      final result = <Map<String, dynamic>>[];
      for (final entry in raw) {
        if (entry is Map<String, dynamic>) {
          result.add(Map<String, dynamic>.from(entry));
        } else if (entry is Map) {
          result.add(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      }
      return result;
    }
    return <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _studentGroups() {
    final groups = _student?['groups'];
    if (groups is List<Map<String, dynamic>>) {
      return groups;
    }
    return _extractGroups(groups);
  }

  Map<String, dynamic> _mapStringDynamic(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return {};
  }

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  String _stringOrEmpty(dynamic value) => _stringOrNull(value) ?? '';

  int? _resolveGroupId(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is String) {
      return int.tryParse(raw.trim());
    }
    return null;
  }

  String _groupOptionLabel(Map<String, dynamic> group) {
    dynamic subject =
        group['subject'] ?? group['subject_name'] ?? group['subject_label'];
    if (subject is Map<String, dynamic>) {
      subject = subject['name'] ?? subject['label'] ?? subject['subject'];
    }
    final subjectText = _stringOrEmpty(subject);
    final nameText = _stringOrEmpty(group['name']);

    if (subjectText.isNotEmpty && nameText.isNotEmpty) {
      return '$subjectText - $nameText';
    }
    if (nameText.isNotEmpty) {
      return nameText;
    }
    if (subjectText.isNotEmpty) {
      return subjectText;
    }

    final id = group['id'];
    if (id is int) {
      return 'Groupe $id';
    }
    return 'Groupe';
  }

  String _groupNameLabel(Map<String, dynamic> group) {
    final nameText = _stringOrEmpty(group['name']);
    if (nameText.isNotEmpty) {
      return nameText;
    }
    final id = _resolveGroupId(group['id']);
    if (id != null) {
      return 'Groupe $id';
    }
    return 'Groupe';
  }

  String _normalizeStatusKey(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    var normalized = trimmed
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'__+'), '_')
        .toLowerCase();

    if (normalized.startsWith('the_')) {
      normalized = normalized.substring(4);
    }
    if (normalized.endsWith('_the')) {
      normalized = normalized.substring(0, normalized.length - 4);
    }
    normalized = normalized.replaceAll('_the_', '_');
    normalized = normalized.replaceAll(RegExp(r'__+'), '_');
    normalized = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized;
  }

  Color? _colorForStatus(String statusKey) {
    switch (statusKey) {
      case 'attended_and_paid':
      case 'paid':
        return Colors.green;
      case 'attended_and_payment_due':
        return Colors.red;
      case 'attended_and_payment_not_due':
        return Colors.orange;
      case 'absent':
        return Colors.blueGrey;
      case 'present':
      case 'attended':
      case 'attendance':
        return Colors.orange;
    }
    return null;
  }

  String _statusLabel(String statusKey) {
    switch (statusKey) {
      case 'attended_and_paid':
      case 'paid':
        return 'Payé';
      case 'attended_and_payment_due':
        return 'Présent - paiement dû';
      case 'attended_and_payment_not_due':
        return 'Présent - paiement non dû';
      case 'absent':
        return 'Absent';
      case 'present':
      case 'attended':
      case 'attendance':
        return 'Présent';
      default:
        if (statusKey.isEmpty) {
          return 'Statut inconnu';
        }
        final words = statusKey.split('_').where((w) => w.isNotEmpty).toList();
        if (words.isEmpty) {
          return statusKey;
        }
        return words
            .map(
              (word) =>
                  word[0].toUpperCase() +
                  (word.length > 1 ? word.substring(1) : ''),
            )
            .join(' ');
    }
  }

  // Build the grid for the month
  Widget _buildCalendarGrid() {
    final days = _daysInMonth(_focusedMonth);
    final firstWeekday = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      1,
    ).weekday; // 1=Mon..7=Sun
    final leadingEmpty =
        (firstWeekday + 6) % 7; // convert Mon=1 to 0 leading slots

    final totalCells = leadingEmpty + days;
    final rows = (totalCells / 7.0).ceil();

    final cells = <Widget>[];

    // Gather events map by date (yyyy-mm-dd)
    final eventsByDay = _buildEventsMapForFocusedMonth();

    for (int i = 0; i < leadingEmpty; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= days; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final key = _ymdKey(date);
      final events = eventsByDay[key] ?? [];
      final statusColor = _statusColorForEvents(events);
      final tooltip = _tooltipForEvents(events, date);

      final dayContent = Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: statusColor ?? Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: statusColor != null
                ? Colors.transparent
                : Colors.grey.shade300,
          ),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Text(
              '$day',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: statusColor != null ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      );

      final dayCell = AspectRatio(
        aspectRatio: 1,
        child: Tooltip(message: tooltip, child: dayContent),
      );

      cells.add(dayCell);
    }

    return Column(
      children: [
        Row(
          children: [
            for (final label in const [
              'Lun',
              'Mar',
              'Mer',
              'Jeu',
              'Ven',
              'Sam',
              'Dim',
            ])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (int r = 0; r < rows; r++)
          Row(
            children: [
              for (int c = 0; c < 7; c++)
                Expanded(
                  child: cells.length > (r * 7 + c)
                      ? cells[r * 7 + c]
                      : const SizedBox(),
                ),
            ],
          ),
      ],
    );
  }

  // Build map yyyy-mm-dd -> list of event maps
  Map<String, List<Map<String, dynamic>>> _buildEventsMapForFocusedMonth() {
    final map = <String, List<Map<String, dynamic>>>{};

    final group = _selectedGroup();
    final now = DateTime.now();
    final isCurrentMonth =
        _focusedMonth.year == now.year && _focusedMonth.month == now.month;
    final isFutureMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
    ).isAfter(DateTime(now.year, now.month));

    // Existing classes
    final classes = (group?['classes'] as List?) ?? [];
    for (final cls in classes) {
      final statusRaw = (cls['status'] ?? '').toString();
      final statusKey = _normalizeStatusKey(statusRaw);

      String? dateStr;
      if (statusKey == 'absent') {
        dateStr = cls['absence_date']?.toString();
      }
      dateStr ??= cls['attendance_date']?.toString();

      if (dateStr == null || dateStr.isEmpty) continue;
      final date = DateTime.tryParse(dateStr) ?? _parseYMD(dateStr);
      if (date == null) continue;
      if (date.year != _focusedMonth.year || date.month != _focusedMonth.month)
        continue;

      final paidAtStr = cls['paid_at']?.toString();
      DateTime? paidAt;
      if (paidAtStr != null && paidAtStr.isNotEmpty) {
        paidAt = DateTime.tryParse(paidAtStr);
      }

      String? startTime;
      String? endTime;
      if (statusKey == 'absent') {
        startTime = cls['absence_start_time']?.toString();
        endTime = cls['absence_end_time']?.toString();
      }
      startTime ??= cls['attendance_start_time']?.toString();
      endTime ??= cls['attendance_end_time']?.toString();

      final event = <String, dynamic>{
        'type': statusKey.isEmpty ? 'attendance' : statusKey,
        'status': statusKey,
        'statusRaw': statusRaw,
        'date': date,
        'start': startTime,
        'end': endTime,
        'paidAt': paidAt,
      };

      final key = _ymdKey(date);
      map.putIfAbsent(key, () => []).add(event);
    }

    // Future placeholders based on group's weekly schedule
    if (group != null) {
      final weekDayRaw = group['week_day'];
      int? weekday = _weekdayFromRaw(weekDayRaw);

      final st = group['start_time']?.toString();
      final et = group['end_time']?.toString();

      if (weekday != null) {
        // Iterate all days in month and add placeholders where applicable
        final daysInMonth = _daysInMonth(_focusedMonth);
        for (int d = 1; d <= daysInMonth; d++) {
          final date = DateTime(_focusedMonth.year, _focusedMonth.month, d);
          if (date.weekday != weekday) continue;

          final isFutureDate = date.isAfter(
            DateTime(now.year, now.month, now.day),
          );
          if (isFutureMonth || (isCurrentMonth && isFutureDate)) {
            final key = _ymdKey(date);
            // Only add placeholder if no recorded event
            if (!(map.containsKey(key) && (map[key]?.isNotEmpty ?? false))) {
              final placeholder = <String, dynamic>{
                'type': 'future',
                'status': 'scheduled',
                'date': date,
                'start': st,
                'end': et,
                'paidAt': null,
              };
              map.putIfAbsent(key, () => []).add(placeholder);
            }
          }
        }
      }
    }

    return map;
  }

  // Decide which color background to show for a day
  Color? _statusColorForEvents(List<Map<String, dynamic>> events) {
    if (events.isEmpty) return null;

    for (final event in events) {
      final type = (event['type'] ?? '').toString();
      if (type == 'future') {
        continue;
      }

      final statusKey = _normalizeStatusKey(
        (event['status'] ?? event['statusRaw'] ?? '').toString(),
      );
      if (statusKey.isEmpty) {
        continue;
      }

      final color = _colorForStatus(statusKey);
      if (color != null) {
        return color;
      }
    }

    if (events.any((e) => (e['type'] ?? '') == 'future')) {
      return Colors.grey;
    }

    return null;
  }

  String _tooltipForEvents(List<Map<String, dynamic>> events, DateTime date) {
    if (events.isEmpty) return _formatScheduled(date, null, null);

    final actualEvents = events
        .where((e) => (e['type'] ?? '') != 'future')
        .toList();
    if (actualEvents.isNotEmpty) {
      final event = actualEvents.first;
      final statusKey = _normalizeStatusKey(
        (event['status'] ?? event['statusRaw'] ?? '').toString(),
      );
      final start = event['start']?.toString();
      final end = event['end']?.toString();
      final paidAt = event['paidAt'] as DateTime?;
      final sessionText = _formatAttended(date, start, end);
      final statusLabel = _statusLabel(statusKey);

      var tooltip = '$statusLabel\n$sessionText';
      if (statusKey == 'attended_and_paid' || statusKey == 'paid') {
        final paidText = _formatPaid(paidAt);
        if (paidText.isNotEmpty) {
          tooltip = '$tooltip\n$paidText';
        }
      }
      return tooltip;
    }

    final future = events.firstWhere(
      (e) => (e['type'] ?? '') == 'future',
      orElse: () => <String, dynamic>{},
    );
    if (future.isNotEmpty) {
      final start = future['start']?.toString();
      final end = future['end']?.toString();
      return 'Planifié\n${_formatScheduled(date, start, end)}';
    }

    return _formatScheduled(date, null, null);
  }

  // Helpers
  int _daysInMonth(DateTime d) {
    final firstNext = (d.month == 12)
        ? DateTime(d.year + 1, 1, 1)
        : DateTime(d.year, d.month + 1, 1);
    return firstNext.subtract(const Duration(days: 1)).day;
  }

  int? _weekdayFromRaw(dynamic raw) {
    // Accept int 1=Mon..7=Sun or English names
    if (raw == null) return null;
    if (raw is int) {
      // Ensure 1..7
      if (raw >= 1 && raw <= 7) return raw;
    } else if (raw is String) {
      final s = raw.toLowerCase();
      switch (s) {
        case 'monday':
        case 'mon':
          return DateTime.monday;
        case 'tuesday':
        case 'tue':
          return DateTime.tuesday;
        case 'wednesday':
        case 'wed':
          return DateTime.wednesday;
        case 'thursday':
        case 'thu':
          return DateTime.thursday;
        case 'friday':
        case 'fri':
          return DateTime.friday;
        case 'saturday':
        case 'sat':
          return DateTime.saturday;
        case 'sunday':
        case 'sun':
          return DateTime.sunday;
      }
      // Try numeric in string
      final asInt = int.tryParse(raw);
      if (asInt != null && asInt >= 1 && asInt <= 7) return asInt;
    }
    return null;
  }

  String _ymdKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime? _parseYMD(String input) {
    // Accept 'YYYY-MM-DD' and return DateTime
    try {
      final parts = input.split('-');
      if (parts.length == 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        return DateTime(y, m, d);
      }
    } catch (_) {}
    return null;
  }

  String _formatDateDMY(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatTimeHM(String? time) {
    if (time == null || time.isEmpty) return '';
    // expect 'HH:MM[:SS]'
    final parts = time.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return time;
  }

  String _formatAttended(DateTime date, String? start, String? end) {
    final s = _formatTimeHM(start);
    final e = _formatTimeHM(end);
    return 'Séance du ${_formatDateDMY(date)} de ${s.isEmpty ? '--:--' : s} à ${e.isEmpty ? '--:--' : e}';
  }

  String _formatPaid(DateTime? paidAt) {
    if (paidAt == null) return '';
    final d = _formatDateDMY(paidAt);
    final h = _formatTimeHM('${paidAt.hour}:${paidAt.minute}');
    return 'Paiement enregistré le $d à $h';
  }

  String _formatScheduled(DateTime date, String? start, String? end) {
    final s = _formatTimeHM(start);
    final e = _formatTimeHM(end);
    return 'Cours prévu le ${_formatDateDMY(date)} de ${s.isEmpty ? '--:--' : s} à ${e.isEmpty ? '--:--' : e}';
  }
}
