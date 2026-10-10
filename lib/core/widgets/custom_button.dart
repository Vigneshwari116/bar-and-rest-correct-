import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final double width;
  final double height;
  final FontWeight fontWeight;
  final double fontSize;
  final double? borderRadius;
  final bool isLoading;

  const CustomButton({super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor = Colors.blue,
    this.textColor = Colors.white,
    this.borderColor = Colors.transparent,
    this.width = 200,
    this.height = 50,
    this.fontWeight = FontWeight.bold,
    this.fontSize = 16.0,
    this.borderRadius = 10.0,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(
          color: borderColor,
        ),
        borderRadius: BorderRadius.circular(borderRadius!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          child: Center(
            child: isLoading
                ? SizedBox(
                    height: 30,
                    width: 30,
                    child: CircularProgressIndicator(
                      color: textColor,
                    ),
                  )
                : Text(
                    label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: fontWeight,
                      fontSize: fontSize,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
