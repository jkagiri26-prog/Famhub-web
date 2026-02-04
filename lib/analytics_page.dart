import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final String _selectedMainCategory = "Crops";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryGreen = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8F9FA),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: [
          const SizedBox(height: 16),
          _buildLocationBreadcrumb(primaryGreen),
          const SizedBox(height: 20),
          _buildMarketHeader("Market Analytics"),
          const SizedBox(height: 16),
          _buildDataVisualization(primaryGreen),
          const SizedBox(height: 24),
          _buildMarketHeader("Available Reports"),
          const SizedBox(height: 12),
          
          // Using your new components here
          _buildReportListing(
            title: "Weekly Price Summary",
            sub: "Public Data • PDF",
            price: "FREE",
            isLocked: false,
            primary: primaryGreen,
          ),
          _buildReportListing(
            title: "12-Month Yield Forecast",
            sub: "AI-Generated • Deep Analysis",
            price: "KSh 250",
            isLocked: true,
            primary: primaryGreen,
          ),
          _buildReportListing(
            title: "Soil Chemistry Map - $_selectedMainCategory",
            sub: "Satellite Data • Ward Level",
            price: "KSh 500",
            isLocked: true,
            primary: primaryGreen,
          ),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildLocationBreadcrumb(Color primary) {
    return Row(
      children: [
        Icon(Icons.location_on, size: 14, color: primary),
        const SizedBox(width: 4),
        const Text("Kenya > Rift Valley > Nakuru", style: TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  Widget _buildMarketHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1),
    );
  }

  Widget _buildDataVisualization(Color primary) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [const FlSpot(0, 3), const FlSpot(2, 5), const FlSpot(4, 4), const FlSpot(6, 8)],
              isCurved: true,
              color: primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: primary.withValues(alpha: 0.1)),
            ),
          ],
        ),
      ),
    );
  }

  // --- REFACTORED PREMIUM LISTING COMPONENT ---
  Widget _buildReportListing({
    required String title,
    required String sub,
    required String price,
    required bool isLocked,
    required Color primary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            isLocked ? Icons.summarize_outlined : Icons.download_done_rounded,
            color: isLocked ? Colors.grey : Colors.green,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(sub, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _handleReportPurchase(title, price),
            child: Container(
              width: 90,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isLocked ? const Color(0xFFFFF8E1) : const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isLocked ? Colors.orange.shade200 : Colors.green.shade200),
              ),
              child: Center(
                child: Text(
                  price,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isLocked ? Colors.orange.shade900 : const Color(0xFF2E7D32),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleReportPurchase(String title, String price) {
    debugPrint("Initiating purchase for $title at $price");
    // This is where M-Pesa STK Push logic will eventually sit
  }
}