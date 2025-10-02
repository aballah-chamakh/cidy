import 'package:flutter/material.dart';

class StudentFilterForm extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  final Function(Map<String, dynamic>) onApplyFilter;
  final VoidCallback onResetFilter;

  const StudentFilterForm({
    super.key,
    required this.currentFilters,
    required this.onApplyFilter,
    required this.onResetFilter,
  });

  @override
  State<StudentFilterForm> createState() => _StudentFilterFormState();
}

class _StudentFilterFormState extends State<StudentFilterForm> {
  late TextEditingController _nameController;
  String? _sortBy;
  String? _paymentStatus;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentFilters['name'],
    );
    _sortBy = widget.currentFilters['sort_by'];
    _paymentStatus = widget.currentFilters['payment_status'];
  }

  void _applyFilters() {
    final filters = {
      'name': _nameController.text,
      'sort_by': _sortBy,
      'payment_status': _paymentStatus,
    };
    widget.onApplyFilter(filters);
  }

  void _resetFilters() {
    setState(() {
      _nameController.clear();
      _sortBy = null;
      _paymentStatus = null;
    });
    widget.onResetFilter();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Filter Students',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Student Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _sortBy,
            decoration: const InputDecoration(
              labelText: 'Sort By',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'full_name', child: Text('Name (A-Z)')),
              DropdownMenuItem(value: '-full_name', child: Text('Name (Z-A)')),
              DropdownMenuItem(
                value: 'paid_amount',
                child: Text('Paid (Low to High)'),
              ),
              DropdownMenuItem(
                value: '-paid_amount',
                child: Text('Paid (High to Low)'),
              ),
              DropdownMenuItem(
                value: 'unpaid_amount',
                child: Text('Unpaid (Low to High)'),
              ),
              DropdownMenuItem(
                value: '-unpaid_amount',
                child: Text('Unpaid (High to Low)'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _sortBy = value;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _paymentStatus,
            decoration: const InputDecoration(
              labelText: 'Payment Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'paid', child: Text('Paid')),
              DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
              DropdownMenuItem(
                value: 'partially_paid',
                child: Text('Partially Paid'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _paymentStatus = value;
              });
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: _resetFilters, child: const Text('Reset')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _applyFilters,
                child: const Text('Apply Filters'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
