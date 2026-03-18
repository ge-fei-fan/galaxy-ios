import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

/// iOS 微信风格底部栏（半透明+毛玻璃+线性图标）。
///
/// 仅负责 UI/交互，页面切换逻辑由外部传入。
class IosWechatTabBar extends StatelessWidget {
  const IosWechatTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _activeColor = Color(0xFF0A63FF);
  static const _inactiveColor = Color(0xFF8E8E93); // iOS 系统灰
  static const _highlightColor = Color(0x1F0A63FF);
  static const _highlightGlowColor = Color(0x4D0A63FF);

  @override
  Widget build(BuildContext context) {
    // 参考图里是浅色半透明底栏 + 顶部分割线。
    final backgroundColor =
        CupertinoDynamicColor.resolve(CupertinoColors.systemBackground, context)
            .withValues(alpha: 0.82);
    return SafeArea(
      top: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              border: const Border(
                top: BorderSide(
                  color: Color(0x1F000000),
                  width: 0.5,
                ),
              ),
            ),
            child: SizedBox(
              height: 58,
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment(
                      currentIndex == 0
                          ? -1
                          : currentIndex == 1
                              ? 0
                              : 1,
                      0,
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      width: 72,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _highlightColor,
                            _highlightColor.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: _highlightGlowColor,
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: IosWechatTabItem(
                          selected: currentIndex == 0,
                          label: '配置',
                          onTap: () => onTap(0),
                          icon: _WechatConfigIcon(
                            color: currentIndex == 0
                                ? _activeColor
                                : _inactiveColor,
                            filled: currentIndex == 0,
                          ),
                        ),
                      ),
                      Expanded(
                        child: IosWechatTabItem(
                          selected: currentIndex == 1,
                          label: '主题',
                          onTap: () => onTap(1),
                          icon: _WechatTopicIcon(
                            color: currentIndex == 1
                                ? _activeColor
                                : _inactiveColor,
                            filled: currentIndex == 1,
                          ),
                        ),
                      ),
                      Expanded(
                        child: IosWechatTabItem(
                          selected: currentIndex == 2,
                          label: '消息',
                          onTap: () => onTap(2),
                          icon: _WechatMessageIcon(
                            color: currentIndex == 2
                                ? _activeColor
                                : _inactiveColor,
                            filled: currentIndex == 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class IosWechatTabItem extends StatelessWidget {
  const IosWechatTabItem({
    super.key,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 10.5,
      height: 1.1,
      fontWeight: FontWeight.w500,
      color: selected
          ? const Color(0xFF0A63FF)
          : const Color(0xFF8E8E93),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        minimumSize: const Size(44, 44),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.18 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: KeyedSubtree(
                        key: ValueKey<bool>(selected),
                        child: icon,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                style: labelStyle,
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------
// 图标：自绘线性风格
// -----------------

class _WechatConfigIcon extends StatelessWidget {
  const _WechatConfigIcon({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GearPainter(color, filled),
      size: const Size(22, 22),
    );
  }
}

class _WechatTopicIcon extends StatelessWidget {
  const _WechatTopicIcon({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TagPainter(color, filled),
      size: const Size(22, 22),
    );
  }
}

class _WechatMessageIcon extends StatelessWidget {
  const _WechatMessageIcon({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(color, filled),
      size: const Size(22, 22),
    );
  }
}

class _GearPainter extends CustomPainter {
  _GearPainter(this.color, this.filled);

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final c = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width * 0.42;
    final rInner = size.width * 0.18;

    // 外圈
    if (filled) {
      canvas.drawCircle(c, rOuter, fillPaint);
    }
    canvas.drawCircle(c, rOuter, strokePaint);
    // 内圈
    canvas.drawCircle(c, rInner, strokePaint);

    // 齿（8 个短线段）
    for (var i = 0; i < 8; i++) {
      final a = (i * math.pi) / 4;
      final dir = Offset(
        math.cos(a),
        math.sin(a),
      );
      final p1 = c + dir * (rOuter + 0.5);
      final p2 = c + dir * (rOuter + 3.0);
      canvas.drawLine(p1, p2, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GearPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.filled != filled;
  }
}

class _TagPainter extends CustomPainter {
  _TagPainter(this.color, this.filled);

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // 一个略带“切角”的标签形状
    final path = Path();
    path.moveTo(w * 0.22, h * 0.26);
    path.lineTo(w * 0.74, h * 0.26);
    path.lineTo(w * 0.86, h * 0.50);
    path.lineTo(w * 0.74, h * 0.74);
    path.lineTo(w * 0.22, h * 0.74);
    path.quadraticBezierTo(w * 0.14, h * 0.74, w * 0.14, h * 0.66);
    path.lineTo(w * 0.14, h * 0.34);
    path.quadraticBezierTo(w * 0.14, h * 0.26, w * 0.22, h * 0.26);
    path.close();
    if (filled) {
      canvas.drawPath(path, fillPaint);
    }
    canvas.drawPath(path, strokePaint);

    // 小圆点（模拟“孔”）
    canvas.drawCircle(Offset(w * 0.28, h * 0.50), w * 0.04, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _TagPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.filled != filled;
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.color, this.filled);

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.18, w * 0.76, h * 0.60),
      Radius.circular(w * 0.18),
    );
    if (filled) {
      canvas.drawRRect(r, fillPaint);
    }
    canvas.drawRRect(r, strokePaint);

    // 尾巴
    final tail = Path();
    tail.moveTo(w * 0.38, h * 0.78);
    tail.lineTo(w * 0.34, h * 0.92);
    tail.lineTo(w * 0.50, h * 0.80);
    canvas.drawPath(tail, strokePaint);

    // 两条“文字线”
    canvas.drawLine(
        Offset(w * 0.28, h * 0.38), Offset(w * 0.72, h * 0.38), strokePaint);
    canvas.drawLine(
        Offset(w * 0.28, h * 0.52), Offset(w * 0.60, h * 0.52), strokePaint);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.filled != filled;
  }
}







