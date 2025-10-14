String formatToK(String value) {
  final num? number = num.tryParse(value);
  if (number == null) return value; // return original if not a valid number

  if (number >= 1000) {
    String formatted = (number / 1000).toStringAsFixed(4); // 1 decimal place
    formatted = formatted.replaceFirst(RegExp(r'\.?0+$'), '');

    return '${formatted} K';
  }

  return number.toString();
}
