import 'dart:collection';

import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';

class ActionResultPopup extends StatelessWidget {
  Map<String, dynamic>? successKpi;
  Map<String, dynamic>? failedKpi;
  String? failedListTitle;
  String? failedListDescription;
  List? failedList;
  final VoidCallback onClose;

  const AttendanceResultPopup({
    super.key,
    required this.successKpi,
    required this.failedKpi,
    required this.failedListTitle,
    required this.failedListDescription,
    required this.failedList,
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
                            markedLabel: studentsMarkedLabel,
                            overlapCount: normalizedOverlaps.length,
                          ),
                          const SizedBox(height: 10),
                          _buildOverlapsSection(
                            context,
                            normalizedOverlaps,
                            maxListHeight: maxListHeight,
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
    required String markedLabel,
    required int overlapCount,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildKpiCard(
              context,
              title: 'Étudiant(s) marqué(s) comme présent(s)',
              value: markedLabel,
              icon: Icons.check_circle,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildKpiCard(
              context,
              title: 'Étudiant(s) non marqués comme présent(s)',
              value: overlapCount.toString(),
              icon: Icons.warning_amber_rounded,
              color: overlapCount > 0
                  ? Colors.orangeAccent.shade700
                  : Colors.blueGrey,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
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

  Widget _buildOverlapsSection(
    BuildContext context,
    List<Map<String, dynamic>> overlaps, {
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
              'Les étudiants non marqués présents',
              style: TextStyle(
                fontSize: headerFontSize,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(height: 20),
            const Text(
              'Ces étudiants n’ont pas été marqués comme présents en raison d’un conflit d’horaire avec une autre séance.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            _buildScrollableOverlapsList(context, overlaps, maxListHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableOverlapsList(
    BuildContext context,
    List<Map<String, dynamic>> overlaps,
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
          thumbVisibility: overlaps.length > 3,
          child: ListView.builder(
            shrinkWrap: true,
            primary: false,
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            itemCount: overlaps.length,
            itemBuilder: (context, index) =>
                _buildOverlappingStudentCard(overlaps[index]),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlappingStudentCard(Map<String, dynamic> student) {
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
                fullName,
                style: const TextStyle(fontSize: mediumFontSize),
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
