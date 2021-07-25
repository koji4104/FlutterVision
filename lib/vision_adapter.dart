import 'dart:io';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';

enum VisionType {
  FACE,
  FACE2,
  TEXT,
  IMAGE,
  BARCODE
}

class VisionAdapter {
  VisionType type = VisionType.FACE;

  List<Face> faces;
  VisionText text;
  List<ImageLabel> labels;
  List<Barcode> barcodes;

  FaceDetector _faceDetector = null;
  TextRecognizer _textRecognizer = null;
  ImageLabeler _imageLabeler = null;
  BarcodeDetector _barcodeDetector = null;

  VisionAdapter(){
    _faceDetector = FirebaseVision.instance.faceDetector(
        FaceDetectorOptions(
            enableClassification: true,
            enableLandmarks: true,
            enableContours: true,
            enableTracking: false));
    _textRecognizer = FirebaseVision.instance.textRecognizer();
    _imageLabeler = FirebaseVision.instance.imageLabeler(
        ImageLabelerOptions(confidenceThreshold: 0.5));
    _barcodeDetector = FirebaseVision.instance.barcodeDetector(
        BarcodeDetectorOptions(barcodeFormats: BarcodeFormat.all));
  }

  void dispose() {
    if (_faceDetector != null) _faceDetector.close();
    if (_textRecognizer != null) _textRecognizer.close();
    if (_imageLabeler != null) _imageLabeler.close();
    if (_barcodeDetector != null) _barcodeDetector.close();
  }

  void detect(File imagefile) async {
    try {
      if (await imagefile.exists()) {
        print('-- START');
        final FirebaseVisionImage visionImage = FirebaseVisionImage.fromFile(imagefile);
        if(type==VisionType.FACE || type==VisionType.FACE2) {
          faces = await _faceDetector.processImage(visionImage);
        } else if(type==VisionType.TEXT) {
          text = await _textRecognizer.processImage(visionImage);
        } else if(type==VisionType.IMAGE) {
          labels = await _imageLabeler.processImage(visionImage);
        } else if(type==VisionType.BARCODE) {
          barcodes = await _barcodeDetector.detectInImage(visionImage);
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
  VisionAdapter vision = null;
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

    //canvas.drawRect(Rect.fromLTWH(1, 1, size.width-2, size.height-2), p);
    //canvas.drawRect(Rect.fromLTWH(size.width/2-10, size.height/2-10, 20, 20), p);
    isLand = screenSize.width>screenSize.height ? true : false;
    if(isLand){
      landx = cameraSize.width*(screenSize.height/screenSize.width*16.0/9.0-1.0)/2;
    } else {
      landx = 0.0;
    }
    //print("landx=" + landx.toString());

    if(isLand){
      canvas.scale(screenSize.height / cameraSize.width);
      double trans = (cameraSize.width - cameraSize.height) / 2;
      canvas.translate(-1 * trans, trans);
    } else {
      canvas.scale(screenSize.height / cameraSize.width);
    }

    //_test(canvas);

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
              (f.smilingProbability * 100.0).toInt().toString());
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
      for (TextBlock b in vision.text.blocks) {
        canvas.drawRect(b.boundingBox, p);
        drawText(canvas, Offset(b.boundingBox.left, b.boundingBox.top), b.text);
      }
      //drawText(canvas, Offset(50, 50), vision.text.text);

    } else if (vision.type == VisionType.IMAGE) {
      if (vision.labels == null || vision.labels.length == 0)
        return;
      int i=0;
      for (ImageLabel label in vision.labels) {
        String s = (label.confidence*100.0).toInt().toString() +" "+ label.text;
        drawText(canvas, Offset(landx+30, 240+42.0*(i++)), s);
      }

    } else if (vision.type == VisionType.BARCODE) {
      if (vision.barcodes == null || vision.barcodes.length == 0)
        return;
      int i=0;
      for (Barcode b in vision.barcodes) {
        canvas.drawRect(b.boundingBox, p);
        String s = b.displayValue;
        drawText(canvas, Offset(landx+30, 240+42.0*(i++)), s);
      }
    }
  }

  /// Draw face Contour
  drawContour(Canvas canvas, Paint p, Face f, FaceContourType type) {
    FaceContour c = f.getContour(type);
    if(c != null) {
      bool move = true;
      var path = Path();
      for (Offset pos in c.positionsList) {
        if(move) {
          path.moveTo(pos.dx, pos.dy);
          move=false;
        } else {
          path.lineTo(pos.dx, pos.dy);
        }
        canvas.drawPath(path, p);
      }
    }
  }

  /// Draw face landmark
  drawLandmark(Canvas canvas, double r, Paint p, Face f, FaceLandmarkType type) {
    FaceLandmark l = f.getLandmark(type);
    if(l != null) {
      canvas.drawCircle(l.position, r, p);
    }
  }

  /// Draw text
  drawText(Canvas canvas, Offset offset, String text) {
    TextSpan span = TextSpan(
      text: " "+text+" ",
      style: TextStyle(
        color: COLOR1,
        backgroundColor: Colors.black54,
        fontSize: 36,
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
    drawText(canvas, Offset(100,100), "Test text");
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
