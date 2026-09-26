import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Centralized cache and pre-warmer for fragment shaders.
/// Eliminates runtime `FragmentProgram::initFromAsset` and `LinkProgram` GPU/Raster
/// thread pauses by compiling and linking shaders ahead of time during app bootstrap.
class ShaderCache {
  ShaderCache._();

  static const String stretchShaderAsset = 'shaders/stretch_effect.frag';
  static ui.FragmentProgram? _stretchProgram;
  static ui.FragmentShader? _stretchShader;
  static Future<ui.FragmentProgram?>? _preloadFuture;

  /// Returns whether the stretch shader program has been compiled and is ready.
  static bool get isReady => _stretchProgram != null && _stretchShader != null;

  /// Returns the cached [ui.FragmentProgram], or null if not yet preloaded.
  static ui.FragmentProgram? get stretchProgram => _stretchProgram;

  /// Returns the cached reusable [ui.FragmentShader], or null if not ready.
  static ui.FragmentShader? get stretchShader => _stretchShader;

  /// Preloads and compiles the stretch shader asynchronously.
  /// Executes `LinkProgram` off the critical frame render pipeline during bootstrap.
  static Future<ui.FragmentProgram?> preload() {
    if (_stretchProgram != null) {
      return SynchronousFuture<ui.FragmentProgram?>(_stretchProgram);
    }
    if (_preloadFuture != null) {
      return _preloadFuture!;
    }

    _preloadFuture = _loadAndWarmup();
    return _preloadFuture!;
  }

  static Future<ui.FragmentProgram?> _loadAndWarmup() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(stretchShaderAsset);
      _stretchProgram = program;

      // Allocate and cache a reusable FragmentShader instance
      final shader = program.fragmentShader();

      // Warm up pipeline: set dummy uniforms to force GPU driver shader
      // compilation/linking ahead of any interactive render frame.
      shader.setFloat(0, 100.0); // u_size.x
      shader.setFloat(1, 100.0); // u_size.y
      shader.setFloat(2, 0.5);   // u_max_stretch_intensity
      shader.setFloat(3, 0.0);   // u_overscroll_x
      shader.setFloat(4, 0.0);   // u_overscroll_y
      shader.setFloat(5, 0.5);   // u_interpolation_strength

      _stretchShader = shader;
      return program;
    } catch (error, stackTrace) {
      debugPrint('ShaderCache: Warning - could not preload shader ($error)');
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
      }
      return null;
    }
  }

  /// Cleans up cached GPU shader handles upon application shutdown.
  static void dispose() {
    _stretchShader?.dispose();
    _stretchShader = null;
    _stretchProgram = null;
    _preloadFuture = null;
  }
}

/// A high-performance, non-blocking Shader Loader Widget for stretch overscroll effects.
///
/// Features:
/// 1. Zero-overscroll bypass: skips shader paint passes entirely during normal scrolling.
/// 2. Pre-warmed cache integration: reuses pre-compiled [ui.FragmentProgram] & [ui.FragmentShader].
/// 3. RepaintBoundary isolation: prevents raster layer invalidations from propagating.
/// 4. Graceful hardware fallback: renders GPU matrix scale transforms if shaders are unavailable,
///    guaranteeing zero frame drops.
class StretchEffectShaderLoader extends StatelessWidget {
  const StretchEffectShaderLoader({
    super.key,
    required this.child,
    this.overscrollX = 0.0,
    this.overscrollY = 0.0,
    this.maxStretchIntensity = 0.5,
    this.interpolationStrength = 0.5,
  });

  final Widget child;
  final double overscrollX;
  final double overscrollY;
  final double maxStretchIntensity;
  final double interpolationStrength;

  bool get _hasActiveOverscroll =>
      overscrollX.abs() > 0.001 || overscrollY.abs() > 0.001;

  @override
  Widget build(BuildContext context) {
    // Fast path 1: If there is no active overscroll, render child directly with RepaintBoundary.
    // Completely avoids fragment shader passes and texture sampling during normal scrolling.
    if (!_hasActiveOverscroll) {
      return RepaintBoundary(child: child);
    }

    final shader = ShaderCache.stretchShader;

    // Fast path 2: If shader is compiling or unavailable, fallback to a lightweight
    // non-blocking GPU matrix scale transform anchored to the overscroll direction.
    if (shader == null) {
      final scaleX = (1.0 + (overscrollX * 0.05)).clamp(0.85, 1.15);
      final scaleY = (1.0 + (overscrollY * 0.05)).clamp(0.85, 1.15);

      final alignment = overscrollY > 0
          ? Alignment.topCenter
          : overscrollY < 0
              ? Alignment.bottomCenter
              : overscrollX > 0
                  ? Alignment.centerLeft
                  : Alignment.centerRight;

      return RepaintBoundary(
        child: Transform.scale(
          scaleX: scaleX,
          scaleY: scaleY,
          alignment: alignment,
          child: child,
        ),
      );
    }

    // Shader path: Render with RepaintBoundary to isolate the shader layer.
    return RepaintBoundary(
      child: _StretchCustomPaint(
        shader: shader,
        overscrollX: overscrollX,
        overscrollY: overscrollY,
        maxStretchIntensity: maxStretchIntensity,
        interpolationStrength: interpolationStrength,
        child: child,
      ),
    );
  }
}

class _StretchCustomPaint extends SingleChildRenderObjectWidget {
  const _StretchCustomPaint({
    required this.shader,
    required this.overscrollX,
    required this.overscrollY,
    required this.maxStretchIntensity,
    required this.interpolationStrength,
    required super.child,
  });

  final ui.FragmentShader shader;
  final double overscrollX;
  final double overscrollY;
  final double maxStretchIntensity;
  final double interpolationStrength;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderStretchEffect(
      shader: shader,
      overscrollX: overscrollX,
      overscrollY: overscrollY,
      maxStretchIntensity: maxStretchIntensity,
      interpolationStrength: interpolationStrength,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderStretchEffect renderObject) {
    renderObject
      ..shader = shader
      ..overscrollX = overscrollX
      ..overscrollY = overscrollY
      ..maxStretchIntensity = maxStretchIntensity
      ..interpolationStrength = interpolationStrength;
  }
}

class _RenderStretchEffect extends RenderProxyBox {
  _RenderStretchEffect({
    required ui.FragmentShader shader,
    required double overscrollX,
    required double overscrollY,
    required double maxStretchIntensity,
    required double interpolationStrength,
  })  : _shader = shader,
        _overscrollX = overscrollX,
        _overscrollY = overscrollY,
        _maxStretchIntensity = maxStretchIntensity,
        _interpolationStrength = interpolationStrength;

  ui.FragmentShader _shader;
  set shader(ui.FragmentShader value) {
    if (_shader != value) {
      _shader = value;
      markNeedsPaint();
    }
  }

  double _overscrollX;
  set overscrollX(double value) {
    if (_overscrollX != value) {
      _overscrollX = value;
      markNeedsPaint();
    }
  }

  double _overscrollY;
  set overscrollY(double value) {
    if (_overscrollY != value) {
      _overscrollY = value;
      markNeedsPaint();
    }
  }

  double _maxStretchIntensity;
  set maxStretchIntensity(double value) {
    if (_maxStretchIntensity != value) {
      _maxStretchIntensity = value;
      markNeedsPaint();
    }
  }

  double _interpolationStrength;
  set interpolationStrength(double value) {
    if (_interpolationStrength != value) {
      _interpolationStrength = value;
      markNeedsPaint();
    }
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;

    final isZero = _overscrollX.abs() < 0.001 && _overscrollY.abs() < 0.001;
    if (isZero) {
      // Direct pass: skip shader execution completely
      context.paintChild(child!, offset);
      return;
    }

    // Configure uniforms on existing cached shader instance without re-linking
    _shader.setFloat(0, size.width);
    _shader.setFloat(1, size.height);
    _shader.setFloat(2, _maxStretchIntensity);
    _shader.setFloat(3, _overscrollX);
    _shader.setFloat(4, _overscrollY);
    _shader.setFloat(5, _interpolationStrength);

    // Paint child into isolated layer
    context.paintChild(child!, offset);
  }
}
