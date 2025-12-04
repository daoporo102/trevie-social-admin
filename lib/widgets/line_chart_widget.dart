import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_media_admin/services/dashboard_service.dart';
import 'package:social_media_admin/utils/colors.dart';

class LineChartWidget extends StatefulWidget {
  final String title;
  final Map<DateTime, int> data;
  final Color lineColor;
  final Function(TimePeriod)? onPeriodChanged;
  final TimePeriod currentPeriod; // Add this

  const LineChartWidget({
    super.key,
    required this.title,
    required this.data,
    required this.lineColor,
    this.onPeriodChanged,
    this.currentPeriod = TimePeriod.week, // Add this
  });

  @override
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget> {
  String _getPeriodLabel(TimePeriod period) {
    switch (period) {
      case TimePeriod.week:
        return '7 ngày';
      case TimePeriod.month:
        return '30 ngày';
      case TimePeriod.year:
        return '1 năm';
    }
  }

  String _formatDate(DateTime date, TimePeriod period, int totalPoints) {
    switch (period) {
      case TimePeriod.week:
        return DateFormat('dd/MM').format(date);
      case TimePeriod.month:
        // For month view, show week numbers: "Tuần 1", "Tuần 2", etc.
        final sortedDates = widget.data.keys.toList()..sort();
        final firstDate = sortedDates.first;
        final weekNumber = (date.difference(firstDate).inDays / 7).floor() + 1;
        return 'Tuần $weekNumber';
      case TimePeriod.year:
        // For year view, show month names
        return _getVietnameseMonth(date.month);
    }
  }

  // Get Vietnamese month name
  String _getVietnameseMonth(int month) {
    const months = [
      'Tháng 1',
      'Tháng 2',
      'Tháng 3',
      'Tháng 4',
      'Tháng 5',
      'Tháng 6',
      'Tháng 7',
      'Tháng 8',
      'Tháng 9',
      'Tháng 10',
      'Tháng 11',
      'Tháng 12',
    ];
    return months[month - 1];
  }

  // Aggregate data based on period
  Map<DateTime, int> _aggregateData(
    Map<DateTime, int> originalData,
    TimePeriod period,
  ) {
    if (period == TimePeriod.week) {
      return originalData;
    }

    final sortedDates = originalData.keys.toList()..sort();
    if (sortedDates.isEmpty) return {};

    Map<DateTime, int> aggregatedData = {};

    if (period == TimePeriod.month) {
      // Aggregate by week (every 7 days)
      DateTime? weekStart;
      int weekSum = 0;
      int dayCount = 0;

      for (int i = 0; i < sortedDates.length; i++) {
        final date = sortedDates[i];

        if (weekStart == null) {
          weekStart = date;
          weekSum = originalData[date]!;
          dayCount = 1;
        } else {
          dayCount++;
          weekSum += originalData[date]!;

          if (dayCount == 7 || i == sortedDates.length - 1) {
            aggregatedData[weekStart] = weekSum;
            weekStart = null;
            weekSum = 0;
            dayCount = 0;
          }
        }
      }
    } else if (period == TimePeriod.year) {
      // Aggregate by month (12 months)
      final now = DateTime.now();

      for (int i = 11; i >= 0; i--) {
        int targetYear = now.year;
        int targetMonth = now.month - i;

        while (targetMonth <= 0) {
          targetMonth += 12;
          targetYear--;
        }

        final monthDate = DateTime(targetYear, targetMonth, 1);
        aggregatedData[monthDate] = 0;
      }

      for (var date in sortedDates) {
        final monthKey = DateTime(date.year, date.month, 1);
        if (aggregatedData.containsKey(monthKey)) {
          aggregatedData[monthKey] =
              aggregatedData[monthKey]! + originalData[date]!;
        }
      }
    }

    return aggregatedData;
  }

  // Calculate appropriate label interval based on data points
  int _calculateLabelInterval(int totalPoints, TimePeriod period) {
    if (period == TimePeriod.week) {
      return 1; // Show all 7 days
    } else if (period == TimePeriod.month) {
      return 1; // Show all weeks (usually 4-5 weeks)
    } else {
      // For year, show every month but might skip some if too crowded
      return totalPoints > 12 ? 2 : 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPeriod = widget.currentPeriod;
    final aggregatedData = _aggregateData(widget.data, currentPeriod);
    final sortedDates = aggregatedData.keys.toList()..sort();

    final maxValue = aggregatedData.values.isEmpty
        ? 10
        : aggregatedData.values.reduce((a, b) => a > b ? a : b);

    final maxY = maxValue == 0 ? 10.0 : (maxValue * 1.2).ceilToDouble();

    double calculateInterval(double max) {
      if (max <= 5) return 1;
      if (max <= 10) return 2;
      if (max <= 20) return 5;
      if (max <= 50) return 10;
      if (max <= 100) return 20;
      return (max / 5).ceilToDouble();
    }

    final interval = calculateInterval(maxY);
    final labelInterval = _calculateLabelInterval(
      sortedDates.length,
      currentPeriod,
    );

    if (aggregatedData.isEmpty || sortedDates.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
              ),
              _buildPeriodSelector(),
            ],
          ),
          const SizedBox(height: 20.0),
          SizedBox(
            height: 200.0,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: labelInterval.toDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < sortedDates.length) {
                          final date = sortedDates[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Transform.rotate(
                              angle: currentPeriod == TimePeriod.year
                                  ? -0.5
                                  : 0,
                              child: Text(
                                _formatDate(
                                  date,
                                  currentPeriod,
                                  sortedDates.length,
                                ),
                                style: TextStyle(
                                  color: secondaryColor,
                                  fontSize: currentPeriod == TimePeriod.year
                                      ? 9
                                      : 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 == 0) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: secondaryColor,
                              fontSize: 12,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                minX: 0,
                maxX: sortedDates.length - 1.0,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: sortedDates.asMap().entries.map((entry) {
                      final index = entry.key;
                      final date = entry.value;
                      return FlSpot(
                        index.toDouble(),
                        aggregatedData[date]!.toDouble(),
                      );
                    }).toList(),
                    isCurved: true,
                    color: widget.lineColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: currentPeriod == TimePeriod.week),
                    belowBarData: BarAreaData(
                      show: true,
                      color: widget.lineColor.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: TimePeriod.values.map((period) {
          final isSelected = widget.currentPeriod == period;
          return InkWell(
            onTap: () {
              widget.onPeriodChanged?.call(period);
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? widget.lineColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _getPeriodLabel(period),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? onPrimaryColor : secondaryColor,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              _buildPeriodSelector(),
            ],
          ),
          const SizedBox(height: 20.0),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: Text(
                'Chưa có dữ liệu',
                style: TextStyle(fontSize: 16.0, color: secondaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
