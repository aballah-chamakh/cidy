import 'package:cidy/app_styles.dart';
import 'package:flutter/material.dart';

class StudentsFilterPopup extends StatefulWidget {
  final void Function(Map<String, dynamic> filters) onApplyFilter;
  final VoidCallback onResetFilter;
  final Map<String, dynamic> currentFilters;
  final Map<String, dynamic> filterOptions;

  const StudentsFilterPopup({
    super.key,
    required this.onApplyFilter,
    required this.onResetFilter,
    required this.currentFilters,
    required this.filterOptions,
  });

  @override
  State<StudentsFilterPopup> createState() => _StudentsFilterPopupState();
}

class _StudentsFilterPopupState extends State<StudentsFilterPopup> {
  // Data for dropdowns
  Map<String, dynamic> _levels = {};
  Map<String, dynamic> _sections = {};

  // Selected filter values
  String? _selectedLevelName;
  String? _selectedSectionName;
  String? _sortBy;

  final _formKey = GlobalKey<FormState>();

  final Map<String, String> _sortOptions = {
    'paid_amount_desc': 'Montant payé (décroissant)',
    'paid_amount_asc': 'Montant payé (croissant)',
    'unpaid_amount_desc': 'Montant impayé (décroissant)',
    'unpaid_amount_asc': 'Montant impayé (croissant)',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialFilters();
    _processFilterOptions();
  }

  void _processFilterOptions() {
    _levels = widget.filterOptions;
    // Pre-fill sections if a level is already selected
    if (_selectedLevelName != null && _levels.containsKey(_selectedLevelName)) {
      _sections = _levels[_selectedLevelName]['sections'] ?? {};
    }
  }

  void _loadInitialFilters() {
    _selectedLevelName = widget.currentFilters['level'];
    _selectedSectionName = widget.currentFilters['section'];
    _sortBy = widget.currentFilters['sort_by'];
  }

  void _applyFilters() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final filters = {
        'level': _selectedLevelName,
        'section': _selectedSectionName,
        'sort_by': _sortBy,
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
            const Text(
              'Filtrer',
              style: TextStyle(
                fontSize: headerFontSize,
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(
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
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLevelDropdown(),
                const SizedBox(height: 16),
                _buildSectionDropdown(),
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
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
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
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: BorderSide(color: primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12.0),
            ),
            child: const Text(
              'Réinitialiser',
              style: TextStyle(fontSize: mediumFontSize),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedLevelName,
      style:
          Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16) ??
          const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Niveau',
        labelStyle: TextStyle(color: primaryColor),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor),
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Tous les niveaux', style: TextStyle(fontSize: 16)),
        ),
        ..._levels.keys.map(
          (levelName) => DropdownMenuItem<String>(
            value: levelName,
            child: Text(levelName, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedLevelName = value;
          _selectedSectionName = null;
          _sections = (value != null && _levels.containsKey(value))
              ? _levels[value]['sections'] ?? {}
              : {};
        });
      },
    );
  }

  Widget _buildSectionDropdown() {
    final bool isEnabled = _sections.isNotEmpty;

    return DropdownButtonFormField<String>(
      value: _selectedSectionName,
      style:
          Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16) ??
          const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Section',
        labelStyle: TextStyle(color: primaryColor),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor),
          borderRadius: BorderRadius.circular(8.0),
        ),
        filled: !isEnabled,
        fillColor: Colors.grey[200],
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Toutes les sections', style: TextStyle(fontSize: 16)),
        ),
        ..._sections.keys.map(
          (sectionName) => DropdownMenuItem<String>(
            value: sectionName,
            child: Text(sectionName, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
      onChanged: isEnabled
          ? (value) {
              setState(() {
                _selectedSectionName = value;
              });
            }
          : null,
    );
  }

  Widget _buildSortByDropdown() {
    return DropdownButtonFormField<String>(
      value: _sortBy,
      style:
          Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16) ??
          const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Trier par',
        labelStyle: TextStyle(color: primaryColor),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor),
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Défaut', style: TextStyle(fontSize: 16)),
        ),
        ..._sortOptions.entries.map(
          (entry) => DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value, style: const TextStyle(fontSize: 16)),
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
