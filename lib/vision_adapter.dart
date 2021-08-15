import 'dart:io';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:flutter/material.dart';
import "dart:async";
import "package:fluttervision/tflite_adapter.dart";

bool isTest = false;

enum VisionType {
  FACE,
  FACE2,
  TEXT,
  IMAGE,
  BARCODE,
  TENSOR,
  POSE,
  INK,
  OBJECT,
}

class VisionAdapter {
  VisionType type = VisionType.FACE;

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
          if(_faceDetector==null){
            _faceDetector = GoogleMlKit.vision.faceDetector(
              FaceDetectorOptions(
                enableClassification: true,
                enableLandmarks: true,
                enableContours: true,
                enableTracking: false)
            );
          }
          faces = await _faceDetector!.processImage(inputImage);

        } else if(type==VisionType.TEXT) {
          if(_textDetector==null){
            _textDetector = GoogleMlKit.vision.textDetector();
          }
          text = await _textDetector!.processImage(inputImage);
        
        } else if(type==VisionType.IMAGE) {
          if(_imageLabeler==null){
            _imageLabeler = GoogleMlKit.vision.imageLabeler(
              ImageLabelerOptions(confidenceThreshold: 0.5)
            );
          }
          labels = await _imageLabeler!.processImage(inputImage);

        } else if(type==VisionType.BARCODE) {
          if(_barcodeScanner==null){
            _barcodeScanner = GoogleMlKit.vision.barcodeScanner();
          }
          barcodes = await _barcodeScanner!.processImage(inputImage);

        } else if(type==VisionType.POSE) {
          if(_poseDetector==null){
            _poseDetector = GoogleMlKit.vision.poseDetector(
              poseDetectorOptions:PoseDetectorOptions(
                model: PoseDetectionModel.base, mode: PoseDetectionMode.singleImage)
            );
          }
          poses = await _poseDetector!.processImage(inputImage);

        } else if(type==VisionType.INK) {
          if(_digitalInkRecogniser==null){
          }
        } else if(type==VisionType.OBJECT) {
          if(_objectDetector==null){
          }
        } else if(type==VisionType.TENSOR) {
          if (_tflite == null) {
            _tflite = TfliteAdapter();
            await _tflite!.initModel();
          }
          results = await _tflite!.detect(imagefile);
          if (results.length > 0) {
            int i = 0;
            for (TfResult res in results) {
              print('-- res ' + res.score.toString() + " " + res.label);
              if (i++ > 5) break;
            }
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

  bool isLand = false;
  double landx = 0.0;
  Paint _paint = Paint();
  late Canvas _canvas;

  @override
  void paint(Canvas canvas, Size size) { 
    _canvas = canvas;
    _paint.style = PaintingStyle.stroke;
    _paint.color = COLOR1;
    _paint.strokeWidth = 3.0;

    isLand = screenSize.width>screenSize.height ? true : false;
    if(isLand){
      landx = cameraSize.width*(screenSize.height/screenSize.width*16.0/9.0-1.0)/2-10;
    } else {
      landx = 0.0;
    }

    if(isTest) {
      _canvas.drawRect(Rect.fromLTWH(size.width/2-10, size.height/2-10, 20, 20), _paint);
      _canvas.scale(screenSize.height / cameraSize.width);
      double trans = (screenSize.height - cameraSize.height);
      _canvas.translate(-1 * 36, -1 * 67);
      _test(_canvas);
    } else {
      if (isLand) {
        _canvas.scale(screenSize.height / cameraSize.width);
        double trans = (cameraSize.width - cameraSize.height) / 2;
        _canvas.translate(-1 * trans, trans);
      } else {
        _canvas.scale(screenSize.height / cameraSize.width);
      }
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
        if (f.smilingProbability != null) {
          drawText(Offset(r.left, r.top), (f.smilingProbability! * 100.0).toInt().toString(), 36);
        }
        _canvas.drawRect(r, _paint);

        _paint.style = PaintingStyle.fill;
        _paint.color = Colors.red;
        double r1 = 8.0;
        drawLandmark(r1, f, FaceLandmarkType.leftEye);
        drawLandmark(r1, f, FaceLandmarkType.rightEye);

        _paint.color = Colors.orange;
        drawLandmark(r1, f, FaceLandmarkType.noseBase);

        _paint.color = COLOR1;
        drawLandmark(r1, f, FaceLandmarkType.bottomMouth);
        drawLandmark(r1, f, FaceLandmarkType.leftMouth);
        drawLandmark(r1, f, FaceLandmarkType.rightMouth);

        drawLandmark(r1, f, FaceLandmarkType.leftEar);
        drawLandmark(r1, f, FaceLandmarkType.rightEar);
        drawLandmark(r1, f, FaceLandmarkType.leftCheek);
        drawLandmark(r1, f, FaceLandmarkType.rightCheek);
      }

    } else if (vision.type == VisionType.FACE2) {
      if (vision.faces == null || vision.faces.length == 0) {
        return;
      }
      for (Face f in vision.faces) {
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
        _canvas.drawRect(b.rect, _paint);
        drawText(Offset(b.rect.left, b.rect.top), b.text, 36);
      }

    } else if (vision.type == VisionType.IMAGE) {
      if (vision.labels == null || vision.labels.length == 0)
        return;
      int i=0;
      for (ImageLabel label in vision.labels) {
        String s = (label.confidence*100.0).toInt().toString() +" "+ label.label;
        drawText(Offset(landx+30, 220+42.0*(i++)-landx), s, 36);
      }

    } else if (vision.type == VisionType.BARCODE) {
      if (vision.barcodes == null || vision.barcodes.length == 0)
        return;
      int i=0;
      for (Barcode b in vision.barcodes) {
        _paint.strokeWidth = 3.0;
        _canvas.drawRect(b.value.boundingBox!, _paint);
        String s = b.value.displayValue!;
        drawText(Offset(landx+30, 220+42.0*(i++)-landx), s, 36);
      }
    
    } else if (vision.type == VisionType.TENSOR) {
      if (vision.results.length == 0)
        return;
      int i=0;
      for (TfResult res in vision.results) {
        String s = (res.score).toInt().toString() + " " + res.label;
        drawText(Offset(landx+30, 220+42.0*(i++)-landx), s, 36);
        if(i>5) break;
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

  /// Face Contour
  drawContour(Face f, FaceContourType type) {
    FaceContour? c = f.getContour(type);
    if(c != null) {
      bool moveto = true;
      var path = Path();
      for (Offset pos in c.positionsList) {
        if(moveto) {
          path.moveTo(pos.dx, pos.dy);
          moveto = false;
        } else {
          path.lineTo(pos.dx, pos.dy);
        }
      }
      _canvas.drawPath(path, _paint);
    }
  }

  /// Face landmark
  drawLandmark(double r, Face f, FaceLandmarkType type) {
    FaceLandmark? l = f.getLandmark(type);
    if(l != null) {
      _canvas.drawCircle(l.position, r, _paint);
    }
  }

  drawPoseLandmark(Map<PoseLandmarkType, PoseLandmark> landmarks, PoseLandmarkType type) {
    PoseLandmark? m = landmarks[type];
    if(m != null) {
      _paint.style = PaintingStyle.fill;
      _canvas.drawCircle(Offset(m.x, m.y), 6, _paint);
    }
  }

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
      style: TextStyle(
        color: COLOR1,
        backgroundColor: Colors.black54,
        fontSize: size,
      ),
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
    p.strokeWidth = 2.0;
    canvas.drawRect(Rect.fromLTWH(1, 1, 100, 100), p);

    double cw = cameraSize.width;
    double ch = cameraSize.height;
    if(screenSize.width>screenSize.height){
      canvas.drawLine(Offset(cw / 2, 0), Offset(cw / 2, ch), p);
      canvas.drawLine(Offset(0, ch / 2), Offset(cw, ch / 2), p);
      canvas.drawRect(Rect.fromLTWH(1, 1, cw-2.0, ch-2.0), p);
    } else {
      canvas.drawLine(Offset(0,cw / 2), Offset(ch,cw / 2), p);
      canvas.drawLine(Offset(720 / 2,0), Offset(ch / 2,cw), p);
      canvas.drawRect(Rect.fromLTWH(1, 1, ch-2.0, cw-2.0), p);
    }
    drawText(Offset(100,100), "ABCDEFGHIJKLMN", 60);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
