import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';

class AttendanceResultPopup extends StatelessWidget {
  final int studentsMarkedCount;
  final List overlappingStudents;
  final VoidCallback onClose;

  const AttendanceResultPopup({
    super.key,
    required this.studentsMarkedCount,
    required this.overlappingStudents,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final maxDialogHeight = MediaQuery.of(context).size.height * 0.8;

    final normalizedOverlaps = overlappingStudents
        .whereType<Map>()
        .map(
          (student) =>
              student.map((key, value) => MapEntry(key.toString(), value)),
        )
        .cast<Map<String, dynamic>>()
        .toList();

    final hasOverlaps = normalizedOverlaps.isNotEmpty;
    final studentsMarkedLabel = studentsMarkedCount.toString();

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
      child: Container(
        padding: const EdgeInsets.all(popupPadding),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(popupBorderRadius),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxDialogHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: primaryColor),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Résultat',
                        style: TextStyle(
                          fontSize: headerFontSize,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: headerIconSize,
                        color: primaryColor,
                      ),
                      onPressed: onClose,
                      tooltip: 'Fermer',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ResultHighlights(
                        studentsMarkedLabel: studentsMarkedLabel,
                        overlappingCount: normalizedOverlaps.length,
                      ),
                      const SizedBox(height: 20),
                      if (hasOverlaps) ...[
                        const Text(
                          'Étudiants avec chevauchement',
                          style: TextStyle(
                            fontSize: mediumFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...normalizedOverlaps.map(
                          (student) =>
                              _OverlappingStudentCard(student: student),
                        ),
                      ] else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceVariant.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.done_all, color: primaryColor),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Aucun chevauchement détecté.',
                                  style: TextStyle(fontSize: mediumFontSize),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: primaryButtonStyle,
                onPressed: onClose,
                child: const Text(
                  'Ok',
                  style: TextStyle(fontSize: mediumFontSize),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlappingStudentCard extends StatelessWidget {
  final Map<String, dynamic> student;

  const _OverlappingStudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl(student['image']);
    final fullName = (student['fullname'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundImage: NetworkImage(imageUrl),
              onBackgroundImageError: (_, __) {},
              backgroundColor: Colors.grey.shade300,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fullName.isEmpty ? 'Nom indisponible' : fullName,
                style: const TextStyle(fontSize: mediumFontSize),
              ),
            ),
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
          ],
        ),
      ),
    );
  }
}

class _ResultHighlights extends StatelessWidget {
  final String studentsMarkedLabel;
  final int overlappingCount;

  const _ResultHighlights({
    required this.studentsMarkedLabel,
    required this.overlappingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HighlightCard(
            title: 'Présences marquées',
            value: studentsMarkedLabel,
            icon: Icons.check_circle,
            color: Colors.green.shade600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HighlightCard(
            title: 'Chevauchements',
            value: overlappingCount.toString(),
            icon: Icons.warning_amber_rounded,
            color: overlappingCount > 0
                ? Colors.orangeAccent.shade700
                : Colors.blueGrey,
          ),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _HighlightCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: mediumFontSize,
              color: color.withOpacity(0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _resolveImageUrl(dynamic imageValue) {
  if (imageValue == null) {
    return '${Config.backendUrl}/media/defaults/student.png';
  }

  final imagePath = imageValue.toString();
  if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
    return imagePath;
  }
  if (imagePath.startsWith('/')) {
    return '${Config.backendUrl}$imagePath';
  }
  return '${Config.backendUrl}/$imagePath';
}
