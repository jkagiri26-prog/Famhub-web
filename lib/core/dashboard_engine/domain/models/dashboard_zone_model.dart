import 'package:flutter/widgets.dart';

class DashboardZoneModel {
  const DashboardZoneModel({
    required this.id,
    required this.widgets,
  });

  final String id;

  final List<Widget> widgets;
}