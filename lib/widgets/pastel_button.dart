import 'package:flutter/material.dart';

class PastelButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const PastelButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFA3E4A6),
          foregroundColor: const Color(0xFF114432),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ).merge(
          ButtonStyle(
            shadowColor: MaterialStateProperty.all(
              Colors.black.withOpacity(0.18),
            ),
            elevation: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.pressed)) return 2;
              return 6;
            }),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
