import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';

class UnattendanceResultPopup extends StatelessWidget {
  final int requestedClasses;
  final int fullyUnmarkedCount;
  final List studentsWithMissingClasses;
  final VoidCallback onClose;

  const UnattendanceResultPopup({
    super.key,
    required this.requestedClasses,
    required this.fullyUnmarkedCount,
    required this.studentsWithMissingClasses,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final maxDialogHeight = MediaQuery.of(context).size.height * 0.8;
    final students = studentsWithMissingClasses;
    final partiallyUnmarkedCount = students.length;

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : maxDialogHeight;
            final maxListHeight = availableHeight * 0.6;

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxDialogHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Résultat',
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
                        onPressed: onClose,
                      ),
                    ],
                  ),
                  const Divider(height: 5),
                  const SizedBox(height: 10.0),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHighlightsRow(
                            context,
                            requestedClasses: requestedClasses,
                            fullyUnmarkedCount: fullyUnmarkedCount,
                            partiallyUnmarkedCount: partiallyUnmarkedCount,
                          ),
                          const SizedBox(height: 10),
                          if (partiallyUnmarkedCount > 0)
                            _buildStudentsSection(
                              context,
                              students,
                              requestedClasses: requestedClasses,
                              maxListHeight: maxListHeight,
                            ),
                          if (partiallyUnmarkedCount == 0)
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Tous les étudiants sélectionnés ont été annulés pour $requestedClasses séance(s).',
                                  style: const TextStyle(
                                    fontSize: mediumFontSize,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: primaryButtonStyle,
                      onPressed: onClose,
                      child: const Text(
                        'Ok',
                        style: TextStyle(fontSize: mediumFontSize),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHighlightsRow(
    BuildContext context, {
    required int requestedClasses,
    required int fullyUnmarkedCount,
    required int partiallyUnmarkedCount,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildKpiCard(
              context,
              title: 'Étudiant(s) – complètement annulée(s)',
              value: fullyUnmarkedCount.toString(),
              icon: Icons.check_circle,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildKpiCard(
              context,
              title: 'Étudiant(s) - incomplètement annulée(s)',
              value: partiallyUnmarkedCount.toString(),
              icon: Icons.warning_amber_rounded,
              color: Colors.orangeAccent.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: color.withOpacity(0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsSection(
    BuildContext context,
    List students, {
    required int requestedClasses,
    required double maxListHeight,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Étudiants avec des séances manquantes',
              style: TextStyle(
                fontSize: headerFontSize,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(height: 20),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 15, color: Colors.black),
                children: [
                  const TextSpan(
                    text:
                        'Ces étudiants n\'avaient pas suffisamment de séances pour annuler les ',
                  ),
                  TextSpan(
                    text: '$requestedClasses',
                    style: TextStyle(
                      color: Colors.orangeAccent.shade700,
                      fontWeight: FontWeight.bold,
                    ), // 👈 highlight
                  ),
                  const TextSpan(text: ' prévues.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildScrollableStudentsList(context, students, maxListHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableStudentsList(
    BuildContext context,
    List students,
    double maxHeight,
  ) {
    final ScrollController? primaryScrollController =
        PrimaryScrollController.of(context);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is OverscrollNotification &&
            primaryScrollController != null &&
            primaryScrollController.hasClients) {
          final parentPosition = primaryScrollController.position;
          final targetOffset = (parentPosition.pixels + notification.overscroll)
              .clamp(
                parentPosition.minScrollExtent,
                parentPosition.maxScrollExtent,
              )
              .toDouble();

          if (targetOffset != parentPosition.pixels) {
            parentPosition.jumpTo(targetOffset);
            return true;
          }
        }
        return false;
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Scrollbar(
          thumbVisibility: students.length > 3,
          child: ListView.builder(
            shrinkWrap: true,
            primary: false,
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            itemCount: students.length,
            itemBuilder: (context, index) => _buildStudentCard(students[index]),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(dynamic student) {
    dynamic imageValue;
    String fullName = '';
    String missingCount = '0';

    if (student is Map) {
      imageValue = student['image'];
      final dynamic fullnameValue = student['fullname'];
      if (fullnameValue != null) {
        fullName = fullnameValue.toString();
      }
      final dynamic missingValue =
          student['missing_number_of_classes_to_unmark'];
      if (missingValue != null) {
        missingCount = missingValue.toString();
      }
    }

    final imageUrl = _resolveImageUrl(imageValue);

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(fontSize: mediumFontSize),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                      children: [
                        const TextSpan(text: 'Séances manquantes : '),
                        TextSpan(
                          text: '$missingCount',
                          style: TextStyle(
                            color: Colors.orangeAccent.shade700,
                            fontWeight: FontWeight.bold,
                          ), // 👈 your custom color here
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orangeAccent,
              size: 30,
            ),
          ],
        ),
      ),
    );
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
}
