import 'package:flutter/material.dart';
import '../theme/app_color.dart';

class CustomTextField extends StatefulWidget {
  final String hintText;
  final IconData? prefixIcon;
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final bool isPassword;
  final double? width;
  final double? height;
  final bool isMultiline;
  final Color? borderColor;
  final Color backgroundColor;
  final Color textColor;
  final Color hintColor;
  final bool hasError;


  const CustomTextField({
    super.key,
    this.hasError = false,
    required this.hintText,
    required this.controller,
    this.prefixIcon,
    this.errorText,
    this.onChanged,
    this.validator,
    this.isPassword = false,
    this.width,
    this.height,
    this.isMultiline = false,
    this.borderColor,
    this.hintColor = const Color(0xFF838E9E),
    this.textColor = Colors.black,
    this.backgroundColor = AppColors.white,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _isObscured = true;
  late FocusNode _focusNode;
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    _focusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    widget.controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(() {});
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color defaultBorder = widget.borderColor ?? Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            width: widget.width,
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(10),

              border: Border.all(
                color: _focusNode.hasFocus ? Colors.blueAccent : defaultBorder,
                width: _focusNode.hasFocus ? 1 : 1,
              ),
            ),
            child: Row(
              children: [
                if (widget.prefixIcon != null)
                  Icon(widget.prefixIcon, color: widget.hintColor),

                Expanded(
                  child: TextFormField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    obscureText: widget.isPassword ? _isObscured : false,
                    maxLines: widget.isMultiline ? null : 1,
                    validator: widget.validator,
                    onChanged: widget.onChanged,
                    style: TextStyle(
                      color: widget.hasError ? Colors.red : widget.textColor,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        color: widget.hintColor,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                if (widget.isPassword && widget.controller.text.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      _isObscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscured = !_isObscured;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
