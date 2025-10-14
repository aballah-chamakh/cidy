import 'package:flutter/material.dart';
import 'package:cidy/app_styles.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_group_detail_screen/add_existing_student_form.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_group_detail_screen/create_new_student_form.dart';

class AddStudentPopup extends StatefulWidget {
  final int groupId;
  final Function onStudentsAdded;
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
        onServerError: widget.onServerError,
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
      insetPadding: const EdgeInsets.symmetric(
        horizontal: popupHorizontalMargin,
        vertical: 0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(popupBorderRadius),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Container(
          padding: const EdgeInsets.all(popupPadding),
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
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(child: _buildContent()),
              ),
              const Divider(height: 30),
              _buildFooter(),
            ],
          ),
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
            fontSize: headerFontSize,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.close,
            weight: 2.0,
            color: primaryColor,
            size: headerIconSize,
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
        Icon(Icons.person_add, size: 100.0, color: primaryColor),
        const SizedBox(height: 16.0),
        // Label
        Text(
          'Choisissez entre ajouter des élèves existants ou créer un nouvel élève puis l\'ajouter',
          style: TextStyle(fontSize: mediumFontSize, color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10.0),
        // Select input with options
        DropdownButtonFormField<String>(
          value: _selectedOption,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(inputBorderRadius),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(inputBorderRadius),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            contentPadding: inputContentPadding,
          ),
          hint: const Text(
            'Sélectionnez une option',
            style: TextStyle(fontSize: mediumFontSize),
          ),
          items: const [
            DropdownMenuItem(
              value: 'existing',
              child: Text(
                'ajouter des élèves existants',
                style: TextStyle(fontSize: mediumFontSize),
              ),
            ),
            DropdownMenuItem(
              value: 'new',
              child: Text(
                'créer un nouvel élève puis l\'ajouter',
                style: TextStyle(fontSize: mediumFontSize),
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
    return Row(
      children: [
        Expanded(
          child: TextButton(
            style: secondaryButtonStyle,
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text(
              'Annuler',
              style: TextStyle(fontSize: mediumFontSize),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: ElevatedButton(
            style: primaryButtonStyle,
            onPressed: _selectedOption != null ? _handleNext : null,
            child: const Text(
              'Suivant',
              style: TextStyle(fontSize: mediumFontSize),
            ),
          ),
        ),
      ],
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
