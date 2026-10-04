import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/managedkafka/v1.dart';
import 'package:to_do_app/models/task.dart';

class MyPieChart extends StatefulWidget {
  final Map<String, List<Task>> mappedPending;
  final int total;
  double shade = 0;
  final Color color;

  MyPieChart({
    required this.mappedPending,
    required this.total,
    required this.color,
  }) {}

  @override
  State<MyPieChart> createState() => _MyPieChartState();
}

class _MyPieChartState extends State<MyPieChart> {
  late double shade;
  late Color color;
  List<Color> colors = [];

  double offset = 0.13;

  int selectedIndex = -1;

  Color lighten(Color color, [double amount = 0.1]) {
    if (amount > 1) amount = 1;
    if (amount < 0) amount = 0;

    final r = (color.red + ((255 - color.red) * amount)).round();
    final g = (color.green + ((255 - color.green) * amount)).round();
    final b = (color.blue + ((255 - color.blue) * amount)).round();

    return Color.fromARGB(color.alpha, r, g, b);
  }

  // Usage
  Color darken(Color color, [double amount = 0.1]) {
    int r = (color.r * (1 - amount)).round().clamp(0, 255);
    int g = (color.g * (1 - amount)).round().clamp(0, 255);
    int b = (color.b * (1 - amount)).round().clamp(0, 255);

    return Color.fromARGB(color.alpha, r, g, b);
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    color = widget.color;

    shade = -offset;
    for (var category in widget.mappedPending.keys) {
      shade += offset;

      colors.add(lighten(color, shade));
    }
    shade = -offset;
  }

  @override
  Widget build(BuildContext context) {
    shade = -offset;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 200,
          width: 200,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  setState(() {
                    selectedIndex =
                        response?.touchedSection?.touchedSectionIndex ?? -1;
                  });
                },
              ),
              sectionsSpace: 4,
              centerSpaceRadius: 40,
              sections:
                  widget.mappedPending.entries.map((e) {
                    shade = shade + offset;
                    return PieChartSectionData(
                      color: lighten(
                        Theme.of(context).colorScheme.primary,
                        shade,
                      ),
                      value:
                          widget.total != 0 ? e.value.length / widget.total : 0,
                      title:
                          widget.total != 0
                              ? '${(e.value.length / widget.total * 100).round()}%'
                              : '0%',
                      radius: 60,
                      titleStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
        Spacer(),
        Container(
          width: 100,
          height: 200,
          child: ListView.builder(
            itemCount: colors.length,
            itemBuilder: (context, index) {
              return Container(
                padding: EdgeInsets.all(2),
                color:
                    selectedIndex == index
                        ? Theme.of(context).colorScheme.secondary
                        : null,
                child: Row(
                  children: [
                    Container(width: 10, height: 10, color: colors[index]),
                    Spacer(),
                    Text(widget.mappedPending.keys.toList()[index]),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
