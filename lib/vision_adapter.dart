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
  List<TfliteResult> results = [];
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

        } else if(type==VisionType.TENSOR) {
          if(_tflite==null){
            _tflite = TfliteAdapter();
            await _tflite!.initModel();
          }
          results = await _tflite!.detect(imagefile);
          print('-- _tensor.length=' + results.length.toString());
          if(results.length>0) {
            for (TfliteResult res in results) {
              print('-- label-' + res.label + ' score=' + res.score.toString());
            }
          }
        
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
        }
        print('-- END');
      }
    } on Exception catch (e) {
      print('-- Exception ' + e.toString());
    }
  }
}

class VisionPainter extends CustomPainter {
  final Color COLOR1 = Color.fromARGB(255, 0xCC, 0x99, 0xFF);
  VisionAdapter vision;
  Size cameraSize;
  Size screenSize;
  VisionPainter(this.vision, this.cameraSize, this.screenSize);

  bool isLand = false;
  double landx = 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint();
    p.style = PaintingStyle.stroke;
    p.color = COLOR1;
    p.strokeWidth = 2.0;

    isLand = screenSize.width>screenSize.height ? true : false;
    if(isLand){
      landx = cameraSize.width*(screenSize.height/screenSize.width*16.0/9.0-1.0)/2;
    } else {
      landx = 0.0;
    }

    if(isTest) {
      canvas.drawRect(Rect.fromLTWH(size.width/2-10, size.height/2-10, 20, 20), p);
      canvas.scale(screenSize.height / cameraSize.width);
      double trans = (screenSize.height - cameraSize.height);
      canvas.translate(-1 * 36, -1 * 67);
      _test(canvas);
    } else {
      if (isLand) {
        canvas.scale(screenSize.height / cameraSize.width);
        double trans = (cameraSize.width - cameraSize.height) / 2;
        canvas.translate(-1 * trans, trans);
      } else {
        canvas.scale(screenSize.height / cameraSize.width);
      }
    }

    if (vision == null) {
      print("-- vision null");
      return;
    }

    if (vision.type == VisionType.FACE) {
      if (vision.faces == null || vision.faces.length == 0) {
        //print("-- face zero");
        return;
      }
      for (Face f in vision.faces) {
        Rect r = f.boundingBox;
        if (f.smilingProbability != null) {
          drawText(canvas, Offset(r.left, r.top),
              (f.smilingProbability! * 100.0).toInt().toString(), 36);
        }
        p.strokeWidth = 2.0;
        canvas.drawRect(r, p);

        p.color = Colors.red;
        p.style = PaintingStyle.fill;
        p.strokeWidth = 4.0;
        double r1 = 12.0;
        drawLandmark(canvas, r1, p, f, FaceLandmarkType.leftEye);
        drawLandmark(canvas, r1, p, f, FaceLandmarkType.rightEye);

        p.color = COLOR1;
        p.style = PaintingStyle.fill;
        p.strokeWidth = 1.0;
        r1 = 8.0;
        drawLandmark(canvas, r1, p, f, FaceLandmarkType.bottomMouth);
        drawLandmark(canvas, r1, p, f, FaceLandmarkType.leftMouth);
        drawLandmark(canvas, r1, p, f, FaceLandmarkType.rightMouth);

        drawLandmark(canvas, r1, p, f, FaceLandmarkType.leftEar);
        drawLandmark(canvas, r1, p, f, FaceLandmarkType.rightEar);
        drawLandmark(canvas, r1, p, f, FaceLandmarkType.leftCheek);
        drawLandmark(canvas, r1, p, f, FaceLandmarkType.rightCheek);

        drawLandmark(canvas, r1, p, f, FaceLandmarkType.noseBase);
      }

    } else if (vision.type == VisionType.FACE2) {
      if (vision.faces == null || vision.faces.length == 0) {
        return;
      }
      for (Face f in vision.faces) {
        p.color = COLOR1;
        p.style = PaintingStyle.stroke;
        p.strokeWidth = 2.0;
        drawContour(canvas, p, f, FaceContourType.leftEye);
        drawContour(canvas, p, f, FaceContourType.rightEye);

        drawContour(canvas, p, f, FaceContourType.leftEyebrowBottom);
        drawContour(canvas, p, f, FaceContourType.leftEyebrowTop);
        drawContour(canvas, p, f, FaceContourType.rightEyebrowBottom);
        drawContour(canvas, p, f, FaceContourType.leftEyebrowTop);

        drawContour(canvas, p, f, FaceContourType.face);

        drawContour(canvas, p, f, FaceContourType.lowerLipBottom);
        drawContour(canvas, p, f, FaceContourType.lowerLipTop);
        drawContour(canvas, p, f, FaceContourType.upperLipBottom);
        drawContour(canvas, p, f, FaceContourType.upperLipTop);

        drawContour(canvas, p, f, FaceContourType.noseBottom);
        drawContour(canvas, p, f, FaceContourType.noseBridge);
      }

    } else if (vision.type == VisionType.TEXT) {
      if (vision.text == null)
        return;
      for (TextBlock b in vision.text!.blocks) {
        canvas.drawRect(b.rect, p);
        drawText(canvas, Offset(b.rect.left, b.rect.top), b.text, 36);
      }

    } else if (vision.type == VisionType.IMAGE) {
      if (vision.labels == null || vision.labels.length == 0)
        return;
      int i=0;
      for (ImageLabel label in vision.labels) {
        String s = (label.confidence*100.0).toInt().toString() +" "+ label.label;
        drawText(canvas, Offset(landx+30, 240+42.0*(i++)), s, 36);
      }

    } else if (vision.type == VisionType.BARCODE) {
      if (vision.barcodes == null || vision.barcodes.length == 0)
        return;
      int i=0;
      for (Barcode b in vision.barcodes) {
        canvas.drawRect(b.value.boundingBox!, p);
        String s = b.value.displayValue!;
        drawText(canvas, Offset(landx+30, 240+42.0*(i++)), s, 36);
      }
    
    } else if (vision.type == VisionType.TENSOR) {
      if (vision.results.length == 0)
        return;
      int i=0;
      for (TfliteResult res in vision.results) {
        canvas.drawRect(res.location, p);
        String s = (res.score*100.0).toInt().toString() + " " + res.label;
        drawText(canvas, Offset(landx+30, 240+42.0*(i++)), s, 36);
      }

    } else if (vision.type == VisionType.POSE) {
      if (vision.poses.length == 0)
        return;
      p.style = PaintingStyle.fill;
      p.strokeWidth = 1.0;
      vision.poses.forEach((pose) {

        p.color = Colors.blue;
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftAnkle);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftKnee);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftHeel);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftHip);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftFootIndex);

        p.color = Colors.lightBlueAccent;
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftElbow);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftShoulder);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftWrist);

        p.color = Colors.blueAccent;
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftPinky);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftThumb);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftIndex);

        p.color = Colors.greenAccent;
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftEar);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftEye);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftEyeInner);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftEyeOuter);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.leftMouth);

        p.color = Colors.red;
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.nose);

        p.color = Colors.red;
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightAnkle);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightKnee);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightHeel);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightHip);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightFootIndex);

        p.color = Colors.orange;
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightElbow);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightShoulder);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightWrist);

        p.color = Colors.redAccent;
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightPinky);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightThumb);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightIndex);

        p.color = Colors.lightGreen;
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightEar);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightEye);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightEyeInner);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightEyeOuter);
        drawPoseLandmark(canvas, p, pose.landmarks, PoseLandmarkType.rightMouth);

      });        
    }
  }

  /// Draw face Contour
  drawContour(Canvas canvas, Paint p, Face f, FaceContourType type) {
    FaceContour? c = f.getContour(type);
    if(c != null) {
      bool moveto = true;
      var path = Path();
      for (Offset pos in c.positionsList) {
        if(moveto) {
          path.moveTo(pos.dx, pos.dy);
          moveto=false;
        } else {
          path.lineTo(pos.dx, pos.dy);
        }
      }
      canvas.drawPath(path, p);
    }
  }

  /// Draw face landmark
  drawLandmark(Canvas canvas, double r, Paint p, Face f, FaceLandmarkType type) {
    FaceLandmark? l = f.getLandmark(type);
    if(l != null) {
      canvas.drawCircle(l.position, r, p);
    }
  }

  drawPoseLandmark(Canvas canvas, Paint p, Map<PoseLandmarkType, PoseLandmark> landmarks, PoseLandmarkType type) {
    PoseLandmark? m = landmarks[type];
    if(m != null) {
      canvas.drawCircle(Offset(m.x, m.y), 4, p);
    }
  }

  /// Draw text
  drawText(Canvas canvas, Offset offset, String text, double size) {
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
    textPainter.paint(canvas, offset);  
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
    drawText(canvas, Offset(100,100), "ABCDEFGHIJKLMN", 60);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
