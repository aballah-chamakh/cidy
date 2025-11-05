import 'package:cidy/app_styles.dart';
import 'package:cidy/app_styles.dart';
import 'package:flutter/material.dart';

class KpiCard extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const KpiCard({
    super.key,
    required this.value,
    required this.label,
    this.valueColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(label, style: AppStyles.body, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
