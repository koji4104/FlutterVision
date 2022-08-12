import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'vision_adapter.dart';
import 'provider.dart';

final cameraScreenProvider = ChangeNotifierProvider((ref) => ChangeNotifier());
class CameraScreen extends ConsumerWidget {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ResolutionPreset _resolutionPreset = ResolutionPreset.high; //high=1280x720
  final ICON_SIZE=34.0;
  final ICON_RADIUS=34.0-8.0;
  final ICON_SPACE=58.0;

  final Color ICON_COLOR = Color(0xFFA0A0A0);
  final Color ICON_BACKCOLOR = Color(0x60000000);
  final Color ICON_COLOR1 = Color(0xFF000000); // selected
  final Color ICON_BACKCOLOR1 = Color(0xFFe0e0e0); // selected

  File _pictureFile = File("");
  bool _isDispPicture = false;

  bool _loading = false;
  late VisionAdapter _vision;
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  Size _cameraSize = Size(100.0, 100.0);
  Size _screenSize = Size(100.0, 100.0);
  double _scale = 1.0;
  double _aspect = 1.0;
  bool bInit = false;
  late WidgetRef _ref;

  CameraScreen(){
    _vision = VisionAdapter();
  }

  void init(BuildContext context, WidgetRef ref) {
    if(bInit==false) {
      _initCameraSync();
      bInit=true;
    }
  }

  @override
  void dispose(){
    if (_controller != null) _controller!.dispose();
    _vision.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref){
    this._ref = ref;
    Future.delayed(Duration.zero, () => init(context,ref));
    _isDispPicture = ref.watch(isDispPictureProvider);
    _vision.type = ref.watch(visionTypeProvider);
    ref.watch(cameraScreenProvider);
    _loading = ref.watch(isLoadingProvider);

    return Scaffold(
      backgroundColor: Color(0xFF006666),
      body: Stack(
        children: <Widget>[
          // Display picture or camera
          _isDispPicture ?
            Center(
              child: Transform.scale(
                scale: _scale,
                child: AspectRatio(
                  aspectRatio: _aspect,
                  child: _isDispPicture ? Image.file(_pictureFile) : null
                ),
              ),
            ) : _cameraWidget(context),

          // Painter (canvas)
          Center(
            child: Transform.scale(
              scale: _scale,
              child: AspectRatio(
                aspectRatio: _aspect,
                child: CustomPaint(
                  size: _cameraSize,
                  painter: VisionPainter(_vision, _cameraSize, _screenSize)
                ),
              ),
            ),
          ),

          // Detect button
          Positioned(
            bottom: 20, left: 0, right: 0,
            child: myIconButton(
              icon: Icons.play_circle_outline,
              backgroundColor: _loading ? Colors.red : ICON_BACKCOLOR,
              onPressed: () => _onDetect(),
            ),
          ),

          // Picture button
          Positioned(
            bottom: 20, left: 20,
            child: myIconButton(
              icon: Icons.pause_outlined,
              color: _isDispPicture ? ICON_COLOR1 : ICON_COLOR,
              backgroundColor: _isDispPicture ? ICON_BACKCOLOR1 : ICON_BACKCOLOR,
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
          typeButton(6, VisionType.OBJECT, Icons.crop_square),
          typeButton(7, VisionType.SELFIE, Icons.face),
          typeButton(8, VisionType.TENSOR, Icons.looks_one_outlined),
          typeButton(9, VisionType.TENSOR2, Icons.looks_two_outlined),
          //typeButton(10, VisionType.INK, Icons.clear),
      ]),
    );
  }

  Future<void> _initCameraSync() async {
    _cameras = await availableCameras();
    if (_cameras.length > 0){
      _controller = CameraController(
          _cameras[0],
          _resolutionPreset,
          imageFormatGroup: ImageFormatGroup.yuv420);
      _controller!.initialize().then((_) {
        _ref.read(cameraScreenProvider).notifyListeners();
      });
    } else {
      print('-- _cameras.length==0');
    }
  }

  /// Camera
  Widget _cameraWidget(BuildContext context) {
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

  /// CameraSwitch
  Future<void> _onCameraSwitch() async {
    final CameraDescription desc = (_controller!.description == _cameras[0]) ? _cameras[1] : _cameras[0];
    if(_controller != null){
      await _controller!.dispose();
    }
    _controller = CameraController(desc, _resolutionPreset);
    try {
      _controller!.initialize().then((_) {
        _ref.read(cameraScreenProvider).notifyListeners();
      });
    } on CameraException catch (e) {
    }
  }

  /// Display picture or camera
  /// Display the picture taken at the time of detection.
  Future<void> _onDispPicture() async {
    bool isDisp = _ref.read(isDispPictureProvider);
    if(isDisp){
      _ref.read(isDispPictureProvider.state).state = false;
    } else if(await _pictureFile.exists()) {
      _ref.read(isDispPictureProvider.state).state = true;
    }
  }

  /// Detect
  /// take a picture and pass the picture to MlKit.
  _onDetect() async {
    _ref.read(isLoadingProvider.state).state = true;
    try {
      if (_controller!.value.isInitialized) {
        await _deleteCacheDir();
        XFile file = await _controller!.takePicture();
        this._pictureFile = File(file.path);
        await _vision.detect(_pictureFile);
      }
    } on Exception catch (e) {
      print('-- Exception ' + e.toString());
    }
    _ref.read(isLoadingProvider.state).state = false;
  }

  /// Delete the garbage data of the picture.
  Future<void> _deleteCacheDir() async {
    final cacheDir = await getTemporaryDirectory();
    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
    }
  }

  /// Button
  Widget typeButton(int index, VisionType type, IconData icon){
    double top = _aspect>1.0 ? 30.0 : index<6 ? 30.0 : 30.0+ICON_SPACE;
    double left = _aspect>1.0 ? 20 + ICON_SPACE*index : 20 + ICON_SPACE*(index%6);
    bool sel = _vision.type==type;
    return Positioned(
      top: top, left: left,
      child: myIconButton(
        icon: icon,
        color: sel ? ICON_COLOR1 : ICON_COLOR,
        backgroundColor: sel ? ICON_BACKCOLOR1 : ICON_BACKCOLOR,
        onPressed:(){
          _ref.read(visionTypeProvider.state).state = type;
        },
      )
    );
  }

  /// myIconButton
  Widget myIconButton({IconData? icon, Color? color, Color? backgroundColor, Function()? onPressed}){
    return CircleAvatar(
      backgroundColor: backgroundColor,
      radius: ICON_RADIUS,
      child: IconButton(
        icon: Icon(icon),
        iconSize: ICON_SIZE,
        color: color ?? Colors.white,
        onPressed: onPressed,
      )
    );
  }
}
