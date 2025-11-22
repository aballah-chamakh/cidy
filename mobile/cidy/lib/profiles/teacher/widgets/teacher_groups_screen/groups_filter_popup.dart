import 'package:cidy/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GroupsFilterPopup extends StatefulWidget {
  final void Function(Map<String, dynamic> filters) onApplyFilter;
  final VoidCallback onResetFilter;
  final Map<String, dynamic> currentFilters;
  final Map<String, dynamic> filterOptions;

  const GroupsFilterPopup({
    super.key,
    required this.onApplyFilter,
    required this.onResetFilter,
    required this.currentFilters,
    required this.filterOptions,
  });

  @override
  State<GroupsFilterPopup> createState() => _GroupsFilterPopupState();
}

class _GroupsFilterPopupState extends State<GroupsFilterPopup> {
  // Data for dropdowns
  Map<String, dynamic> _levels = {};
  Map<String, dynamic> _sections = {};
  List<dynamic> _subjects = [];

  // Selected filter values
  String? _selectedLevelName;
  String? _selectedSectionName;
  String? _selectedSubjectName;
  String? _selectedDay;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _sortBy;

  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<Map<String, String>> _weekDays = [
    {'value': 'Monday', 'name': 'Lundi'},
    {'value': 'Tuesday', 'name': 'Mardi'},
    {'value': 'Wednesday', 'name': 'Mercredi'},
    {'value': 'Thursday', 'name': 'Jeudi'},
    {'value': 'Friday', 'name': 'Vendredi'},
    {'value': 'Saturday', 'name': 'Samedi'},
    {'value': 'Sunday', 'name': 'Dimanche'},
  ];

  final Map<String, String> _sortOptions = {
    'paid_desc': 'Montant payé (décroissant)',
    'paid_asc': 'Montant payé (croissant)',
    'unpaid_desc': 'Montant impayé (décroissant)',
    'unpaid_asc': 'Montant impayé (croissant)',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialFilters();
    _processFilterOptions();
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  void _processFilterOptions() {
    _levels = widget.filterOptions;
    // Pre-fill sections if a level is already selected
    if (_selectedLevelName != null && _levels.containsKey(_selectedLevelName)) {
      _sections = _levels[_selectedLevelName]['sections'] ?? {};
    }
    // Pre-fill subjects if a section is already selected
    if (_selectedSectionName != null &&
        _sections.containsKey(_selectedSectionName)) {
      _subjects = _sections[_selectedSectionName]['subjects'] ?? [];
    }
  }

  void _loadInitialFilters() {
    _selectedLevelName = widget.currentFilters['level'];
    _selectedSectionName = widget.currentFilters['section'];
    _selectedSubjectName = widget.currentFilters['subject'];
    _selectedDay = widget.currentFilters['day'];
    _sortBy = widget.currentFilters['sort_by'];

    // Load start_time and end_time independently (each optional)
    final String? startTimeStr = widget.currentFilters['start_time'];
    final String? endTimeStr = widget.currentFilters['end_time'];
    if (startTimeStr != null && startTimeStr.isNotEmpty) {
      _startTime = _parseTime(startTimeStr);
      _startTimeController.text = startTimeStr;
    }
    if (endTimeStr != null && endTimeStr.isNotEmpty) {
      _endTime = _parseTime(endTimeStr);
      _endTimeController.text = endTimeStr;
    }
  }

  TimeOfDay? _parseTime(String? timeString) {
    if (timeString == null) return null;
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (e) {
      // Handle parsing error
    }
    return null;
  }

  void _applyFilters() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final filters = {
        'level': _selectedLevelName,
        'section': _selectedSectionName,
        'subject': _selectedSubjectName,
        'day': _selectedDay,
        'sort_by': _sortBy,
        // send independent times; each can be set alone
        'start_time': _startTime != null
            ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
            : null,
        'end_time': _endTime != null
            ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
            : null,
      };
      widget.onApplyFilter(filters);
    }
  }

  void _resetFilters() {
    widget.onResetFilter();
  }

  int _countActiveFilters() {
    int count = 0;
    if (_selectedLevelName != null) count++;
    if (_selectedSectionName != null) count++;
    if (_selectedSubjectName != null) count++;
    if (_selectedDay != null) count++;
    if (_startTime != null || _endTime != null) count++;
    if (_sortBy != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(key: _formKey, child: _buildForm()),
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
            Text(
              'Filtre',
              style: TextStyle(
                fontSize: headerFontSize,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                size: headerIconSize,
                color: primaryColor,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const Divider(),
        const SizedBox(height: 16),

        // Form Content
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _applyFilters,
            style: primaryButtonStyle,
            child: Text(
              'Filtrer (${_countActiveFilters()})',
              style: TextStyle(fontSize: mediumFontSize),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _resetFilters,
            style: secondaryButtonStyle,
            child: const Text(
              'Réinitialiser',
              style: TextStyle(fontSize: mediumFontSize, color: primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedLevelName,
      style: TextStyle(fontSize: mediumFontSize, color: Colors.black),
      decoration: InputDecoration(
        labelText: 'Niveau',
        labelStyle: TextStyle(color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorMaxLines: 3,
        contentPadding: inputContentPadding,
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text(
            'Tous les niveaux',
            style: TextStyle(fontSize: mediumFontSize),
          ),
        ),
        ..._levels.keys.map(
          (levelName) => DropdownMenuItem<String>(
            value: levelName,
            child: Text(levelName, style: TextStyle(fontSize: mediumFontSize)),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedLevelName = value;
          _selectedSectionName = null;
          _selectedSubjectName = null;
          if (value != null) {
            _sections = _levels[value]['sections'] ?? {};
          } else {
            _sections = {};
          }
          _subjects = [];
        });
      },
    );
  }

  Widget _buildSectionDropdown() {
    final bool isEnabled = _sections.isNotEmpty;

    return DropdownButtonFormField<String>(
      initialValue: _selectedSectionName,
      style: TextStyle(fontSize: mediumFontSize, color: Colors.black),
      decoration: InputDecoration(
        labelText: 'Section',
        labelStyle: TextStyle(color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorMaxLines: 3,
        contentPadding: inputContentPadding,
        filled: !isEnabled,
        fillColor: Colors.grey[200],
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text(
            'Toutes les sections',
            style: TextStyle(fontSize: mediumFontSize),
          ),
        ),
        ..._sections.keys.map(
          (sectionName) => DropdownMenuItem<String>(
            value: sectionName,
            child: Text(
              sectionName,
              style: TextStyle(fontSize: mediumFontSize),
            ),
          ),
        ),
      ],
      onChanged: isEnabled
          ? (value) {
              setState(() {
                _selectedSectionName = value;
                _selectedSubjectName = null;
                if (value != null) {
                  _subjects = _sections[value]['subjects'] ?? [];
                } else {
                  _subjects = [];
                }
              });
            }
          : null,
    );
  }

  Widget _buildSubjectDropdown() {
    bool isEnabled = false;
    List<dynamic> currentSubjects = [];

    if (_selectedLevelName != null) {
      final levelData = _levels[_selectedLevelName];
      if (levelData != null) {
        // If sections exist for the level
        if (levelData['sections'] != null && levelData['sections'].isNotEmpty) {
          // A section must be selected
          if (_selectedSectionName != null) {
            final sectionData = levelData['sections'][_selectedSectionName];
            if (sectionData != null && sectionData['subjects'] != null) {
              currentSubjects = sectionData['subjects'];
              isEnabled = currentSubjects.isNotEmpty;
            }
          }
        }
        // If no sections exist, check for subjects directly under the level
        else if (levelData['subjects'] != null) {
          currentSubjects = levelData['subjects'];
          isEnabled = currentSubjects.isNotEmpty;
        }
      }
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedSubjectName,
      style: TextStyle(fontSize: mediumFontSize, color: Colors.black),
      decoration: InputDecoration(
        labelText: 'Matière',
        labelStyle: TextStyle(color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorMaxLines: 3,
        contentPadding: inputContentPadding,
        filled: !isEnabled,
        fillColor: Colors.grey[200],
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text(
            'Toutes les matières',
            style: TextStyle(fontSize: mediumFontSize),
          ),
        ),
        ...currentSubjects.map(
          (subjectName) => DropdownMenuItem<String>(
            value: subjectName,
            child: Text(
              subjectName,
              style: TextStyle(fontSize: mediumFontSize),
            ),
          ),
        ),
      ],
      onChanged: isEnabled
          ? (value) {
              setState(() {
                _selectedSubjectName = value;
              });
            }
          : null,
    );
  }

  Widget _buildDayDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedDay,
      style: TextStyle(fontSize: mediumFontSize, color: Colors.black),
      decoration: InputDecoration(
        labelText: 'Jour de la semaine',
        labelStyle: TextStyle(color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorMaxLines: 3,
        contentPadding: inputContentPadding,
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text(
            'Tous les jours',
            style: TextStyle(fontSize: mediumFontSize),
          ),
        ),
        ..._weekDays.map(
          (day) => DropdownMenuItem<String>(
            value: day['value'],
            child: Text(
              day['name']!,
              style: TextStyle(fontSize: mediumFontSize),
            ),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedDay = value;
        });
      },
    );
  }

  Widget _buildTimeRangeSelector() {
    final bool isEnabled =
        true; // Always enable time filters, even for 'Tous les jours'
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _startTimeController,
            style: TextStyle(fontSize: mediumFontSize, color: Colors.black),
            decoration: InputDecoration(
              labelText: 'Heure de début',
              labelStyle: TextStyle(color: primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(inputBorderRadius),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(inputBorderRadius),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              errorMaxLines: 3,
              contentPadding: inputContentPadding,
              filled: !isEnabled,
              fillColor: Colors.grey[200],
              hintText: 'HH:MM',
            ),
            enabled: isEnabled,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
              _TimeTextInputFormatter(),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Requis';
              }
              final time = _parseTime(value);
              final endTime = _parseTime(_endTimeController.text);
              if (time == null) return 'Format invalide';
              if (time.hour < 8) return 'Min 08:00';
              if (endTime != null &&
                  (time.hour > endTime.hour ||
                      (time.hour == endTime.hour &&
                          time.minute > endTime.minute))) {
                return 'Début > Fin';
              }
              if (endTime != null &&
                  time.hour == endTime.hour &&
                  time.minute == endTime.minute) {
                return 'Début == Fin';
              }
              return null;
            },
            onSaved: (value) {
              if (value != null && value.isNotEmpty) {
                _startTime = _parseTime(value);
              } else {
                _startTime = null;
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _endTimeController,
            style: TextStyle(fontSize: mediumFontSize, color: Colors.black),
            decoration: InputDecoration(
              labelText: 'Heure de fin',
              labelStyle: TextStyle(color: primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(inputBorderRadius),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(inputBorderRadius),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              errorMaxLines: 3,
              contentPadding: inputContentPadding,
              filled: !isEnabled,
              fillColor: Colors.grey[200],
              hintText: 'HH:MM',
            ),
            enabled: isEnabled,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
              _TimeTextInputFormatter(),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Requis';
              }
              final time = _parseTime(value);
              final startTime = _parseTime(_startTimeController.text);
              if (time == null) return 'Format invalide';
              if (time.hour == 0 && time.minute > 0) return 'Max 00:00';
              if (startTime != null &&
                  (time.hour < startTime.hour ||
                      (time.hour == startTime.hour &&
                          time.minute < startTime.minute))) {
                return 'Fin < Début';
              }
              if (startTime != null &&
                  time.hour == startTime!.hour &&
                  time.minute == startTime.minute) {
                return 'Début == Fin';
              }
              return null;
            },
            onSaved: (value) {
              if (value != null && value.isNotEmpty) {
                _endTime = _parseTime(value);
              } else {
                _endTime = null;
              }
            },
          ),
        ),
        if (_startTimeController.text.isNotEmpty ||
            _endTimeController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _startTime = null;
                _endTime = null;
                _startTimeController.clear();
                _endTimeController.clear();
              });
            },
          ),
      ],
    );
  }

  Widget _buildSortByDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _sortBy,
      style: TextStyle(fontSize: mediumFontSize, color: Colors.black),
      decoration: InputDecoration(
        labelText: 'Trier par',
        labelStyle: TextStyle(color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorMaxLines: 3,
        contentPadding: inputContentPadding,
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Défaut', style: TextStyle(fontSize: mediumFontSize)),
        ),
        ..._sortOptions.entries.map(
          (entry) => DropdownMenuItem<String>(
            value: entry.key,
            child: Text(
              entry.value,
              style: TextStyle(fontSize: mediumFontSize),
            ),
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

class _TimeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;
    if (newText.length > 5) {
      return oldValue;
    }

    String text = newText.replaceAll(':', '');

    if (text.length == 2) {
      final hour = int.tryParse(text);
      if (hour != null && hour > 23) {
        if (oldValue.text.length == 1 && int.tryParse(oldValue.text) != null) {
          final firstDigit = oldValue.text;
          final secondDigit = text.substring(1);
          text = '0$firstDigit:$secondDigit';

          final minuteDigit = int.tryParse(secondDigit);
          if (minuteDigit != null && minuteDigit > 5) {
            text = '0$firstDigit:0$secondDigit';
          }

          return TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      }
    }

    if (text.length > 2) {
      text = '${text.substring(0, 2)}:${text.substring(2)}';
    }

    // Validate hour and minute
    if (text.contains(':')) {
      final parts = text.split(':');
      final hour = int.tryParse(parts[0]);

      if (parts.length > 1 &&
          parts[1].length == 1 &&
          newValue.text.length > oldValue.text.length) {
        final m = int.tryParse(parts[1]);
        if (m != null && m > 5) {
          text = '${parts[0]}:0$m';
          return TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      }

      final minute = int.tryParse(parts[1]);

      if (hour != null && hour > 23) {
        return oldValue;
      }
      if (minute != null && minute > 59) {
        return oldValue;
      }
    } else if (text.length == 2) {
      final hour = int.tryParse(text);
      if (hour != null && hour > 23) {
        return oldValue;
      }
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
