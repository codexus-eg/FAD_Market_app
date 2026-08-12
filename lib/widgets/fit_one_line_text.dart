import 'package:flutter/material.dart';

class FitOneLineText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Alignment alignment;
  final int maxLines;

  const FitOneLineText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.alignment = Alignment.center,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        text,
        maxLines: maxLines,
        softWrap: false,
        overflow: TextOverflow.visible,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}
