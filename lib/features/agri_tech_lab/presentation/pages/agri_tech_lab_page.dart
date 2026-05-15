import 'package:flutter/material.dart';

import '../../../../shared/widgets/layout/responsive_wrapper_widget.dart';
import '../../../../shared/widgets/headers/module_header_widget.dart';
import '../../../../shared/widgets/headers/section_header_widget.dart';
import '../../../../shared/widgets/layout/section_container_widget.dart';

import '../widgets/device_card_widget.dart';

class AgriTechHubPage extends StatelessWidget {
  const AgriTechHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return ResponsiveWrapperWidget(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 12),

          /// HEADER
          ModuleHeaderWidget(
            title: "Agri Tech Hub",
            subtitle: "IoT Devices • Sensors • Smart Farming",
            trailingIcon: Icons.sensors,
            onTrailingTap: () {},
          ),

          const SizedBox(height: 16),

          /// SECTION
          const SectionHeaderWidget(
            title: "IoT Farm Devices",
          ),

          const SizedBox(height: 12),

          /// DEVICE LIST
          SectionContainerWidget(
            child: Column(
              children: const [
                DeviceCardWidget(
                  name: 'Soil Sensor A1',
                  status: 'Active',
                ),
                SizedBox(height: 12),
                DeviceCardWidget(
                  name: 'Greenhouse Climate Sensor',
                  status: 'Online',
                ),
                SizedBox(height: 12),
                DeviceCardWidget(
                  name: 'Water Flow Meter',
                  status: 'Maintenance Required',
                ),
              ],
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}