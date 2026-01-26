import 'package:flutter/material.dart';

class OverflowWidgets {
  static Widget flexibleRow(List<Widget> children) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: children,
    );
  }

  static Widget responsiveChips(List<String> items) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: items.map((item) => Chip(label: Text(item))).toList(),
    );
  }

  static Widget ellipsisText(String text, {int maxLines = 1}) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  static Widget expandableText(String text) {
    return Text(text);
  }

  static Widget scrollableChips(List<String> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) => 
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Chip(label: Text(item)),
          )
        ).toList(),
      ),
    );
  }

  static Widget wrapChips(List<String> items) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: items.map((item) => Chip(label: Text(item))).toList(),
    );
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width > 1024;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width > 600 && MediaQuery.of(context).size.width <= 1024;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width <= 600;
  }
}



