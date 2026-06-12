
import 'package:flutter/material.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';
import 'package:famhub_app/shared/layouts/section_container_widget.dart';

import '../widgets/logistics_active_shipment_card_widget.dart';
import '../widgets/transporter_listing_card_widget.dart';

class LogisticsPage extends StatelessWidget {
  const LogisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapperWidget(
      child: ListView(
        children: [
          const SizedBox(height: 10),

          /// MODULE HEADER
          const ModuleHeaderWidget(
            title: "Logistics",
            subtitle: "Transport • Fleet • Supply Chain",
          ),

          const SizedBox(height: 16),

          /// ACTIVE SHIPMENT
          const LogisticsActiveShipmentCardWidget(),

          const SizedBox(height: 20),

          /// SECTION HEADER
          const SectionHeaderWidget(
            title: "Available Transporters",
          ),

          const SizedBox(height: 12),

          /// TRANSPORTERS LIST
          const TransporterListingCardWidget(
            name: "Molo Express",
            vehicle: "5 Ton Truck",
            rate: "KSh 150/km",
          ),

          const TransporterListingCardWidget(
            name: "Nakuru Logistics",
            vehicle: "10 Ton Lorry",
            rate: "KSh 280/km",
          ),

          const TransporterListingCardWidget(
            name: "Farm-to-Market",
            vehicle: "Pick-up 1 Ton",
            rate: "KSh 80/km",
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}