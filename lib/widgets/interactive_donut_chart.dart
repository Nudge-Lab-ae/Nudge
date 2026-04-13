import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nudge/main.dart';

class InteractiveDonutChart extends StatefulWidget {
  /// Expects distributionData like:
  /// [
  ///   {"category": "VIP", "count": 30},
  ///   {"category": "Regular", "count": 70},
  ///   {"category": "Needs Care", "count": 15},
  /// ]
  final List<Map<String, dynamic>> distributionData;

  const InteractiveDonutChart({super.key, required this.distributionData});

  @override
  State<InteractiveDonutChart> createState() => _InteractiveDonutChartState();
}

class _InteractiveDonutChartState extends State<InteractiveDonutChart>
    with SingleTickerProviderStateMixin {
  int? selectedIndex;
  late double total;
  late AnimationController _controller;
  late Animation<double> _explodeAnim;
  final Map<String, bool> _visibleSections = {};
  late List<Map<String, dynamic>> _filteredData;

  // Enhanced gradients with higher contrast (light to dark)
  final List<List<Color>> _gradients = [
    [const Color.fromARGB(255, 54, 158, 244), const Color.fromARGB(255, 4, 31, 90)], // Blue
    [const Color(0xFF81C784), const Color.fromARGB(255, 13, 47, 15)], // Green
    [const Color(0xFFFFB74D), const Color.fromARGB(255, 130, 48, 4)], // Orange
    [const Color(0xFFE57373), const Color.fromARGB(255, 105, 17, 17)], // Red
    [const Color(0xFFBA68C8), const Color.fromARGB(255, 48, 13, 90)], // Purple
    [const Color(0xFF4DD0E1), const Color.fromARGB(255, 0, 56, 58)], // Cyan
    [const Color(0xFFA1887F), const Color.fromARGB(255, 36, 22, 20)], // Brown
    [const Color(0xFF90A4AE), const Color.fromARGB(255, 22, 29, 32)], // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize all sections as visible
    for (var item in widget.distributionData) {
      _visibleSections[item["category"] as String] = true;
    }
    
    _updateFilteredData();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _explodeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
  }

  void _updateFilteredData() {
    total = widget.distributionData.fold<double>(
        0, (sum, e) => sum + (_visibleSections[e["category"] as String]! ? (e["count"] as num).toDouble() : 0));
    
    _filteredData = widget.distributionData
        .where((element) => _visibleSections[element["category"] as String]!)
        .toList();
  }

  void _toggleSection(String category) {
    setState(() {
      _visibleSections[category] = !_visibleSections[category]!;
      _updateFilteredData();
      
      // Reset selection if the selected section is hidden
      if (selectedIndex != null && selectedIndex! < _filteredData.length) {
        final selectedCategory = _filteredData[selectedIndex!]["category"] as String;
        if (selectedCategory != category && !_visibleSections[selectedCategory]!) {
          selectedIndex = null;
          _controller.reverse();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _percentFor(int index) {
    if (_filteredData.isEmpty) return '0%';
    final p = (_filteredData[index]["count"] as num).toDouble() / total * 100;
    return '${p.toStringAsFixed(1)}%';
  }

  void _onTapDown(TapDownDetails details, Size size, Offset center, double outerRadius, double innerRadius) {
    if (_filteredData.isEmpty) return;
    
    final local = details.localPosition;
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    final r = sqrt(dx * dx + dy * dy);

    // Check if tap is in the donut ring area (between inner and outer radius)
    if (r < innerRadius - 10 || r > outerRadius + 10) return;

    // If tap is within 10 pixels of the inner radius, still count it as a valid tap
    // This makes the entire donut area more sensitive
    double angle = atan2(dy, dx);
    if (angle < 0) angle += 2 * pi;

    // Check which segment was tapped
    double acc = -pi / 2;
    for (int i = 0; i < _filteredData.length; i++) {
      final sweep = (_filteredData[i]["count"] as num).toDouble() / total * 2 * pi;
      
      // Normalize angles for comparison
      double normalizedAcc = acc;
      double normalizedAccPlusSweep = acc + sweep;
      
      // Handle wrap-around for segments crossing the -π/2 boundary
      if (normalizedAcc < 0) normalizedAcc += 2 * pi;
      if (normalizedAccPlusSweep < 0) normalizedAccPlusSweep += 2 * pi;
      
      // Check if angle is within this segment
      bool isInSegment = false;
      if (normalizedAcc <= normalizedAccPlusSweep) {
        // Normal case: segment doesn't wrap around
        isInSegment = angle >= normalizedAcc && angle <= normalizedAccPlusSweep;
      } else {
        // Segment wraps around 2π boundary
        isInSegment = angle >= normalizedAcc || angle <= normalizedAccPlusSweep;
      }
      
      if (isInSegment) {
        setState(() {
          if (selectedIndex == i) {
            selectedIndex = null;
            _controller.reverse();
          } else {
            selectedIndex = i;
            _controller.forward(from: 0);
          }
        });
        break;
      }
      acc += sweep;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, min(constraints.maxHeight, 280));
      final outerRadius = min(size.width, size.height) * 0.38;
      final innerRadius = outerRadius * 0.65;
      final center = Offset(size.width / 2, size.height / 3);

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Make the entire area around the chart clickable
            GestureDetector(
              onTapDown: (d) => _onTapDown(d, size, center, outerRadius, innerRadius),
              child: Container(
                width: size.width,
                height: size.height * 0.65,
                color: Colors.transparent, // Make entire area tappable
                child: AnimatedBuilder(
                  animation: _explodeAnim,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _DonutPainter(
                        data: _filteredData,
                        total: total,
                        center: center,
                        outerRadius: outerRadius,
                        innerRadius: innerRadius,
                        selectedIndex: selectedIndex,
                        explodeProgress: _explodeAnim.value,
                        gradients: _gradients,
                        visibleSections: _visibleSections,
                        allData: widget.distributionData,
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Compact Legends placed directly below chart
            Container(
              margin: const EdgeInsets.only(top: 40.0),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                    child: Text(
                      'CATEGORIES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: widget.distributionData.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final category = item["category"] as String;
                      final isVisible = _visibleSections[category]!;
                      final count = item["count"] as num;
                      final percent = (count.toDouble() / 
                        widget.distributionData.fold<double>(0, (sum, e) => sum + (e["count"] as num).toDouble()) * 100);
                      
                      return Tooltip(
                        message: '$category: $count (${percent.toStringAsFixed(1)}%)',
                        child: InkWell(
                          onTap: () => _toggleSection(category),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: isVisible 
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.outline,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isVisible 
                                    ? _gradients[index % _gradients.length][0].withOpacity(0.4)
                                    : Theme.of(context).colorScheme.surfaceContainerLowest,
                                width: isVisible ? 1.5 : 1,
                              ),
                              boxShadow: isVisible ? [
                                BoxShadow(
                                  color: _gradients[index % _gradients.length][0].withOpacity(0.1),
                                  blurRadius: 1,
                                  offset: const Offset(0, 1),
                                ),
                              ] : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Compact color indicator with visibility status
                                Stack(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: isVisible 
                                              ? _gradients[index % _gradients.length]
                                              : [Theme.of(context).colorScheme.surfaceContainerLow, Theme.of(context).colorScheme.surfaceContainerLow],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                    ),
                                    if (!isVisible)
                                      Positioned(
                                        right: -1,
                                        bottom: -1,
                                        child: Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.outline,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            size: 3,
                                            color: Theme.of(context).colorScheme.outline,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 3),
                                // Compact category name (truncated if too long)
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth * 0.15,
                                  ),
                                  child: Text(
                                    category.length > 8 ? '${category.substring(0, 7)}..' : category,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isVisible 
                                          ? _gradients[index % _gradients.length][1]
                                          : Theme.of(context).colorScheme.surfaceContainerLow,
                                      height: 1.0,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                // Small percentage indicator
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isVisible 
                                        ? _gradients[index % _gradients.length][0].withOpacity(0.15)
                                        : Theme.of(context).colorScheme.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${percent.toStringAsFixed(percent >= 10 ? 0 : 1)}%',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: isVisible 
                                          ? _gradients[index % _gradients.length][1]
                                          : Theme.of(context).colorScheme.outline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            
            // Selected item info (only shown when something is selected)
            if (selectedIndex != null && selectedIndex! < _filteredData.length)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _gradients[selectedIndex! % _gradients.length],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _gradients[selectedIndex! % _gradients.length][1].withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Icon(
                          Icons.pie_chart,
                          size: 11,
                          color: _gradients[selectedIndex! % _gradients.length][1],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${_filteredData[selectedIndex!]["category"]} • ${_percentFor(selectedIndex!)} '
                          '(${_filteredData[selectedIndex!]["count"]} of ${total.toStringAsFixed(0)})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _DonutPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double total;
  final Offset center;
  final double outerRadius;
  final double innerRadius;
  final int? selectedIndex;
  final double explodeProgress;
  final List<List<Color>> gradients;
  final Map<String, bool> visibleSections;
  final List<Map<String, dynamic>> allData;

  _DonutPainter({
    required this.data,
    required this.total,
    required this.center,
    required this.outerRadius,
    required this.innerRadius,
    required this.selectedIndex,
    required this.explodeProgress,
    required this.gradients,
    required this.visibleSections,
    required this.allData,
  });

  final TextPainter _tp = TextPainter(textDirection: TextDirection.ltr);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || total == 0) {
      // Draw empty state
      final paint = Paint()
        ..color = Theme.of(navigatorKey.currentContext!).colorScheme.surfaceContainerLowest
        ..style = PaintingStyle.fill;
      
      final outerPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: outerRadius));
      
      final innerPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: innerRadius));
      
      canvas.drawPath(Path.combine(
        PathOperation.difference,
        outerPath,
        innerPath,
      ), paint);
      return;
    }
    
    double startAngle = -pi / 2;
    
    // Find the original index in allData for each filtered item
    final Map<String, int> originalIndices = {};
    for (int i = 0; i < allData.length; i++) {
      originalIndices[allData[i]["category"] as String] = i;
    }
    
    for (int i = 0; i < data.length; i++) {
      final category = data[i]["category"] as String;
      final originalIndex = originalIndices[category] ?? i;
      
      final sweep = (data[i]["count"] as num).toDouble() / total * 2 * pi;
      final midAngle = startAngle + sweep / 2;
      final isSelected = (selectedIndex == i);
      final explode = isSelected ? explodeProgress * 15.0 : 0.0;
      final offset = Offset(cos(midAngle) * explode, sin(midAngle) * explode);
      final sliceCenter = center + offset;

      // Create the donut segment
      final path = Path()
        ..addArc(Rect.fromCircle(center: sliceCenter, radius: outerRadius), startAngle, sweep)
        ..arcTo(Rect.fromCircle(center: sliceCenter, radius: innerRadius),
            startAngle + sweep, -sweep, false)
        ..close();

      // Calculate gradient start and end points for THIS segment only
      // This ensures the full gradient is applied to each segment individually
      final colors = gradients[originalIndex % gradients.length];
      
      // Calculate points along the middle of the segment for gradient direction
      // final midInnerPoint = sliceCenter + Offset(cos(midAngle), sin(midAngle)) * innerRadius;
      // final midOuterPoint = sliceCenter + Offset(cos(midAngle), sin(midAngle)) * outerRadius;
      
      // Create a gradient that spans the entire segment from inner to outer edge
      // This gives each segment its own full gradient
      final gradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: colors,
        stops: const [0.0, 1.0],
      );
      
      // Create a shader that covers the segment's bounding box
      final segmentBounds = Rect.fromCircle(
        center: sliceCenter + Offset(cos(midAngle), sin(midAngle)) * ((innerRadius + outerRadius) / 2),
        radius: (outerRadius - innerRadius) / 2,
      ).inflate(outerRadius - innerRadius);
      
      final paint = Paint()
        ..shader = gradient.createShader(segmentBounds)
        ..style = PaintingStyle.fill;
      
      // Add a subtle shadow for depth
      if (isSelected) {
        final shadowPaint = Paint()
          ..color = Colors.black.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        
        final shadowPath = Path()
          ..addArc(Rect.fromCircle(center: sliceCenter + const Offset(0, 2), radius: outerRadius), startAngle, sweep)
          ..arcTo(Rect.fromCircle(center: sliceCenter + const Offset(0, 2), radius: innerRadius),
              startAngle + sweep, -sweep, false)
          ..close();
        
        canvas.drawPath(shadowPath, shadowPaint);
      }

      canvas.drawPath(path, paint);

      // Draw percentage label
      if (sweep > 0.3) { // Only draw label if segment is large enough
        final percent = (data[i]["count"] as num).toDouble() / total * 100;
        _tp.text = TextSpan(
          text: '${percent.toStringAsFixed(percent >= 1 ? 0 : 1)}%',
          style: TextStyle(
            color: Theme.of(navigatorKey.currentContext!).colorScheme.surfaceContainerLowest,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 2,
                offset: Offset(1, 1),
              ),
            ],
          ),
        );
        _tp.layout();
        final labelRadius = (innerRadius + outerRadius) / 2;
        final tx = sliceCenter.dx + cos(midAngle) * labelRadius - _tp.width / 2;
        final ty = sliceCenter.dy + sin(midAngle) * labelRadius - _tp.height / 2;
        _tp.paint(canvas, Offset(tx, ty));
      }

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) {
    return old.selectedIndex != selectedIndex || 
           old.explodeProgress != explodeProgress ||
           old.visibleSections != visibleSections;
  }
}