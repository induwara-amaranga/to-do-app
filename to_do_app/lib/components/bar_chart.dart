import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/themes/app_colors.dart';

/// Completed tasks per weekday. The busiest day is drawn in the accent
/// colour, the rest in a neutral track colour, with the count above each bar.
class MyBarChart extends StatelessWidget {
  final Map<int, List<Task>> mappedWeek;
  final bool isFromMonday;
  const MyBarChart({
    super.key,
    required this.mappedWeek,
    required this.isFromMonday,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final int peak = mappedWeek.values
        .map((v) => v.length)
        .fold(0, (a, b) => a > b ? a : b);
    final labelStyle = TextStyle(fontSize: 12, color: colors.muted);

    return BarChart(
      BarChartData(
        maxY: (peak + 1).toDouble(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 4,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (rod.toY == 0) return null;
              return BarTooltipItem(
                rod.toY.toInt().toString(),
                TextStyle(fontSize: 11, color: colors.muted),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[value.toInt()], style: labelStyle),
                );
              },
            ),
          ),
        ),
        barGroups:
            mappedWeek.entries.map((entry) {
              final n = entry.value.length;
              final isPeak = peak > 0 && n == peak;
              return BarChartGroupData(
                x: entry.key - 1,
                showingTooltipIndicators: n > 0 ? [0] : [],
                barRods: [
                  BarChartRodData(
                    toY: n.toDouble(),
                    color: isPeak ? kAccent : colors.trackOff,
                    width: 22,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }
}
