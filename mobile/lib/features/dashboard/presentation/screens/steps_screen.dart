import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../shared/widgets/app_background.dart';

class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  int _selectedTab = 0; // 0=Day, 1=Week, 2=Month, 3=Year
  late DateTime _now;
  int _totalSteps = 0;
  List<double> _chartValues = [];
  List<String> _xAxisLabels = [];

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _loadData();
  }

  void _loadData() {
    // Generate empty buckets
    _chartValues = [];
    _xAxisLabels = [];
    _totalSteps = 0;

    String dateKey() => DateFormat('yyyy-MM-dd').format(_now);

    if (_selectedTab == 0) {
      // DAY
      final Map<String, dynamic> hourly = StorageService.getItem('steps_hourly_${dateKey()}') ?? {};
      _chartValues = List.filled(24, 0.0);
      for (int i = 0; i < 24; i++) {
        _chartValues[i] = ((hourly[i.toString()] as num?)?.toDouble() ?? 0.0);
        _totalSteps += _chartValues[i].toInt();
      }
      _xAxisLabels = ['12 AM', '6 AM', '12 PM', '6 PM'];
      
      // Fallback to fetch total if hourly doesn't match total perfectly yet
      final todayTotal = (StorageService.getItem('current_steps_${dateKey()}') as num?)?.toInt() ?? 0;
      if (_totalSteps == 0 && todayTotal > 0) {
        _totalSteps = todayTotal;
        _chartValues[DateTime.now().hour] = todayTotal.toDouble(); 
      }
    } 
    else if (_selectedTab == 1) {
      // WEEK (past 7 days)
      _chartValues = List.filled(7, 0.0);
      DateTime startDay = DateTime(_now.year, _now.month, _now.day - 6);
      int maxI = 6;
      for (int i = 0; i <= maxI; i++) {
        DateTime d = DateTime(startDay.year, startDay.month, startDay.day + i);
        String k = DateFormat('yyyy-MM-dd').format(d);
        int s = (StorageService.getItem('current_steps_$k') as num?)?.toInt() ?? 0;
        _chartValues[i] = s.toDouble();
        _totalSteps += s;
        _xAxisLabels.add(DateFormat('EEE').format(d));
      }
    } 
    else if (_selectedTab == 2) {
      // MONTH (past 30 days)
      _chartValues = List.filled(30, 0.0);
      DateTime startDay = DateTime(_now.year, _now.month, _now.day - 29);
      for (int i = 0; i < 30; i++) {
        DateTime d = DateTime(startDay.year, startDay.month, startDay.day + i);
        String k = DateFormat('yyyy-MM-dd').format(d);
        int s = (StorageService.getItem('current_steps_$k') as num?)?.toInt() ?? 0;
        _chartValues[i] = s.toDouble();
        _totalSteps += s;
        if (i == 0 || i == 14 || i == 29) {
          _xAxisLabels.add(DateFormat('MMM d').format(d));
        } else {
          _xAxisLabels.add('');
        }
      }
    } 
    else {
      // YEAR (past 12 months)
      _chartValues = List.filled(12, 0.0);
      for (int i = 0; i < 12; i++) {
        DateTime monthStart = DateTime(_now.year, _now.month - (11 - i), 1);
        int daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
        int monthTotal = 0;
        for (int d = 1; d <= daysInMonth; d++) {
          DateTime current = DateTime(monthStart.year, monthStart.month, d);
          String k = DateFormat('yyyy-MM-dd').format(current);
          monthTotal += (StorageService.getItem('current_steps_$k') as num?)?.toInt() ?? 0;
        }
        _chartValues[i] = monthTotal.toDouble();
        _totalSteps += monthTotal;
        _xAxisLabels.add(DateFormat('MMM').format(monthStart));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      useBlobs: true,
      isInternal: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.textPrimary.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 16),
            ),
            onPressed: () => context.pop(),
          ),
          title: Text('Step Count', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
          centerTitle: false,
        ),
        body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const SizedBox(height: 20),
              _buildTabs(),
              const SizedBox(height: 24),
              Text('TOTAL', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
              Text(
                NumberFormat('#,###').format(_totalSteps),
                style: GoogleFonts.outfit(color: Colors.orange, fontSize: 40, fontWeight: FontWeight.bold, height: 1.1),
              ),
              Text(_getSubtitleText(), style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 30),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.2,
                    child: CustomPaint(
                      painter: _StepChartPainter(_chartValues, _xAxisLabels, _selectedTab),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        ),
      ),
    );
  }

  String _getSubtitleText() {
    if (_selectedTab == 0) return 'Today';
    if (_selectedTab == 1) return 'Past 7 Days';
    if (_selectedTab == 2) return 'Past 30 Days';
    return 'Past 12 Months';
  }

  Widget _buildTabs() {
    final tabs = ['D', 'W', 'M', 'Y'];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: List.generate(4, (i) {
          final isSelected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = i;
                  _loadData();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(tabs[i], style: GoogleFonts.outfit(color: isSelected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StepChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> xAxisLabels;
  final int tab;

  _StepChartPainter(this.values, this.xAxisLabels, this.tab);

  @override
  void paint(Canvas canvas, Size size) {
    double maxVal = 0;
    for (var v in values) {
      if (v > maxVal) maxVal = v;
    }
    
    // Ensure we have a reasonable y-axis max
    if (maxVal == 0) maxVal = 3000;
    
    // Round round maxVal up to nearest nice number
    double niceMax = maxVal;
    if (maxVal > 0) {
      double magnitude = pow(10, (log(maxVal) / ln10).floor()).toDouble();
      niceMax = ((maxVal / magnitude).ceil()) * magnitude;
      if (niceMax == maxVal) niceMax += magnitude;
    }

    // Colors
    final gridColor = AppColors.textPrimary.withOpacity(0.35);
    final textColor = AppColors.textPrimary.withOpacity(0.8);
    final barColor = Colors.orange;

    // Grid Line Paints
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final dashedPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Dimensions
    const double bottomLabelHeight = 24.0;
    const double rightLabelWidth = 40.0;
    final chartRect = Rect.fromLTWH(0, 0, size.width - rightLabelWidth, size.height - bottomLabelHeight);

    // Draw Horizontal Grid Lines (Y-Axis)
    int yLines = 3; // 0, middle, top
    for (int i = 0; i < yLines; i++) {
      double yPos = chartRect.bottom - (chartRect.height * (i / (yLines - 1)));
      canvas.drawLine(Offset(0, yPos), Offset(chartRect.right, yPos), gridPaint);
      
      // Draw Y-Axis labels
      double val = (niceMax * i) / (yLines - 1);
      final textPainter = TextPainter(
        text: TextSpan(text: NumberFormat('#,###').format(val), style: GoogleFonts.outfit(color: textColor, fontSize: 10)),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(chartRect.right + 4, yPos - textPainter.height / 2));
    }

    // Draw Vertical Dashed Lines (X-Axis)
    if (tab == 0) {
      // Plot grid lines for exactly 0h, 6h, 12h, 18h
      List<int> hourMarks = [0, 6, 12, 18];
      for (int i = 0; i < hourMarks.length; i++) {
        // Find xPos aligned with the bar index
        double xPos = (chartRect.width / 24) * hourMarks[i] + (chartRect.width / 24) / 2;
        _drawDashedLine(canvas, Offset(xPos, 0), Offset(xPos, chartRect.bottom), dashedPaint);
        
        // Draw X-Axis labels
        if (i < xAxisLabels.length) {
          final textPainter = TextPainter(
            text: TextSpan(text: xAxisLabels[i], style: GoogleFonts.outfit(color: textColor, fontSize: 10)),
            textDirection: ui.TextDirection.ltr,
          );
          textPainter.layout();
          double tx = xPos - (textPainter.width / 2);
          if (tx < 0) tx = 0;
          if (tx > chartRect.right - textPainter.width) tx = chartRect.right - textPainter.width;
          textPainter.paint(canvas, Offset(tx, chartRect.bottom + 6));
        }
      }
    } else {
      // For Week, Month, Year
      int numLabels = xAxisLabels.where((l) => l.isNotEmpty).length;
      int labelIdx = 0;
      for (int i = 0; i < values.length; i++) {
        if (tab == 1 || (tab == 2 && (i == 0 || i == 14 || i == 29)) || tab == 3) {
          double xPos = (chartRect.width / (values.length)) * i + (chartRect.width / values.length) / 2;
          if (tab == 2) {
             xPos = (chartRect.width / 29) * i; 
          }
          _drawDashedLine(canvas, Offset(xPos, 0), Offset(xPos, chartRect.bottom), dashedPaint);
          
          String label = '';
          if (tab == 1 && i < xAxisLabels.length) label = xAxisLabels[i];
          if (tab == 2 && labelIdx < xAxisLabels.length && xAxisLabels[i].isNotEmpty) {
            label = xAxisLabels[i];
            labelIdx++;
          }
          if (tab == 3 && i < xAxisLabels.length) label = xAxisLabels[i];

          if (label.isNotEmpty) {
            final textPainter = TextPainter(
              text: TextSpan(text: label, style: GoogleFonts.outfit(color: textColor, fontSize: 10)),
              textDirection: ui.TextDirection.ltr,
            );
            textPainter.layout();
            double tx = xPos - (textPainter.width / 2);
            textPainter.paint(canvas, Offset(tx, chartRect.bottom + 6));
          }
        }
      }
    }

    // Draw Bars
    if (values.isEmpty) return;
    
    double barWidth = (chartRect.width / values.length) * 0.6;
    if (barWidth > 30) barWidth = 30; // Max bar width
    if (tab == 2) barWidth = (chartRect.width / 30) * 0.8; // Month bars are tight

    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < values.length; i++) {
      if (values[i] > 0) {
        double barHeight = (values[i] / niceMax) * chartRect.height;
        double xPos = (chartRect.width / values.length) * i + (chartRect.width / values.length) / 2 - (barWidth / 2);
        
        final rBox = RRect.fromRectAndRadius(
          Rect.fromLTWH(xPos, chartRect.bottom - barHeight, barWidth, barHeight),
          const Radius.circular(4)
        );
        canvas.drawRRect(rBox, barPaint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const int dashWidth = 4;
    const int dashSpace = 4;
    double startY = p1.dy;
    while (startY < p2.dy) {
      canvas.drawLine(Offset(p1.dx, startY), Offset(p1.dx, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
