import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:cidy/app_styles.dart';
import 'package:cidy/authentication/login.dart';
import 'package:cidy/config.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_layout.dart';

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

  final ScrollController _pageScrollController = ScrollController();

  // Calendar state
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final List<String> _monthNames = const [
    'Janvier',
    'Fevrier',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Aout',
    'Septembre',
    'Octobre',
    'Novembre',
    'Decembre',
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
        final raw =
            json.decode(utf8.decode(response.bodyBytes))
                as Map<String, dynamic>;
        setState(() {
          final normalized = Map<String, dynamic>.from(raw);
          final groups = _extractGroups(normalized['groups']);
          normalized['groups'] = groups;

          int? initialGroupId;
          if (groups.isNotEmpty) {
            initialGroupId = _resolveGroupId(groups.first['id']);
          }

          _student = normalized;
          _selectedGroupId = initialGroupId;
        });
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        setState(() {
          _errorMessage =
              'Failed to load student (code ${response.statusCode}).';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
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
    return TeacherLayout(title: 'Student', body: _buildBody());
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
      return const Center(child: Text('Eleve introuvable.'));
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
            const SizedBox(height: 12),
            _buildGlobalKpisRow(),
            const SizedBox(height: 12),
            _buildGroupSelectorCard(),
            const SizedBox(height: 12),
            _buildGroupKpisRow(),
            const SizedBox(height: 12),
            _buildCalendarCard(),
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: fullImageUrl != null
                  ? NetworkImage(fullImageUrl)
                  : null,
              child: fullImageUrl == null
                  ? Icon(Icons.person, size: 48, color: Colors.grey.shade600)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              fullname.isEmpty ? '--' : fullname,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (levelSection.isNotEmpty)
              Text(
                levelSection,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            Text(
              phone.isEmpty ? '--' : phone,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalKpisRow() {
    final paidAmount = _formatAmount(_student!['paid_amount']);
    final unpaidAmount = _formatAmount(_student!['unpaid_amount']);

    return Row(
      children: [
        Expanded(child: _buildKpiCard(paidAmount, 'paid', Colors.green)),
        const SizedBox(width: 10),
        Expanded(child: _buildKpiCard(unpaidAmount, 'unpaid', Colors.red)),
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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Group',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            if (dropdownItems.isEmpty)
              const Text('No group assigned to this student.')
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
          ],
        ),
      ),
    );
  }

  Widget _buildGroupKpisRow() {
    final group = _selectedGroup();
    final paidAmount = _formatAmount(
      group != null ? group['paid_amount'] : null,
    );
    final unpaidAmount = _formatAmount(
      group != null ? group['unpaid_amount'] : null,
    );
    final groupLabel = group != null ? _groupNameLabel(group) : 'Group';

    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            '$paidAmount',
            '$groupLabel - paid',
            Colors.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKpiCard(
            '$unpaidAmount',
            '$groupLabel - unpaid',
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Calendar'),
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
    Widget dot(Color c) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        Row(
          children: [
            dot(Colors.green),
            const SizedBox(width: 6),
            const Text('Attended & paid'),
          ],
        ),
        Row(
          children: [
            dot(Colors.red),
            const SizedBox(width: 6),
            const Text('Attended & unpaid (due)'),
          ],
        ),
        Row(
          children: [
            dot(Colors.orange),
            const SizedBox(width: 6),
            const Text('Attended & unpaid (not due)'),
          ],
        ),
        Row(
          children: [
            dot(Colors.grey),
            const SizedBox(width: 6),
            const Text('Scheduled class'),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
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

  String _normalizeNumericString(String input) {
    final trimmed = input.trim();
    final decimalMatch = RegExp(
      r"Decimal\('([0-9.,+-]+)'\)",
    ).firstMatch(trimmed);
    if (decimalMatch != null) {
      return decimalMatch.group(1)!.replaceAll(',', '.');
    }
    return trimmed.replaceAll(',', '.');
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
      return 'Group $id';
    }
    return 'Group';
  }

  String _groupNameLabel(Map<String, dynamic> group) {
    final nameText = _stringOrEmpty(group['name']);
    if (nameText.isNotEmpty) {
      return nameText;
    }
    final id = _resolveGroupId(group['id']);
    if (id != null) {
      return 'Group $id';
    }
    return 'Group';
  }

  String _formatAmount(dynamic raw) {
    num? value;
    if (raw is num) {
      value = raw;
    } else if (raw != null) {
      value = num.tryParse(_normalizeNumericString(raw.toString()));
    }

    if (value == null) {
      return '0';
    }

    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
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
      final dot = _bestDotForEvents(events);
      final tooltip = _tooltipForEvents(events, date);

      final dayCell = AspectRatio(
        aspectRatio: 1,
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Text(
                    '$day',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (dot != null)
                Center(
                  child: Tooltip(
                    message: tooltip,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
      final dateStr = cls['attendance_date']?.toString();
      if (dateStr == null || dateStr.isEmpty) continue;
      final date = DateTime.tryParse(dateStr) ?? _parseYMD(dateStr);
      if (date == null) continue;
      if (date.year != _focusedMonth.year || date.month != _focusedMonth.month)
        continue;

      final status = (cls['status'] ?? '').toString().toLowerCase();
      final paidAtStr = cls['paid_at']?.toString();
      DateTime? paidAt;
      if (paidAtStr != null && paidAtStr.isNotEmpty) {
        paidAt = DateTime.tryParse(paidAtStr);
      }

      final event = <String, dynamic>{
        'type': paidAt != null
            ? 'paid'
            : (status == 'present' ||
                  status == 'attended' ||
                  status == 'attendance')
            ? 'attended'
            : (status == 'absent' ? 'absent' : 'attended'),
        'status': status,
        'date': date,
        'start': cls['attendance_start_time']?.toString(),
        'end': cls['attendance_end_time']?.toString(),
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

  // Decide which color dot to show for a day
  Color? _bestDotForEvents(List<Map<String, dynamic>> events) {
    if (events.isEmpty) return null;
    // Priority: paid (green) > attended due/unpaid (red/orange) > future (gray)
    bool hasPaid = events.any((e) => e['type'] == 'paid');
    if (hasPaid) return Colors.green;

    // attended but unpaid: if date < today => red, if date == today => orange
    final now = DateTime.now();
    final attended = events
        .where((e) => e['type'] == 'attended' || e['type'] == 'absent')
        .toList();
    if (attended.isNotEmpty) {
      final date = (attended.first['date'] as DateTime);
      final today = DateTime(now.year, now.month, now.day);
      final dayOnly = DateTime(date.year, date.month, date.day);
      if (dayOnly.isBefore(today)) return Colors.red;
      if (dayOnly == today) return Colors.orange;
      return Colors.red; // default to red if future attended appears
    }

    // future placeholder
    if (events.any((e) => e['type'] == 'future')) return Colors.grey;

    return null;
  }

  String _tooltipForEvents(List<Map<String, dynamic>> events, DateTime date) {
    if (events.isEmpty) return _formatScheduled(date, null, null);

    // Prefer paid, then attended, then future
    Map<String, dynamic>? paid = events.firstWhere(
      (e) => e['type'] == 'paid',
      orElse: () => {},
    );
    if (paid.isNotEmpty) {
      final start = paid['start']?.toString();
      final end = paid['end']?.toString();
      final paidAt = paid['paidAt'] as DateTime?;
      return 'Paye\n${_formatAttended(date, start, end)}\n${_formatPaid(paidAt)}';
    }

    Map<String, dynamic>? attended = events.firstWhere(
      (e) => e['type'] == 'attended' || e['type'] == 'absent',
      orElse: () => {},
    );
    if (attended.isNotEmpty) {
      final start = attended['start']?.toString();
      final end = attended['end']?.toString();
      final status = (attended['type'] == 'absent') ? 'Absent' : 'Present';
      return '$status\n${_formatAttended(date, start, end)}';
    }

    final future = events.firstWhere(
      (e) => e['type'] == 'future',
      orElse: () => {},
    );
    if (future.isNotEmpty) {
      final start = future['start']?.toString();
      final end = future['end']?.toString();
      return 'Planifie\n${_formatScheduled(date, start, end)}';
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
    return 'Seance du ${_formatDateDMY(date)} de ${s.isEmpty ? '--:--' : s} a ${e.isEmpty ? '--:--' : e}';
  }

  String _formatPaid(DateTime? paidAt) {
    if (paidAt == null) return '';
    final d = _formatDateDMY(paidAt);
    final h = _formatTimeHM('${paidAt.hour}:${paidAt.minute}');
    return 'Paiement enregistre le $d a $h';
  }

  String _formatScheduled(DateTime date, String? start, String? end) {
    final s = _formatTimeHM(start);
    final e = _formatTimeHM(end);
    return 'Cours prevu le ${_formatDateDMY(date)} de ${s.isEmpty ? '--:--' : s} a ${e.isEmpty ? '--:--' : e}';
  }
}
