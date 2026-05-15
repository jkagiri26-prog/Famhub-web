import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../shared/widgets/layout/responsive_wrapper_widget.dart';
import '../../../../shared/widgets/headers/module_header_widget.dart';
import '../../../../shared/widgets/headers/section_header_widget.dart';
import '../../../../shared/widgets/cards/report_card_widget.dart';

import 'widgets/analytics_chart_widget.dart';
import 'widgets/analytics_breadcrumb_widget.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return ResponsiveWrapperWidget(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 12),

          /// MODULE HEADER
          ModuleHeaderWidget(
            title: "Analytics",
            subtitle: "Market Intelligence • Reports • Insights",
            trailingIcon: Icons.analytics_outlined,
            onTrailingTap: () {},
          ),

          const SizedBox(height: 16),

          /// CONTEXT BREADCRUMB (MODULE WIDGET)
          const AnalyticsBreadcrumbWidget(),

          const SizedBox(height: 20),

          /// SECTION HEADER
          const SectionHeaderWidget(
            title: "Market Insights",
          ),

          const SizedBox(height: 12),

          /// CHART (MODULE WIDGET)
          AnalyticsChartWidget(primary: primary),

          const SizedBox(height: 24),

          /// SECTION HEADER
          const SectionHeaderWidget(
            title: "Available Reports",
          ),

          const SizedBox(height: 12),

          /// REPORT CARDS (SHARED WIDGET)
          const ReportCardWidget(
            title: "Weekly Price Summary",
            subtitle: "Public Data • PDF",
            price: "FREE",
            isLocked: false,
          ),

          const ReportCardWidget(
            title: "12-Month Yield Forecast",
            subtitle: "AI-Generated • Deep Analysis",
            price: "KSh 250",
            isLocked: true,
          ),

          const ReportCardWidget(
            title: "Soil Chemistry Map",
            subtitle: "Satellite Data • Ward Level",
            price: "KSh 500",
            isLocked: true,
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}