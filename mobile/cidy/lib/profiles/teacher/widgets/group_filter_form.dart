import 'dart:convert';
import 'package:cidy/config.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class GroupFilterForm extends StatefulWidget {
  final void Function(Map<String, dynamic> filters) onApplyFilter;
  final VoidCallback onResetFilter;
  final Map<String, dynamic> currentFilters;

  const GroupFilterForm({
    super.key,
    required this.onApplyFilter,
    required this.onResetFilter,
    required this.currentFilters,
  });

  @override
  State<GroupFilterForm> createState() => _GroupFilterFormState();
}

class _GroupFilterFormState extends State<GroupFilterForm> {
  bool _isLoading = true;
  String? _errorMessage;

  // Data for dropdowns
  List _levels = [];
  List _sections = [];
  List _subjects = [];

  // Selected filter values
  int? _selectedLevelId;
  int? _selectedSectionId;
  int? _selectedSubjectId;
  String? _selectedDay;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _sortBy;

  final List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final Map<String, String> _sortOptions = {
    'paid_desc': 'Paid Amount (High to Low)',
    'paid_asc': 'Paid Amount (Low to High)',
    'unpaid_desc': 'Unpaid Amount (High to Low)',
    'unpaid_asc': 'Unpaid Amount (Low to High)',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialFilters();
    _fetchDependencies();
  }

  void _loadInitialFilters() {
    _selectedLevelId = widget.currentFilters['level'];
    _selectedSectionId = widget.currentFilters['section'];
    _selectedSubjectId = widget.currentFilters['subject'];
    _selectedDay = widget.currentFilters['day'];
    _sortBy = widget.currentFilters['sort_by'];
    // Note: Time range parsing from string would be needed if persisted
  }

  Future<void> _fetchDependencies() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        throw Exception('Authentication token not found.');
      }
      final headers = {'Authorization': 'Bearer $token'};

      // Fetch in parallel
      final responses = await Future.wait([
        http.get(
          Uri.parse('${Config.backendUrl}/api/common/teacher-levels/'),
          headers: headers,
        ),
        http.get(
          Uri.parse('${Config.backendUrl}/api/common/teacher-sections/'),
          headers: headers,
        ),
        http.get(
          Uri.parse('${Config.backendUrl}/api/common/teacher-subjects/'),
          headers: headers,
        ),
      ]);

      if (responses.any((res) => res.statusCode != 200)) {
        throw Exception('Failed to load filter dependencies.');
      }

      if (mounted) {
        setState(() {
          final levelsData = json.decode(responses[0].body) as List;
          _levels = levelsData;

          final sectionsData = json.decode(responses[1].body) as List;
          _sections = sectionsData;

          final subjectsData = json.decode(responses[2].body) as List;
          _subjects = subjectsData;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final filters = {
      'level': _selectedLevelId,
      'section': _selectedSectionId,
      'subject': _selectedSubjectId,
      'day': _selectedDay,
      'sort_by': _sortBy,
      'time_range': _startTime != null && _endTime != null
          ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}-${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
          : null,
    };
    widget.onApplyFilter(filters);
  }

  void _resetFilters() {
    widget.onResetFilter();
  }

  int _countActiveFilters() {
    int count = 0;
    if (_selectedLevelId != null) count++;
    if (_selectedSectionId != null) count++;
    if (_selectedSubjectId != null) count++;
    if (_selectedDay != null) count++;
    if (_startTime != null || _endTime != null) count++;
    if (_sortBy != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Filter',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const Divider(),
        const SizedBox(height: 16),

        // Form Content
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildLevelDropdown(),
                const SizedBox(height: 16),
                _buildSectionDropdown(),
                const SizedBox(height: 16),
                _buildSubjectDropdown(),
                const SizedBox(height: 16),
                _buildDayDropdown(),
                const SizedBox(height: 16),
                _buildTimeRangeSelector(),
                const SizedBox(height: 16),
                _buildSortByDropdown(),
              ],
            ),
          ),
        ),

        // Footer
        const SizedBox(height: 16),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _resetFilters,
              child: Text('Reset (${_countActiveFilters()})'),
            ),
            ElevatedButton(
              onPressed: _applyFilters,
              child: const Text('Filter'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLevelDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedLevelId,
      decoration: const InputDecoration(
        labelText: 'Level',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('Any Level')),
        ..._levels.map(
          (level) =>
              DropdownMenuItem<int>(value: level.id, child: Text(level.name)),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedLevelId = value;
          _selectedSectionId = null;
          _selectedSubjectId = null;
        });
      },
    );
  }

  Widget _buildSectionDropdown() {
    final filteredSections = _selectedLevelId == null
        ? []
        : _sections.where((s) => s.level == _selectedLevelId).toList();
    final bool isEnabled = filteredSections.isNotEmpty;

    return DropdownButtonFormField<int>(
      value: _selectedSectionId,
      decoration: InputDecoration(
        labelText: 'Section',
        border: const OutlineInputBorder(),
        filled: !isEnabled,
        fillColor: Colors.grey[200],
      ),
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('Any Section')),
        ...filteredSections.map(
          (section) => DropdownMenuItem<int>(
            value: section.id,
            child: Text(section.name),
          ),
        ),
      ],
      onChanged: isEnabled
          ? (value) {
              setState(() {
                _selectedSectionId = value;
                _selectedSubjectId = null;
              });
            }
          : null,
    );
  }

  Widget _buildSubjectDropdown() {
    List filteredSubjects = [];
    bool isEnabled = false;

    if (_selectedLevelId != null) {
      final levelHasSections = _sections.any(
        (s) => s.level == _selectedLevelId,
      );
      if (levelHasSections) {
        if (_selectedSectionId != null) {
          filteredSubjects = _subjects
              .where((s) => s.section == _selectedSectionId)
              .toList();
          isEnabled = filteredSubjects.isNotEmpty;
        }
      } else {
        filteredSubjects = _subjects
            .where((s) => s.level == _selectedLevelId && s.section == null)
            .toList();
        isEnabled = filteredSubjects.isNotEmpty;
      }
    }

    return DropdownButtonFormField<int>(
      value: _selectedSubjectId,
      decoration: InputDecoration(
        labelText: 'Subject',
        border: const OutlineInputBorder(),
        filled: !isEnabled,
        fillColor: Colors.grey[200],
      ),
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('Any Subject')),
        ...filteredSubjects.map(
          (subject) => DropdownMenuItem<int>(
            value: subject.id,
            child: Text(subject.name),
          ),
        ),
      ],
      onChanged: isEnabled
          ? (value) {
              setState(() {
                _selectedSubjectId = value;
              });
            }
          : null,
    );
  }

  Widget _buildDayDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedDay,
      decoration: const InputDecoration(
        labelText: 'Week Day',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Any Day')),
        ..._weekDays.map(
          (day) => DropdownMenuItem<String>(value: day, child: Text(day)),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedDay = value;
          if (value == null) {
            _startTime = null;
            _endTime = null;
          }
        });
      },
    );
  }

  Widget _buildTimeRangeSelector() {
    final bool isEnabled = _selectedDay != null;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: !isEnabled
                ? null
                : () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _startTime ?? TimeOfDay.now(),
                    );
                    if (time != null) setState(() => _startTime = time);
                  },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Start Time',
                border: const OutlineInputBorder(),
                filled: !isEnabled,
                fillColor: Colors.grey[200],
              ),
              child: Text(_startTime?.format(context) ?? 'Not set'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: !isEnabled
                ? null
                : () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _endTime ?? TimeOfDay.now(),
                    );
                    if (time != null) setState(() => _endTime = time);
                  },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'End Time',
                border: const OutlineInputBorder(),
                filled: !isEnabled,
                fillColor: Colors.grey[200],
              ),
              child: Text(_endTime?.format(context) ?? 'Not set'),
            ),
          ),
        ),
        if (_startTime != null || _endTime != null)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _startTime = null;
                _endTime = null;
              });
            },
          ),
      ],
    );
  }

  Widget _buildSortByDropdown() {
    return DropdownButtonFormField<String>(
      value: _sortBy,
      decoration: const InputDecoration(
        labelText: 'Sort By',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Default')),
        ..._sortOptions.entries.map(
          (entry) => DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _sortBy = value;
        });
      },
    );
  }
}
