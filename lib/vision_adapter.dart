import 'dart:io';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:flutter/material.dart';
import "dart:async";
import "package:fluttervision/tflite_adapter.dart";
import "package:image/image.dart" as imglib;
import 'package:path_provider/path_provider.dart';

bool isTest = false;

enum VisionType {
  FACE,
  FACE2,
  TEXT,
  IMAGE,
  BARCODE,
  TENSOR,
  TENSOR2,
  POSE,
  INK,
  OBJECT,
}

class VisionAdapter {
  VisionType type = VisionType.TENSOR2;

  List<Face> faces = [];
  RecognisedText? text = null;
  List<ImageLabel> labels = [];
  List<Barcode> barcodes = [];
  List<TfResult> results = [];
  List<Pose> poses = [];

  FaceDetector? _faceDetector;
  TextDetector ? _textDetector;
  ImageLabeler? _imageLabeler;
  BarcodeScanner? _barcodeScanner;
  TfliteAdapter? _tflite;
  PoseDetector? _poseDetector;
  DigitalInkRecogniser? _digitalInkRecogniser;
  ObjectDetector? _objectDetector;
  LanguageModelManager? _languageModelManager;
  RemoteModelManager? _remoteModelManager;

  VisionAdapter(){
    if(_faceDetector==null){
      _faceDetector = GoogleMlKit.vision.faceDetector(
        FaceDetectorOptions(
          enableClassification: true,
          enableLandmarks: true,
          enableContours: true,
          enableTracking: false)
      );
    }
    if(_textDetector==null){
      _textDetector = GoogleMlKit.vision.textDetector();
    }
    if(_imageLabeler==null){
      _imageLabeler = GoogleMlKit.vision.imageLabeler(
          ImageLabelerOptions(confidenceThreshold: 0.5)
      );
    }
    if(_barcodeScanner==null){
      _barcodeScanner = GoogleMlKit.vision.barcodeScanner();
    }
    if(_poseDetector==null){
      _poseDetector = GoogleMlKit.vision.poseDetector(
        poseDetectorOptions:PoseDetectorOptions(
          model: PoseDetectionModel.base, mode: PoseDetectionMode.singleImage)
      );
    }
    if (_tflite == null) {
      _tflite = TfliteAdapter();
    }
  }

  void dispose() {
    if (_faceDetector != null) _faceDetector!.close();
    if (_textDetector != null) _textDetector!.close();
    if (_imageLabeler != null) _imageLabeler!.close();
    if (_barcodeScanner != null) _barcodeScanner!.close();
    if (_poseDetector != null) _poseDetector!.close();
    if (_digitalInkRecogniser != null) _digitalInkRecogniser!.close();
    if (_objectDetector != null) _objectDetector!.close();
    //if (_languageModelManager != null) _languageModelManager!.close();
    //if (_remoteModelManager != null) _remoteModelManager!.close();
  }

  Future<void> detect(File imagefile) async {
    try {
      if (await imagefile.exists()) {
        print('-- START');
        final inputImage = InputImage.fromFile(imagefile);

        if(type==VisionType.FACE || type==VisionType.FACE2) {
          faces = await _faceDetector!.processImage(inputImage);

        } else if(type==VisionType.TEXT) {
          text = await _textDetector!.processImage(inputImage);
        
        } else if(type==VisionType.IMAGE) {
          labels = await _imageLabeler!.processImage(inputImage);

        } else if(type==VisionType.BARCODE) {
          barcodes = await _barcodeScanner!.processImage(inputImage);

        } else if(type==VisionType.POSE) {
          poses = await _poseDetector!.processImage(inputImage);

        } else if(type==VisionType.INK) {

        } else if(type==VisionType.OBJECT) {

        } else if(type==VisionType.TENSOR) {
          results.clear();
          TfResult res = await _tflite!.detect(imagefile);
          results.add(res);

        } else if(type==VisionType.TENSOR2) {
          List<Rect> rects = [];
          faces = await _faceDetector!.processImage(inputImage);
          for (Face f in faces) {
            rects.add(f.boundingBox);
          }
          print('-- face='+faces.length.toString());

          results.clear();
          final File cropfile = File('${(await getTemporaryDirectory()).path}/crop.jpg');
          final byteData = imagefile.readAsBytesSync();
          imglib.Image? srcimg = imglib.decodeImage(byteData);

          for (Rect r1 in rects) {
            r1 = r1.inflate(4.0);
            imglib.Image crop = imglib.copyCrop(srcimg!, r1.left.toInt(), r1.top.toInt(), r1.width.toInt(), r1.height.toInt());
            await cropfile.writeAsBytes(imglib.encodeJpg(crop));
            TfResult res = await _tflite!.detect(cropfile);
            res.rect = r1;
            if(res.outputs.length>0)
              results.add(res);
          }
        }
        print('-- END');
      }
    } on Exception catch (e) {
      print('-- Exception ' + e.toString());
    }
  }
}

class VisionPainter extends CustomPainter {
  final Color COLOR1 = Colors.greenAccent;
  VisionAdapter vision;
  Size cameraSize;
  Size screenSize;
  VisionPainter(this.vision, this.cameraSize, this.screenSize);

  double landx = 0.0;
  Paint _paint = Paint();
  late Canvas _canvas;
  double _textTop = 240.0;
  double _textLeft = 30.0;

  double _fontSize = 32;
  double _fontHeight = 38;
  double _pad = 30;

  @override
  void paint(Canvas canvas, Size size) { 
    _canvas = canvas;
    _paint.style = PaintingStyle.stroke;
    _paint.color = COLOR1;
    _paint.strokeWidth = 2.0;

    double sw = screenSize.width;
    double sh = screenSize.height;
    double dw = sw>sh ? sw : sh;
    double dh = sw>sh ? sh : sw;

    if(isTest)
      drawRect(Rect.fromLTWH(size.width/2-10, size.height/2-10, 20, 20));

    // 16:10 (Up-down black) or 17:9 (Left-right black)
    double scale = dw/dh < 16.0/9.0 ? dw / cameraSize.width : dh / cameraSize.height;
    _canvas.scale(scale);

    if(size.width>size.height && dw/dh < 16.0/9.0){
      landx = (screenSize.height - size.height);
    } else if(sw<sh && dw/dh > 16.0/9.0) {
      landx = (screenSize.height - size.height)/2;
    }

    //landx = 0;
    if(size.width>size.height){
      _textTop = 200;
      _textLeft = 40;
    } else {
      _textTop = 300;
      _textLeft = 80;
    }

    if(isTest) {
      print('-- canvas size=${size.width.toInt()}x${size.height.toInt()}'
          ' screen ${screenSize.width.toInt()}x${screenSize.height.toInt()}'
          ' scale ${scale.toStringAsFixed(2)}');
      _test(_canvas);
    }

    if (vision == null) {
      print("-- vision null");
      return;
    }

    if (vision.type == VisionType.FACE) {
      if (vision.faces.length == 0) {
        return;
      }
      for (Face f in vision.faces) {
        Rect r = f.boundingBox;
        drawRect(r);
        if (f.smilingProbability != null) {
          drawText(Offset(r.left, r.top), (f.smilingProbability! * 100.0).toInt().toString(), 36);
        }

        _paint.color = Colors.red;
        drawLandmark(f, FaceLandmarkType.leftEye);
        drawLandmark(f, FaceLandmarkType.rightEye);

        _paint.color = Colors.orange;
        drawLandmark(f, FaceLandmarkType.noseBase);

        _paint.color = COLOR1;
        drawLandmark(f, FaceLandmarkType.bottomMouth);
        drawLandmark(f, FaceLandmarkType.leftMouth);
        drawLandmark(f, FaceLandmarkType.rightMouth);

        drawLandmark(f, FaceLandmarkType.leftEar);
        drawLandmark(f, FaceLandmarkType.rightEar);
        drawLandmark(f, FaceLandmarkType.leftCheek);
        drawLandmark(f, FaceLandmarkType.rightCheek);
      }

    } else if (vision.type == VisionType.FACE2) {
      if (vision.faces.length == 0) {
        return;
      }
      for (Face f in vision.faces) {
        Rect r = f.boundingBox;
        drawRect(r);

        drawContour(f, FaceContourType.leftEye);
        drawContour(f, FaceContourType.rightEye);

        drawContour(f, FaceContourType.leftEyebrowBottom);
        drawContour(f, FaceContourType.leftEyebrowTop);
        drawContour(f, FaceContourType.rightEyebrowBottom);
        drawContour(f, FaceContourType.leftEyebrowTop);

        drawContour(f, FaceContourType.face);

        drawContour(f, FaceContourType.lowerLipBottom);
        drawContour(f, FaceContourType.lowerLipTop);
        drawContour(f, FaceContourType.upperLipBottom);
        drawContour(f, FaceContourType.upperLipTop);

        drawContour(f, FaceContourType.noseBottom);
        drawContour(f, FaceContourType.noseBridge);
      }

    } else if (vision.type == VisionType.TEXT) {
      if (vision.text == null)
        return;
      for (TextBlock b in vision.text!.blocks) {
        drawRect(b.rect);
        drawText(Offset(b.rect.left, b.rect.top), b.text, _fontSize);
      }

    } else if (vision.type == VisionType.IMAGE) {
      if (vision.labels == null || vision.labels.length == 0)
        return;
      int i=0;
      for (ImageLabel label in vision.labels) {
        String s = (label.confidence*100.0).toInt().toString() +" "+ label.label;
        drawText(Offset(landx+_pad, _textTop+_fontHeight*(i++)), s, _fontSize);
      }

    } else if (vision.type == VisionType.BARCODE) {
      if (vision.barcodes == null || vision.barcodes.length == 0)
        return;
      int i=0;
      for (Barcode b in vision.barcodes) {
        _paint.strokeWidth = 3.0;
        drawRect(b.value.boundingBox!);
        String s = b.value.displayValue!;
        drawText(Offset(_textLeft, _textTop + _fontHeight * (i++)), s, _fontSize);
      }
    
    } else if (vision.type == VisionType.TENSOR) {
      if (vision.results.length == 0)
        return;
      int i=0;
      for (TfResult res in vision.results) {
        for (TfOutput out in res.outputs) {
          String s = (out.score).toInt().toString() + " " + out.label;
          drawText(Offset(_textLeft, _textTop + _fontHeight * (i++)), s, _fontSize);
          if (i > 5) break;
        }
      }

    } else if (vision.type == VisionType.TENSOR2) {
      if (vision.results.length == 0)
        return;
      for (TfResult res in vision.results) {
        drawRect(res.rect);
        String s = (res.outputs[0].score).toInt().toString() + " " + res.outputs[0].label;
        drawText(Offset(res.rect.left, res.rect.top - _fontHeight), s, _fontSize);
      }

    } else if (vision.type == VisionType.POSE) {
      if (vision.poses.length == 0)
        return;
      vision.poses.forEach((pose) {
        Map<PoseLandmarkType, PoseLandmark> lms = pose.landmarks;

        _paint.color = Colors.blueAccent;
        drawPoseLandmark(lms, PoseLandmarkType.leftHip);
        drawPoseLandmark(lms, PoseLandmarkType.leftKnee);
        drawPoseLandmark(lms, PoseLandmarkType.leftAnkle);
        drawPoseLandmark(lms, PoseLandmarkType.leftHeel);
        drawPoseLandmark(lms, PoseLandmarkType.leftFootIndex);

        drawPoseLine(lms, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
        drawPoseLine(lms, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
        drawPoseLine(lms, PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel);
        drawPoseLine(lms, PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex);

        drawPoseLandmark(lms, PoseLandmarkType.leftShoulder);
        drawPoseLandmark(lms, PoseLandmarkType.leftElbow);
        drawPoseLandmark(lms, PoseLandmarkType.leftWrist);

        drawPoseLine(lms, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
        drawPoseLine(lms, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);

        drawPoseLandmark(lms, PoseLandmarkType.leftThumb);
        drawPoseLandmark(lms, PoseLandmarkType.leftIndex);
        drawPoseLandmark(lms, PoseLandmarkType.leftPinky);

        drawPoseLine(lms, PoseLandmarkType.leftWrist, PoseLandmarkType.leftThumb);
        drawPoseLine(lms, PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex);
        drawPoseLine(lms, PoseLandmarkType.leftWrist, PoseLandmarkType.leftPinky);

        _paint.color = Colors.greenAccent;
        drawPoseLandmark(lms, PoseLandmarkType.rightHip);
        drawPoseLandmark(lms, PoseLandmarkType.rightKnee);
        drawPoseLandmark(lms, PoseLandmarkType.rightAnkle);
        drawPoseLandmark(lms, PoseLandmarkType.rightHeel);
        drawPoseLandmark(lms, PoseLandmarkType.rightFootIndex);

        drawPoseLine(lms, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
        drawPoseLine(lms, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
        drawPoseLine(lms, PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel);
        drawPoseLine(lms, PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex);

        drawPoseLandmark(lms, PoseLandmarkType.rightShoulder);
        drawPoseLandmark(lms, PoseLandmarkType.rightElbow);
        drawPoseLandmark(lms, PoseLandmarkType.rightWrist);

        drawPoseLine(lms, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
        drawPoseLine(lms, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

        drawPoseLandmark(lms, PoseLandmarkType.rightThumb);
        drawPoseLandmark(lms, PoseLandmarkType.rightIndex);
        drawPoseLandmark(lms, PoseLandmarkType.rightPinky);

        drawPoseLine(lms, PoseLandmarkType.rightWrist, PoseLandmarkType.rightThumb);
        drawPoseLine(lms, PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex);
        drawPoseLine(lms, PoseLandmarkType.rightWrist, PoseLandmarkType.rightPinky);

        _paint.color = Colors.red;
        //drawPoseLandmark(lms, PoseLandmarkType.leftEar);
        drawPoseLandmark(lms, PoseLandmarkType.leftEye);
        //drawPoseLandmark(lms, PoseLandmarkType.leftEyeInner);
        //drawPoseLandmark(lms, PoseLandmarkType.leftEyeOuter);

        //drawPoseLandmark(lms, PoseLandmarkType.rightEar);
        drawPoseLandmark(lms, PoseLandmarkType.rightEye);
        //drawPoseLandmark(lms, PoseLandmarkType.rightEyeInner);
        //drawPoseLandmark(lms, PoseLandmarkType.rightEyeOuter);

        _paint.color = Colors.orange;
        drawPoseLandmark(lms, PoseLandmarkType.nose);

        _paint.color = Colors.orange;
        drawPoseLandmark(lms, PoseLandmarkType.rightMouth);
        drawPoseLandmark(lms, PoseLandmarkType.leftMouth);
        drawPoseLine(lms, PoseLandmarkType.rightMouth, PoseLandmarkType.leftMouth);

      });        
    }
  }

  /// Rect
  drawRect(Rect r) {
    _paint.style = PaintingStyle.stroke;
    _canvas.drawRect(r, _paint);
  }

  /// Face Contour
  drawContour(Face f, FaceContourType type) {
    FaceContour? c = f.getContour(type);
    if(c != null) {
      var path = Path();
      c.positionsList.asMap().forEach((i, pos) {
        i==0 ? path.moveTo(pos.dx, pos.dy) : path.lineTo(pos.dx, pos.dy);
      });
      _paint.style = PaintingStyle.stroke;
      _canvas.drawPath(path, _paint);
    }
  }

  /// Face landmark
  drawLandmark(Face f, FaceLandmarkType type) {
    FaceLandmark? l = f.getLandmark(type);
    if(l != null) {
      _paint.style = PaintingStyle.fill;
      _canvas.drawCircle(l.position, 6.0, _paint);
    }
  }

  /// Pose
  drawPoseLandmark(Map<PoseLandmarkType, PoseLandmark> landmarks, PoseLandmarkType type) {
    PoseLandmark? m = landmarks[type];
    if(m != null) {
      _paint.style = PaintingStyle.fill;
      _canvas.drawCircle(Offset(m.x, m.y), 6, _paint);
    }
  }

  /// Pose line (moveTo lineTo)
  drawPoseLine(Map<PoseLandmarkType, PoseLandmark> landmarks, PoseLandmarkType type1, PoseLandmarkType type2) {
    PoseLandmark? m1 = landmarks[type1];
    PoseLandmark? m2 = landmarks[type2];
    if(m1 != null && m2 != null) {
      _paint.style = PaintingStyle.stroke;
      _canvas.drawLine(Offset(m1.x, m1.y), Offset(m2.x, m2.y), _paint);
    }
  }

  /// Draw text
  drawText(Offset offset, String text, double size) {
    TextSpan span = TextSpan(
      text: " "+text+" ",
      style: TextStyle(color: COLOR1, backgroundColor: Colors.black54, fontSize: size),
    );
    final textPainter = TextPainter(
      text: span,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(_canvas, offset);  
  }

  /// Test
  _test(Canvas canvas) {
    final Paint p = Paint();
    p.style = PaintingStyle.stroke;
    p.color = Colors.green;
    p.strokeWidth = 3.0;
    
    double cw = cameraSize.width;
    double ch = cameraSize.height;

    canvas.drawRect(Rect.fromLTWH(0, 0, 100, 100), p);

    if(screenSize.width>screenSize.height){
      canvas.drawLine(Offset(cw / 2, 0), Offset(cw / 2, ch), p);
      canvas.drawLine(Offset(0, ch / 2), Offset(cw, ch / 2), p);
      canvas.drawRect(Rect.fromLTWH(1, 1, cw-2.0, ch-2.0), p);
    } else {
      canvas.drawLine(Offset(0, cw / 2), Offset(ch, cw / 2), p);
      canvas.drawLine(Offset(ch / 2, 0), Offset(ch / 2, cw), p);
      canvas.drawRect(Rect.fromLTWH(1, 1, ch-2.0, cw-2.0), p);
    }
    drawText(Offset(100,100), "ABCDEFG", 24);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
