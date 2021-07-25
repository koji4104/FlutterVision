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
  CameraScreen({Key key}) : super(key: key);
  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ResolutionPreset _resolutionPreset = ResolutionPreset.high;
  final ICON_RADIUS=30.0;
  final ICON_SIZE=40.0;
  final Color COLOR1 = Color.fromARGB(255, 0xCC, 0x99, 0xFF);

  bool isAndroid = Platform.isAndroid;

  bool _loading = false;
  VisionAdapter _vision;
  CameraController _controller = null;
  List<CameraDescription> _cameras;
  Size _cameraSize = Size(100.0, 100.0);
  Size _screenSize = Size(100.0, 100.0);
  double _scale = 1.0;
  double _angle = 1.0;

  @override
  void initState() {
    _initCameraSync();
    _vision = VisionAdapter();
    super.initState();
  }

  Future<void> _initCameraSync() async {
    _cameras = await availableCameras();
    if (_cameras.length > 0) {
      _controller = CameraController(_cameras[0], _resolutionPreset);
      _controller.initialize().then((_) {
        if (!mounted)
          return;
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    if (_controller != null) _controller?.dispose();
    if (_vision != null) _vision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF000000),
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
                    painter: VisionPainter(_vision, _cameraSize, _screenSize)
                    ),),),
          ),

          // Detect button
          Positioned(
            bottom: 30, left: 0, right: 0,
            child: CircleAvatar(
              backgroundColor: _loading ? Colors.red : Colors.black54,
              radius: ICON_RADIUS,
              child: IconButton(
                icon: Icon(Icons.play_circle_outline),
                iconSize: ICON_SIZE,
                color: Colors.white,
                onPressed: () => _detect(),
              ))
          ),

          // Camera Switch button
          Positioned(
            bottom: 30, right: 40,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              radius: ICON_RADIUS,
              child: IconButton(
                icon: Icon(Icons.flip_camera_ios),
                iconSize: ICON_SIZE,
                color: Colors.white,
                onPressed: () => _onCameraSwitch(),
              ))
          ),

          _typeButton(
            top: 30, left: 30+70.0*0,
            icon: Icon(Icons.face),
            type: VisionType.FACE,
          ),
          _typeButton(
            top: 30, left: 30+70.0*1,
            icon: Icon(Icons.face_unlock_outlined),
            type: VisionType.FACE2,
          ),
          _typeButton(
            top: 30, left: 30+70.0*2,
            icon: Icon(Icons.font_download_outlined),
            type: VisionType.TEXT,
          ),
          _typeButton(
            top: 30, left: 30+70.0*3,
            icon: Icon(Icons.image),
            type: VisionType.IMAGE,
          ),
          _typeButton(
            top: 30, left: 30+70.0*4,
            icon: Icon(Icons.qr_code),
            type: VisionType.BARCODE,
          ),
      ]),
    );
  }

  /// Camera
  Widget _cameraWidget() {
    if (_controller == null)
      return Container();

    _screenSize = MediaQuery.of(context).size;
    _cameraSize = _controller.value.previewSize;
    _scale = 1.0;
    if(_screenSize.width>_screenSize.height)
      _scale = _screenSize.width/_screenSize.height;

    if(_screenSize.width>_screenSize.height)
      _scale*=_screenSize.height/_screenSize.width*16/9;
    else
      _scale*=_screenSize.width/_screenSize.height*16/9;
    //_scale*=1.1;

    setState(() {});

    print('-- screen ' + Size2Str(_screenSize) + ' camera ' + Size2Str(_cameraSize));
    print('-- aspect ' + _controller.value.aspectRatio.toString() +" scale="+ _scale.toString());

    return Center(
      child: Transform.scale(
        scale: _scale,
        child: OrientationCamera(
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: CameraPreview(_controller),
          ),),),
    );
  }

  /// _onCameraSwitch
  Future<void> _onCameraSwitch() async {
    final CameraDescription desc = (_controller.description == _cameras[0]) ? _cameras[1] : _cameras[0];
    if (_controller != null) {
      await _controller.dispose();
    }
    _controller = CameraController(desc, _resolutionPreset);
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    try {
      await _controller.initialize();
    } on CameraException catch (e) {
    }
    if (mounted) setState(() {});
  }

  /// Button
  Widget _typeButton({Icon icon, VisionType type,
    double left=null, double top=null, double right=null, double bottom=null}) {
    return Positioned(
      left: left, top:top, right:right, bottom:bottom,
      child: CircleAvatar(
        backgroundColor: _vision.type==type ? COLOR1 : Colors.black45,
        radius: ICON_RADIUS,
        child: IconButton(
          icon: icon,
          iconSize: ICON_SIZE,
          color: Colors.white,
          onPressed:() {
            setState(() { _vision.type = type; });
          }
        ))
    );
  }

  /// Detect
  _detect() async {
    setState(() {
      _loading = true;
    });
    try {
      if (_controller.value.isInitialized) {
        final Directory extDir = await getApplicationDocumentsDirectory();
        final String dirPath = '${extDir.path}/media';
        await Directory(dirPath).create(recursive: true);
        final String filePath = '$dirPath/1.jpeg';

        print("-- file=" + filePath);

        if (await File(filePath).exists())
          File(filePath).deleteSync();
        await _controller.takePicture(filePath);
        await _vision.detect(File(filePath));
      }
    } on Exception catch (e) {
      print('-- Exception ' + e.toString());
    }
    setState(() {
      _loading = false;
    });
  }
}

/// OrientationCamera
class OrientationCamera extends StatelessWidget {
  Widget child;
  OrientationCamera({this.child});
  @override
  Widget build(BuildContext context) {
    return NativeDeviceOrientationReader(
        useSensor: true,
        builder: (context) {
          double angle = 0.0;
          switch(NativeDeviceOrientationReader.orientation(context)) {
            case NativeDeviceOrientation.landscapeRight: angle=pi*1/2; break;
            case NativeDeviceOrientation.landscapeLeft: angle=pi*3/2; break;
            case NativeDeviceOrientation.portraitDown: angle=pi*2/2; break;
            default: break;
          }
          return Transform.rotate(angle: angle, child: child);
        }
    );
  }
}

/// OrientationWidget (no use)
class OrientationWidget extends StatelessWidget {
  Widget child;
  OrientationWidget({this.child});

  @override
  Widget build(BuildContext context) {
    return NativeDeviceOrientationReader(
        useSensor: true,
        builder: (context) {
          double angle = 0.0;
          switch(NativeDeviceOrientationReader.orientation(context)) {
            case NativeDeviceOrientation.landscapeRight: angle=pi*3/2; break;
            case NativeDeviceOrientation.landscapeLeft: angle=pi*1/2; break;
            case NativeDeviceOrientation.portraitDown: angle=pi*2/2; break;
            default: break;
          }
          return Transform.rotate(angle: angle, child: child);
        }
    );
  }
}
