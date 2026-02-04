import 'package:flutter/material.dart';
// Using FamHubService instead of DatabaseHelper

class TechCornerPage extends StatefulWidget {
  final String userRole;
  const TechCornerPage({super.key, required this.userRole});

  @override
  State<TechCornerPage> createState() => _TechCornerPageState();
}

class _TechCornerPageState extends State<TechCornerPage> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("IoT Device Monitor", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList( // FIXED: SliverPadding takes 'sliver', not 'slivers'
              delegate: SliverChildListDelegate([
                _buildDeviceCard("Soil Sensor A1", "Active"),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(String name, String status) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.memory),
        title: Text(name),
        subtitle: Text(status),
      ),
    );
  }
}