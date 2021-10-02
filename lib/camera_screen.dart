import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttervision/vision_adapter.dart';

class CameraScreen extends StatefulWidget {
  CameraScreen();
  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ResolutionPreset _resolutionPreset = ResolutionPreset.high; //high=1280x720
  final ICON_SIZE=34.0;
  final ICON_RADIUS=34.0-8.0;
  final ICON_SPACE=58.0;

  final Color COLOR1 = Color.fromARGB(255, 0xCC, 0x99, 0xFF);
  final Color ICON_BACKCOLOR = Colors.black54;

  File _pictureFile = File("");
  bool _isDispPicture = false;

  bool _loading = false;
  VisionAdapter? _vision;
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  Size _cameraSize = Size(100.0, 100.0);
  Size _screenSize = Size(100.0, 100.0);
  double _scale = 1.0;
  double _aspect = 1.0;

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
          _isDispPicture ? Center(child:null) : _cameraWidget(),

          // Disp Picture
          Center(
            child: Transform.scale(
              scale: _scale,
              child: AspectRatio(
                aspectRatio: _aspect,
                child: _isDispPicture ? Image.file(_pictureFile) : null
                ),),
          ),

          // Painter(canvas)
          Center(
            child: Transform.scale(
              scale: _scale,
              child: AspectRatio(
                aspectRatio: _aspect,
                child: CustomPaint(
                  size: _cameraSize,
                  painter: VisionPainter(_vision!, _cameraSize, _screenSize)
                ),),),
          ),

          // Detect button
          Positioned(
            bottom: 20, left: 0, right: 0,
            child: myIconButton(
              icon: Icons.play_circle_outline,
              backgroundColor: _loading ? Colors.red : ICON_BACKCOLOR,
              onPressed: () => _detect(),
            ),
          ),

          // Picture button
          Positioned(
            bottom: 20, left: 20,
            child: myIconButton(
              icon: Icons.pause_outlined,
              backgroundColor: _isDispPicture ? COLOR1 : ICON_BACKCOLOR,
              onPressed: () => _onDispPicture(),
            ),
          ),

          // Camera Switch button
          Positioned(
            bottom: 20, right: 20,
            child: myIconButton(
              icon: Icons.flip_camera_ios_outlined,
              backgroundColor: ICON_BACKCOLOR,
              onPressed: () => _onCameraSwitch(),
            ),
          ),

          typeButton(0, VisionType.FACE, Icons.face),
          typeButton(1, VisionType.FACE2, Icons.face_unlock_outlined),
          typeButton(2, VisionType.TEXT, Icons.font_download_outlined),
          typeButton(3, VisionType.IMAGE, Icons.image_outlined),
          typeButton(4, VisionType.BARCODE, Icons.qr_code),
          typeButton(5, VisionType.POSE, Icons.accessibility),
          typeButton(6, VisionType.TENSOR, Icons.looks_one_outlined),
          typeButton(7, VisionType.TENSOR2, Icons.looks_two_outlined),
          //typeButton(8, VisionType.INK, Icons.clear),
          //typeButton(9, VisionType.OBJECT, Icons.clear),
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
    double dw = sw>sh ? sw : sh;
    double dh = sw>sh ? sh : sw;
    _aspect = sw>sh ? _controller!.value.aspectRatio : 1/_controller!.value.aspectRatio;

    // 16:10 (Up-down black) or 17:9 (Left-right black)
    _scale = dw/dh < 16.0/9.0 ? dh/dw * 16.0/9.0 : dw/dh * 9.0/16.0;

    setState(() {});
    print('-- screen=${sw.toInt()}x${sh.toInt()}'
        ' camera=${_cameraSize.width.toInt()}x${_cameraSize.height.toInt()}'
        ' aspect=${_aspect.toStringAsFixed(2)}'
        ' scale=${_scale.toStringAsFixed(2)}');

    return Center(
      child: Transform.scale(
        scale: _scale,
        child: AspectRatio(
          aspectRatio: _aspect,
          child: CameraPreview(_controller!),
        ),),
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

  /// _onDispPicture()
  Future<void> _onDispPicture() async {
    if(_isDispPicture) {
      setState((){ _isDispPicture = false; });
    } else if(await _pictureFile.exists()) {
      setState((){ _isDispPicture = true; });
    }
  }

  /// Detect
  _detect() async {
    setState(() { _loading = true; });
    try {
      if (_controller!.value.isInitialized) {
        await _deleteCacheDir();
        XFile file = await _controller!.takePicture();
        setState(() { _pictureFile = File(file.path); });
        await _vision!.detect(_pictureFile);
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

  /// Button
  Widget typeButton(int index, VisionType type, IconData icon) {
    double top = _aspect>1.0 ? 30.0 : index<6 ? 30.0 : 30.0+ICON_SPACE;
    double left = _aspect>1.0 ? 20 + ICON_SPACE*index : 20 + ICON_SPACE*(index%6);
    return Positioned(
      top: top, left: left,
      child: myIconButton(
        icon: icon,
        backgroundColor: _vision!.type==type ? COLOR1 : ICON_BACKCOLOR,
        onPressed: () => setState(() { _vision!.type = type; }),
      )
    );
  }

  /// myIconButton
  Widget myIconButton({IconData? icon, Color? backgroundColor, Function()? onPressed}) {
    return CircleAvatar(
      backgroundColor: backgroundColor,
      radius: ICON_RADIUS,
      child: IconButton(
        icon: Icon(icon),
        iconSize: ICON_SIZE,
        color: Colors.white,
        onPressed: onPressed,
      )
    );
  }
}
