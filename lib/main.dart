import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_drawing/path_drawing.dart';

Path svgToPath(String data) => parseSvgPathData(data);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alexander Piscioneri',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        textTheme: GoogleFonts.jetBrainsMonoTextTheme(),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _SvgData {
  final List<String> paths;
  final double width;
  final double height;
  const _SvgData(this.paths, this.width, this.height);
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Phase 1 (0.00 – 0.25): Alexander draws in
  late Animation<double> _alexanderDraw;

  // Phase 2 (0.25 – 0.50): Piscioneri draws in
  late Animation<double> _piscioneriDraw;

  // Phase 3 (0.50 – 0.65): Both flood-fill
  late Animation<double> _fillAnimation;

  // Phase 4a (0.65 – 0.75): Resize + move horizontally into side-by-side position
  late Animation<double> _horizontalAnimation;

  // Phase 4b (0.75 – 0.85): Move upward to final header position
  late Animation<double> _verticalAnimation;

  // Phase 5 (0.85 – 1.00): Body fades in
  late Animation<double> _bodyFade;

  _SvgData? _alexander;
  _SvgData? _piscioneri;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    );

    _alexanderDraw = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.25, curve: Curves.easeInOutCubic),
      ),
    );

    _piscioneriDraw = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.50, curve: Curves.easeInOutCubic),
      ),
    );

    // Fill fades from 0 (stroke only) to 1 (filled)
    _fillAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 0.65, curve: Curves.easeInOut),
      ),
    );

    _horizontalAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 0.775, curve: Curves.easeInOutCubic),
      ),
    );

    _verticalAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.775, 0.85, curve: Curves.easeInOutCubic),
      ),
    );

    _bodyFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
      ),
    );

    _loadSvgs();
  }

  Future<_SvgData> _loadSingleSvg(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);

    double w = 800, h = 120;
    final viewBoxMatch = RegExp(r'viewBox="([^"]+)"').firstMatch(raw);
    if (viewBoxMatch != null) {
      final parts = viewBoxMatch.group(1)!.trim().split(RegExp(r'[\s,]+'));
      if (parts.length == 4) {
        w = double.parse(parts[2]);
        h = double.parse(parts[3]);
      }
    }

    final paths = <String>[];
    for (final match in RegExp(r'd="([^"]+)"').allMatches(raw)) {
      String d = match.group(1)!.trim();
      // Fix scientific notation
      d = d.replaceAllMapped(
        RegExp(r'-?\d+\.?\d*e[+-]\d+', caseSensitive: false),
        (_) => '0',
      );
      // Split into individual subpaths on each M/m command
      // so all letters animate simultaneously at the same progress
      final subpaths = d
          .split(RegExp(r'(?=[Mm])'))
          .map((s) => s.trim())
          .where((s) => s.startsWith('M') || s.startsWith('m'))
          .toList();
      paths.addAll(subpaths);
    }

    return _SvgData(paths, w, h);
  }

  Future<void> _loadSvgs() async {
    final results = await Future.wait([
      _loadSingleSvg('assets/svg/Alexander.svg'),
      _loadSingleSvg('assets/svg/Piscioneri.svg'),
    ]);

    setState(() {
      _alexander = results[0];
      _piscioneri = results[1];
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (_alexander == null || _piscioneri == null) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // ── Centered draw-in sizes ──────────────────────────────────────
          const double centeredWidthFraction = 0.70;

          final double alexCenteredW = sw * centeredWidthFraction;
          final double alexCenteredH =
              alexCenteredW * (_alexander!.height / _alexander!.width);
          final double pisCenteredW = sw * centeredWidthFraction;
          final double pisCenteredH =
              pisCenteredW * (_piscioneri!.height / _piscioneri!.width);

          const double centeredGap = 16.0;
          final double totalCenteredH =
              alexCenteredH + centeredGap + pisCenteredH;
          final double centeredBlockTop = (sh - totalCenteredH) / 2;

          final double alexCenteredTop = centeredBlockTop;
          final double alexCenteredLeft = (sw - alexCenteredW) / 2;
          final double pisCenteredTop =
              centeredBlockTop + alexCenteredH + centeredGap;
          final double pisCenteredLeft = (sw - pisCenteredW) / 2;

          // ── Header sizes ────────────────────────────────────────────────
          const double headerTop = 32.0;
          const double headerH = 40.0;
          const double headerGap = 32.0;

          final double alexHeaderW =
              headerH * (_alexander!.width / _alexander!.height);
          final double pisHeaderW =
              headerH * (_piscioneri!.width / _piscioneri!.height);
          final double totalHeaderW = alexHeaderW + headerGap + pisHeaderW;

          final double headerBlockLeft = (sw - totalHeaderW) / 2;
          final double alexHeaderLeft = headerBlockLeft;
          final double pisHeaderLeft =
              headerBlockLeft + alexHeaderW + headerGap;

          final th = _horizontalAnimation.value; // 0→1 horizontal phase
          final tv = _verticalAnimation.value; // 0→1 vertical phase

          double lerp(double a, double b, double t) => a + (b - a) * t;

          // Alexander
          // Step 1: move horizontally + resize (Y stays centered)
          final double alexMidTop = lerp(
            alexCenteredTop,
            alexCenteredTop,
            th,
          ); // Y unchanged
          final double alexMidLeft = lerp(
            alexCenteredLeft,
            alexHeaderLeft,
            th,
          ); // X moves
          final double alexMidW = lerp(
            alexCenteredW,
            alexHeaderW,
            th,
          ); // width shrinks
          final double alexMidH = lerp(
            alexCenteredH,
            headerH,
            th,
          ); // height shrinks

          // Step 2: move vertically (X/size already final)
          final double alexTop = lerp(alexMidTop, headerTop, tv);
          final double alexLeft = alexMidLeft;
          final double alexW = alexMidW;
          final double alexH = alexMidH;

          // Piscioneri
          final double pisMidTop = lerp(pisCenteredTop, pisCenteredTop, th);
          final double pisMidLeft = lerp(pisCenteredLeft, pisHeaderLeft, th);
          final double pisMidW = lerp(pisCenteredW, pisHeaderW, th);
          final double pisMidH = lerp(pisCenteredH, headerH, th);

          final double pisTop = lerp(pisMidTop, headerTop, tv);
          final double pisLeft = pisMidLeft;
          final double pisW = pisMidW;
          final double pisH = pisMidH;

          return Stack(
            children: [
              Center(
                child: FadeTransition(
                  opacity: _bodyFade,
                  child: const Text(
                    'Something, something, portfolio.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              Positioned(
                top: alexTop,
                left: alexLeft,
                width: alexW,
                height: alexH,
                child: CustomPaint(
                  painter: SvgStrokePainter(
                    drawProgress: _alexanderDraw.value,
                    fillProgress: _fillAnimation.value,
                    svgPaths: _alexander!.paths,
                    svgWidth: _alexander!.width,
                    svgHeight: _alexander!.height,
                  ),
                ),
              ),
              Positioned(
                top: pisTop,
                left: pisLeft,
                width: pisW,
                height: pisH,
                child: CustomPaint(
                  painter: SvgStrokePainter(
                    drawProgress: _piscioneriDraw.value,
                    fillProgress: _fillAnimation.value,
                    svgPaths: _piscioneri!.paths,
                    svgWidth: _piscioneri!.width,
                    svgHeight: _piscioneri!.height,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SvgStrokePainter extends CustomPainter {
  final double drawProgress;
  final double fillProgress;
  final List<String> svgPaths;
  final double svgWidth;
  final double svgHeight;

  const SvgStrokePainter({
    required this.drawProgress,
    required this.fillProgress,
    required this.svgPaths,
    required this.svgWidth,
    required this.svgHeight,
  });

  @override
  @override
  void paint(Canvas canvas, Size size) {
    if (drawProgress <= 0 || svgPaths.isEmpty) return;

    final scaleX = size.width / svgWidth;
    final scaleY = size.height / svgHeight;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Stroke fades in over first 15% of draw, then fades out as fill takes over
    final strokeFadeIn = (drawProgress / 0.15).clamp(0.0, 1.0);
    final strokeOpacity = strokeFadeIn * (1.0 - fillProgress);

    final strokePaint = Paint()
      ..color = Colors.white.withOpacity(strokeOpacity)
      ..strokeWidth = 2.0 / scaleX
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(fillProgress)
      ..style = PaintingStyle.fill;

    // All subpaths drawn simultaneously at the same progress
    for (final d in svgPaths) {
      final metrics = parseSvgPathData(d).computeMetrics().toList();
      for (final metric in metrics) {
        final drawTo = metric.length * drawProgress;
        if (strokePaint.color.alpha > 0) {
          canvas.drawPath(metric.extractPath(0, drawTo), strokePaint);
        }
      }
    }

    // Fill fades in with even-odd rule to preserve counters (holes in o, e, A etc.)
    if (fillPaint.color.alpha > 0) {
      final combined = Path();
      for (final d in svgPaths) {
        combined.addPath(parseSvgPathData(d), Offset.zero);
      }
      combined.fillType = PathFillType.evenOdd;
      canvas.drawPath(combined, fillPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(SvgStrokePainter old) =>
      old.drawProgress != drawProgress ||
      old.fillProgress != fillProgress ||
      old.svgPaths != svgPaths;
}
