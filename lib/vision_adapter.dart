import 'dart:io';
import "dart:async";
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:flutter/material.dart';
import "package:image/image.dart" as imglib;
import 'package:path_provider/path_provider.dart';

import "tflite_adapter.dart";

bool isTest = false;
enum VisionType {
  NONE,
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
  SELFIE,
}

/// Google ML Kit Vision APIs
class VisionAdapter {
  VisionType type = VisionType.FACE;

  List<Face> faces = [];
  RecognizedText? text = null;
  List<ImageLabel> labels = [];
  List<Barcode> barcodes = [];
  List<TfResult> results = [];
  List<Pose> poses = [];
  List<DetectedObject> objects = [];
  SegmentationMask? mask;

  late FaceDetector _faceDetector;
  late TextRecognizer _textRecognizer;
  late ImageLabeler _imageLabeler;
  late BarcodeScanner _barcodeScanner;
  late TfliteAdapter _tflite;
  late PoseDetector _poseDetector;
  late DigitalInkRecognizer _digitalInkRecognizer;
  late ObjectDetector _objectDetector;
  late SelfieSegmenter _selfieSegmenter;

  VisionAdapter(){
    _faceDetector = FaceDetector(
      options:FaceDetectorOptions(
          enableClassification: true,
          enableLandmarks: true,
          enableContours: true,
          enableTracking: false,
          minFaceSize: 0.1,
          performanceMode: FaceDetectorMode.accurate),
    );

    _textRecognizer = TextRecognizer(script:TextRecognitionScript.latin);

    _imageLabeler = ImageLabeler(
        options:ImageLabelerOptions(confidenceThreshold: 0.5)
    );

    final List<BarcodeFormat> formats = [BarcodeFormat.all];
    _barcodeScanner = BarcodeScanner(formats: formats);

    _poseDetector = PoseDetector(
        options:PoseDetectorOptions(
        model: PoseDetectionModel.base, mode: PoseDetectionMode.single)
    );

    // BCP-47 Code from
    // https://developers.google.com/ml-kit/vision/digital-ink-recognition/base-models?hl=en#text
    _digitalInkRecognizer = DigitalInkRecognizer(languageCode:'ja');

    _objectDetector = ObjectDetector(
        options:ObjectDetectorOptions(
            mode:DetectionMode.single,
            classifyObjects:true,
            multipleObjects:true)
    );

    _selfieSegmenter = SelfieSegmenter(
      mode: SegmenterMode.single,
      enableRawSizeMask: true,
    );

    _tflite = TfliteAdapter();
  }

  void dispose() {
    if (_faceDetector != null) _faceDetector.close();
    if (_textRecognizer != null) _textRecognizer.close();
    if (_imageLabeler != null) _imageLabeler.close();
    if (_barcodeScanner != null) _barcodeScanner.close();
    if (_poseDetector != null) _poseDetector.close();
    if (_digitalInkRecognizer != null) _digitalInkRecognizer.close();
    if (_objectDetector != null) _objectDetector.close();
    if (_selfieSegmenter != null) _selfieSegmenter.close();
  }

  Future<void> detect(File imagefile) async {
    try {
      if (await imagefile.exists()) {
        print('-- START');
        final inputImage = InputImage.fromFile(imagefile);

        if(type==VisionType.FACE || type==VisionType.FACE2) {
          faces = await _faceDetector.processImage(inputImage);

        } else if(type==VisionType.TEXT) {
          text = await _textRecognizer.processImage(inputImage);

        } else if(type==VisionType.IMAGE) {
          labels = await _imageLabeler.processImage(inputImage);

        } else if(type==VisionType.BARCODE) {
          barcodes = await _barcodeScanner.processImage(inputImage);

        } else if(type==VisionType.POSE) {
          poses = await _poseDetector.processImage(inputImage);

        } else if(type==VisionType.INK) {
          //await _digitalInkRecogniser.readText(List<Offset?> points);

        } else if(type==VisionType.OBJECT) {
          objects = await _objectDetector.processImage(inputImage);

        } else if(type==VisionType.SELFIE) {
          mask = await _selfieSegmenter.processImage(inputImage);

        } else if(type==VisionType.TENSOR) {
          results.clear();
          TfResult res = await _tflite.detect(imagefile);
          results.add(res);

        } else if(type==VisionType.TENSOR2) {
          List<Rect> rects = [];
          faces = await _faceDetector.processImage(inputImage);
          for (Face f in faces) {
            rects.add(f.boundingBox);
          }

          results.clear();
          final File cropfile = File('${(await getTemporaryDirectory()).path}/crop.jpg');
          final byteData = imagefile.readAsBytesSync();
          imglib.Image? srcimg = imglib.decodeImage(byteData);

          for (Rect r1 in rects) {
            r1 = r1.inflate(4.0);
            imglib.Image crop = imglib.copyCrop(srcimg!, r1.left.toInt(), r1.top.toInt(), r1.width.toInt(), r1.height.toInt());
            await cropfile.writeAsBytes(imglib.encodeJpg(crop));
            TfResult res = await _tflite.detect(cropfile);
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
  late VisionAdapter vision;
  late Size cameraSize;
  late Size screenSize;
  double scale = 1.0;

  VisionPainter(VisionAdapter vision, Size cameraSize, Size screenSize){
    this.vision = vision;
    this.cameraSize = cameraSize;
    this.screenSize = screenSize;
  }

  Paint _paint = Paint();
  late Canvas _canvas;
  double _textTop = 240.0;
  double _textLeft = 30.0;
  double _fontSize = 32;
  double _fontHeight = 38;

  @override
  void paint(Canvas canvas, Size size){
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
    scale = dw/dh < 16.0/9.0 ? dw / cameraSize.width : dh / cameraSize.height;
    _canvas.scale(scale);

    if(size.width>size.height){
      _textTop = 200;
      _textLeft = 40;
    } else {
      _textTop = 300;
      _textLeft = 80;
    }

    if(isTest){
      //canvas size=392x698 screen 392x825 camera 1280x720 scale 0.55
      print('-- canvas size=${size.width.toInt()}x${size.height.toInt()}'
          ' screen ${screenSize.width.toInt()}x${screenSize.height.toInt()}'
          ' camera ${cameraSize.width.toInt()}x${cameraSize.height.toInt()}'
          ' scale ${scale.toStringAsFixed(2)}');
      _test(_canvas);
    }

    if (vision.type == VisionType.FACE) {
      if (vision.faces.length == 0) {
        return;
      }
      for (Face f in vision.faces) {
        Rect r = f.boundingBox;
        drawRect(r);
        if (f.smilingProbability != null) {
          drawText(Offset(r.left, r.top), 'smil '+(f.smilingProbability! * 100.0).toInt().toString(), _fontSize);
        }
        if (f.headEulerAngleX != null) {
          drawText(Offset(r.left, r.top + _fontHeight), 'x '+(f.headEulerAngleX! * 100.0).toInt().toString(), _fontSize);
        }
        if (f.headEulerAngleY != null) {
          drawText(Offset(r.left, r.top + _fontHeight*2), 'y '+(f.headEulerAngleY! * 100.0).toInt().toString(), _fontSize);
        }
        if (f.headEulerAngleZ != null) {
          drawText(Offset(r.left, r.top + _fontHeight*3), 'z '+(f.headEulerAngleZ! * 100.0).toInt().toString(), _fontSize);
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

        drawContour(f, FaceContourType.lowerLipBottom);
        drawContour(f, FaceContourType.lowerLipTop);
        drawContour(f, FaceContourType.upperLipBottom);
        drawContour(f, FaceContourType.upperLipTop);
        drawContour(f, FaceContourType.noseBottom);
        drawContour(f, FaceContourType.noseBridge);
        drawContour(f, FaceContourType.face);
      }

    } else if (vision.type == VisionType.TEXT) {
      if (vision.text == null)
        return;
      for (TextBlock b in vision.text!.blocks) {
        drawRect(b.boundingBox);
        drawText(Offset(b.boundingBox.left, b.boundingBox.top), b.text, _fontSize);
      }

    } else if (vision.type == VisionType.IMAGE) {
      if (vision.labels == null || vision.labels.length == 0)
        return;
      int i=0;
      for (ImageLabel label in vision.labels) {
        String s = (label.confidence*100.0).toInt().toString() +" "+ label.label;
        drawText(Offset(_textLeft, _textTop + _fontHeight*(i++)), s, _fontSize);
      }

    } else if (vision.type == VisionType.BARCODE) {
      if (vision.barcodes == null || vision.barcodes.length == 0)
        return;
      int i=0;
      for (Barcode b in vision.barcodes) {
        _paint.strokeWidth = 3.0;
        drawRect(b.boundingBox);
        String s = b.displayValue ?? '';
        drawText(Offset(_textLeft, _textTop + _fontHeight * (i++)), s, _fontSize);
      }

    } else if (vision.type == VisionType.SELFIE) {
      if (vision.mask == null)
        return;
      final confidences = vision.mask!.confidences;
      int width = vision.mask!.width; // =256
      int height = vision.mask!.height; // =256
      double sw = screenSize.width; // 392 or 825
      double sh = screenSize.height; // 825 or 392
      double cw = cameraSize.width; // =1280
      double ch = cameraSize.height; // =720
      double dx = sw>sh ? cw/width : ch/width;
      double dy = sw>sh ? ch/height : cw/height;
      print('SELFIE=w= ${width.toString()} ${height.toString()}');
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          if(confidences[(y * width) + x]<0.5) {
            _paint.style = PaintingStyle.fill;
            _canvas.drawCircle(Offset(x.toDouble()*dx, y.toDouble()*dy), 1.0, _paint);
          }
        }
      }

    } else if (vision.type == VisionType.OBJECT) {
      if (vision.objects == null || vision.objects.length == 0)
        return;
      for (DetectedObject b in vision.objects) {
        drawRect(b.boundingBox);
        int i=0;
        Rect r = b.boundingBox;
        drawText(Offset(r.left, r.top + _fontHeight * (i++)), 'id '+b.trackingId.toString(), _fontSize);
        List<Label> ls = b.labels;
        for (Label s in ls) {
          drawText(Offset(r.left, r.top + _fontHeight * (i++)), s.text, _fontSize);
        }
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
        drawPoseLandmark(lms, PoseLandmarkType.leftEye);
        //drawPoseLandmark(lms, PoseLandmarkType.leftEar);
        //drawPoseLandmark(lms, PoseLandmarkType.leftEyeInner);
        //drawPoseLandmark(lms, PoseLandmarkType.leftEyeOuter);

        drawPoseLandmark(lms, PoseLandmarkType.rightEye);
        //drawPoseLandmark(lms, PoseLandmarkType.rightEar);
        //drawPoseLandmark(lms, PoseLandmarkType.rightEyeInner);
        //drawPoseLandmark(lms, PoseLandmarkType.rightEyeOuter);

        _paint.color = Colors.orange;
        drawPoseLandmark(lms, PoseLandmarkType.nose);
        drawPoseLandmark(lms, PoseLandmarkType.rightMouth);
        drawPoseLandmark(lms, PoseLandmarkType.leftMouth);
        drawPoseLine(lms, PoseLandmarkType.rightMouth, PoseLandmarkType.leftMouth);

      });
    }
  }

  /// Rect
  drawRect(Rect? r) {
    if(r==null) return;
    _paint.style = PaintingStyle.stroke;
    _canvas.drawRect(r, _paint);
  }

  /// Face Contour
  drawContour(Face f, FaceContourType type) {
    FaceContour? c = f.contours[type];
    if(c != null) {
      var path = Path();
      c.points.asMap().forEach((i, pt) {
        i==0 ? path.moveTo(pt.x.toDouble(), pt.y.toDouble()) : path.lineTo(pt.x.toDouble(), pt.y.toDouble());
      });
      _paint.style = PaintingStyle.stroke;
      _canvas.drawPath(path, _paint);
    }
  }

  /// Face landmark
  drawLandmark(Face f, FaceLandmarkType type) {
    FaceLandmark? l = f.landmarks[type];
    if(l != null) {
      _paint.style = PaintingStyle.fill;
      _canvas.drawCircle(Offset(l.position.x.toDouble(),l.position.y.toDouble()), 6.0, _paint);
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
