import 'package:flutter/material.dart';
import 'package:cidy/profiles/teacher/widgets/add_student_popup/add_existing_student_form.dart';
import 'package:cidy/profiles/teacher/widgets/add_student_popup/create_new_student_form.dart';

class AddStudentPopup extends StatefulWidget {
  final int groupId;
  final VoidCallback onStudentsAdded;
  final VoidCallback onServerError;

  const AddStudentPopup({
    super.key,
    required this.groupId,
    required this.onStudentsAdded,
    required this.onServerError,
  });

  @override
  State<AddStudentPopup> createState() => _AddStudentPopupState();
}

class _AddStudentPopupState extends State<AddStudentPopup> {
  String? _selectedOption;
  bool _showNextForm = false;

  @override
  Widget build(BuildContext context) {
    // If next button was clicked and an option is selected, show the respective form
    if (_showNextForm && _selectedOption == 'existing') {
      return AddExistingStudentForm(
        groupId: widget.groupId,
        onStudentsAdded: widget.onStudentsAdded,
        onBack: () => setState(() {
          _showNextForm = false;
          _selectedOption = null;
        }),
      );
    }

    if (_showNextForm && _selectedOption == 'new') {
      return CreateNewStudentForm(
        groupId: widget.groupId,
        onStudentAdded: widget.onStudentsAdded,
        onServerError: widget.onServerError,
        onBack: () => setState(() {
          _showNextForm = false;
          _selectedOption = null;
        }),
      );
    }

    // Show initial selection dialog
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            const Divider(height: 16),
            _buildContent(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Ajouter des élèves',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.close,
            weight: 2.0,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        const SizedBox(height: 16.0),
        // Add student icon
        Icon(
          Icons.person_add,
          size: 100.0,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 16.0),
        // Label
        Text(
          'Choisissez entre ajouter des élèves existants ou créer un nouvel élève puis l\'ajouter',
          style: TextStyle(fontSize: 16.0, color: Colors.grey[700]),
          textAlign: TextAlign.left,
        ),
        const SizedBox(height: 10.0),
        // Select input with options
        DropdownButtonFormField<String>(
          value: _selectedOption,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
          ),
          hint: const Text(
            'Sélectionnez une option',
            style: TextStyle(fontSize: 16.0),
          ),
          items: const [
            DropdownMenuItem(
              value: 'existing',
              child: Text(
                'ajouter des élèves existants',
                style: TextStyle(fontSize: 16.0),
              ),
            ),
            DropdownMenuItem(
              value: 'new',
              child: Text(
                'créer un nouvel élève puis l\'ajouter',
                style: TextStyle(fontSize: 16.0),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedOption = value;
            });
          },
          validator: (value) {
            if (value == null) {
              return 'Veuillez sélectionner une option';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(
                side: BorderSide(color: Theme.of(context).primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler', style: TextStyle(fontSize: 16.0)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: _selectedOption != null ? _handleNext : null,
              child: const Text('Suivant', style: TextStyle(fontSize: 16.0)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNext() {
    if (_selectedOption == 'existing' || _selectedOption == 'new') {
      // TODO: Check if teacher has students in the same level/section
      // Set the flag to show the next form
      setState(() {
        _showNextForm = true;
      });
    }
  }
}
