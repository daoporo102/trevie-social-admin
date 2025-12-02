
import 'package:flutter/material.dart';
import 'package:social_media_admin/utils/colors.dart';

class CustomInkwell extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool isLoading;
  final Color backgroundColor;
  final Color textColor;
  final double height;
  final BorderRadiusGeometry borderRadius;

  const CustomInkwell({super.key, required this.title, required this.onTap, this.isLoading = false, this.backgroundColor = appPrimaryColor, this.textColor = onPrimaryColor, this.borderRadius = const BorderRadius.all(Radius.circular(4)), this.height=48.0});


  @override
  Widget build(BuildContext context) {
    final bool enabled = !isLoading;
    return Opacity(
      opacity: enabled ? 1.0 : 0.8,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child:  Ink(
          width: double.infinity,
          height: height,
          decoration: ShapeDecoration(
            color: backgroundColor,
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: onPrimaryColor,
                    ),
                  )
                : Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}