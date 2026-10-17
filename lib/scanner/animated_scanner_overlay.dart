import 'package:flutter/material.dart';

class AnimatedScannerOverlay extends StatefulWidget {
  final double width;
  final double height;
  final Color borderColor;
  final Color laserColor;

  const AnimatedScannerOverlay({
    super.key,
    this.width = 280,
    this.height = 180,
    this.borderColor = Colors.white,
    this.laserColor = Colors.redAccent,
  });

  @override
  State<AnimatedScannerOverlay> createState() => _AnimatedScannerOverlayState();
}

class _AnimatedScannerOverlayState extends State<AnimatedScannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _ScannerFramePainter(
            progress: _animation.value,
            borderColor: widget.borderColor,
            laserColor: widget.laserColor,
          ),
        );
      },
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  final double progress;
  final Color borderColor;
  final Color laserColor;

  _ScannerFramePainter({
    required this.progress,
    required this.borderColor,
    required this.laserColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cornerLength = size.width * 0.18;
    final cornerWidth = 4.0;
    final radius = 12.0;

    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerWidth
      ..strokeCap = StrokeCap.round;

    final path = Path();

    path.moveTo(0, cornerLength);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.lineTo(cornerLength, 0);

    path.moveTo(size.width - cornerLength, 0);
    path.lineTo(size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, radius);
    path.lineTo(size.width, cornerLength);

    path.moveTo(size.width, size.height - cornerLength);
    path.lineTo(size.width, size.height - radius);
    path.quadraticBezierTo(
        size.width, size.height, size.width - radius, size.height);
    path.lineTo(size.width - cornerLength, size.height);

    path.moveTo(cornerLength, size.height);
    path.lineTo(radius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    path.lineTo(0, size.height - cornerLength);

    canvas.drawPath(path, paint);

    final laserY = size.height * progress;
    final laserPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          laserColor.withOpacity(0),
          laserColor.withOpacity(0.8),
          laserColor.withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(0, laserY - 15, size.width, 30))
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, laserY - 2, size.width, 4),
      laserPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
