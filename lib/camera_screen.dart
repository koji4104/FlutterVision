import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'dart:math';
import 'package:fluttervision/vision_adapter.dart';

// debug print
String Size2Str(Size s) {
  return "w=" + s.width.toInt().toString() + " h=" + s.height.toInt().toString();
}

class CameraScreen extends StatefulWidget {
  CameraScreen();
  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ResolutionPreset _resolutionPreset = ResolutionPreset.high;
  final ICON_SIZE=32.0;
  final ICON_RADIUS=24.0;
  final ICON_SPACE=50.0;

  final Color COLOR1 = Color.fromARGB(255, 0xCC, 0x99, 0xFF);
  final Color ICON_BACKCOLOR = Colors.black54;
  bool isAndroid = Platform.isAndroid;

  bool _loading = false;
  VisionAdapter? _vision;
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  Size _cameraSize = Size(100.0, 100.0);
  Size _screenSize = Size(100.0, 100.0);
  double _scale = 1.0;

  @override
  void initState() {
    _initCameraSync();
    _vision = VisionAdapter();
    super.initState();
  }

  Future<void> _initCameraSync() async {
    _cameras = await availableCameras();
    if (_cameras.length > 0) {
      _controller = CameraController(
        _cameras[0],
        _resolutionPreset,
        imageFormatGroup: ImageFormatGroup.yuv420);
      _controller!.initialize().then((_) {
        if (!mounted)
          return;
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    if (_controller != null) _controller!.dispose();
    if (_vision != null) _vision!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF006666),
      body: Stack(
        children: <Widget>[
          _cameraWidget(),

          // Painter(canvas)
          Center(
            child: Transform.scale(
              scale: _scale,
              child: AspectRatio(
                aspectRatio: 9.0/16.0,
                child: CustomPaint(
                  size: _cameraSize,
                  painter: VisionPainter(_vision!, _cameraSize, _screenSize)
                ),),),
          ),

          // Detect button
          Positioned(
            bottom: 30-10, left: 0, right: 0,
            child: CircleAvatar(
              backgroundColor: _loading ? Colors.red : ICON_BACKCOLOR,
              radius: ICON_RADIUS+10,
              child: IconButton(
                icon: Icon(Icons.play_circle_outline),
                iconSize: ICON_SIZE+20,
                color: Colors.white,
                onPressed: () => _detect(),
              ))
          ),

          // Camera Switch button
          Positioned(
            bottom: 30, right: 40,
            child: CircleAvatar(
              backgroundColor: ICON_BACKCOLOR,
              radius: ICON_RADIUS,
              child: IconButton(
                icon: Icon(Icons.flip_camera_ios_outlined),
                iconSize: ICON_SIZE,
                color: Colors.white,
                onPressed: () => _onCameraSwitch(),
              ))
          ),

          _typeButton(0, VisionType.FACE, Icons.face),
          _typeButton(1, VisionType.FACE2, Icons.face_unlock_outlined),
          _typeButton(2, VisionType.TEXT, Icons.font_download_outlined),
          _typeButton(3, VisionType.IMAGE, Icons.image_outlined),
          _typeButton(4, VisionType.BARCODE, Icons.qr_code),
          _typeButton(5, VisionType.POSE, Icons.accessibility),
          _typeButton(6, VisionType.TENSOR, Icons.star_border),
          //_typeButton(7, VisionType.INK, Icons.clear),
          //_typeButton(8, VisionType.OBJECT, Icons.clear),

      ]),
    );
  }

  /// Camera
  Widget _cameraWidget() {
    if (_controller == null)
      return Container();

    _screenSize = MediaQuery.of(context).size;
    _cameraSize = _controller!.value.previewSize!;

    double sw = _screenSize.width;
    double sh = _screenSize.height;
    _scale = sw>sh ? 16.0/9.0 : sw/sh*16.0/9.0;
    double cameraScale = sw>sh ? sh/sw*16.0/9.0 : sw/sh*16.0/9.0;
    double aspectRatio = sw>sh ? _controller!.value.aspectRatio : 1/_controller!.value.aspectRatio;

    if(isTest) {
      // portrait
      _scale = 1.1;
      cameraScale = sh/sw*16.0/9.0;
      aspectRatio = 1/_controller!.value.aspectRatio;
    }
    setState(() {});

    print('-- screen ' + Size2Str(_screenSize) + ' camera ' + Size2Str(_cameraSize));
    print('-- aspect ' + _controller!.value.aspectRatio.toStringAsFixed(2) +" scale="+ _scale.toString());

    return Center(
      child: Transform.scale(
        scale: cameraScale,
        child: OrientationCamera(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: CameraPreview(_controller!),
          ),),),
    );
  }

  /// _onCameraSwitch
  Future<void> _onCameraSwitch() async {
    final CameraDescription desc = (_controller!.description == _cameras[0]) ? _cameras[1] : _cameras[0];
    if (_controller != null) {
      await _controller!.dispose();
    }
    _controller = CameraController(desc, _resolutionPreset);
    _controller!.addListener(() {
      if (mounted) setState(() {});
    });
    try {
      await _controller!.initialize();
    } on CameraException catch (e) {
    }
    if (mounted) setState(() {});
  }

  /// Button
  Widget _typeButton(int index, VisionType type, IconData icon) {
    return Positioned(
      top: 30.0, left: 20+ICON_SPACE*index,
      child: CircleAvatar(
        backgroundColor: _vision!.type==type ? COLOR1 : ICON_BACKCOLOR,
        radius: ICON_RADIUS,
        child: IconButton(
          icon: Icon(icon),
          iconSize: ICON_SIZE,
          color: Colors.white,
          onPressed:() {
            setState(() { _vision!.type = type; });
          }
        ))
    );
  }

  /// Detect
  _detect() async {
    setState(() { _loading = true; });
    try {
      if (_controller!.value.isInitialized) {
        // /data/user/0/com.example.fluttervision/cache/CAP3945262564019216844.jpg'
        XFile file = await _controller!.takePicture();
        await _vision!.detect(File(file.path));
        _deleteCacheDir();
      }
    } on Exception catch (e) {
      print('-- Exception ' + e.toString());
    }
    setState(() { _loading = false; });
  }

  Future<void> _deleteCacheDir() async {
    final cacheDir = await getTemporaryDirectory();
    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
    }
  }
}

/// OrientationCamera
class OrientationCamera extends StatelessWidget {
  Widget? child;
  OrientationCamera({this.child});
  @override
  Widget build(BuildContext context) {
    return NativeDeviceOrientationReader(
        useSensor: true,
        builder: (context) {
          double angle = 0.0;
          if(isTest) {
            switch(NativeDeviceOrientationReader.orientation(context)) {
              case NativeDeviceOrientation.landscapeRight: angle=pi; break;
              case NativeDeviceOrientation.landscapeLeft: angle=0.0; break;
              case NativeDeviceOrientation.portraitDown: angle=pi*1/2; break;
              default: angle = angle=pi*3/2; break;
            }
          }
          return Transform.rotate(angle: angle, child: child);
        }
    );
  }
}
