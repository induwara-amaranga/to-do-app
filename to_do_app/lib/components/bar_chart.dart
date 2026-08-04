import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/models/task.dart';

class MyBarChart extends StatelessWidget {
  final Map<int, List<Task>> mappedWeek;
  final bool isFromMonday;
  const MyBarChart({required this.mappedWeek, required this.isFromMonday});
  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y:
                  mappedWeek.values
                      .map((v) => v.length)
                      .toList()
                      .reduce((a, b) => a + b)
                      .toDouble() /
                  7,
              // ← value where the line should appear
              strokeWidth: 2, // thickness
              color: Colors.grey, // color
              dashArray: [6, 4], // dashed line (optional)
            ),
          ],
        ),
        //borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
        //barTouchData: BarTouchData(enabled: false),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.grey, width: 1),
            right: BorderSide(color: Colors.grey, width: 1), // Y-axis
            bottom: BorderSide(color: Colors.grey, width: 1), // X-axis
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                List<String> labels =
                    isFromMonday
                        ? ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                        : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                return Text(labels[value.toInt()]);
              },
            ),
          ),
        ),
        barGroups:
            mappedWeek.entries
                .map(
                  (entry) => BarChartGroupData(
                    //showingTooltipIndicators: ,
                    x: entry.key - 1, //isFromMonday? entry.key - 1:1,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.length.toDouble(),
                        color: Colors.blue,
                        width: 20,
                      ),
                    ],
                  ),
                )
                .toList(),
      ),
    );
  }
}
