import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomSnackBar {
  static void show({
    required BuildContext context,
    required String message,
    SnackBarType type = SnackBarType.info,
  }) {
    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: type.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(type.icon, color: type.iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.title,
                    style: GoogleFonts.poppins(
                      color: type.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: GoogleFonts.poppins(
                        color: type.textColor.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      duration: const Duration(seconds: 4),
    );

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}

enum SnackBarType {
  success(
    title: 'Success',
    backgroundColor: Color(0xFF4CAF50),
    icon: Icons.check_circle_outlined,
    textColor: Colors.white,
    iconColor: Colors.white,
  ),
  error(
    title: 'Error',
    backgroundColor: Color(0xFFEF5350),
    icon: Icons.error_outline,
    textColor: Colors.white,
    iconColor: Colors.white,
  ),
  warning(
    title: 'Warning',
    backgroundColor: Color(0xFFFFA726),
    icon: Icons.warning_amber_outlined,
    textColor: Colors.white,
    iconColor: Colors.white,
  ),
  info(
    title: 'Info',
    backgroundColor: Color(0xFF42A5F5),
    icon: Icons.info_outline,
    textColor: Colors.white,
    iconColor: Colors.white,
  ),
  loading(
    title: 'Loading',
    backgroundColor: Color(0xFF616161),
    icon: Icons.hourglass_empty,
    textColor: Colors.white,
    iconColor: Colors.white,
  );

  const SnackBarType({
    required this.title,
    required this.backgroundColor,
    required this.icon,
    required this.textColor,
    required this.iconColor,
  });

  final String title;
  final Color backgroundColor;
  final IconData icon;
  final Color textColor;
  final Color iconColor;
}
