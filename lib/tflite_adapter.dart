import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/material.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:image/image.dart' as imagelib;
import 'dart:math';
import "dart:async";
import 'dart:typed_data';

class TfliteAdapter {
  Interpreter? _interpreter = null;
  List<String> _labels = ['11','22','33','44','55','66','77','88','99','00'];
  static const double threshold = 0.6;
  static const int inputSize = 300;
  static const int numResults = 10;
  ImageProcessor? imageProcessor;
  List<List<int>> _outputShapes = [];
  List<TfLiteType> _outputTypes = [];

  Map<int, ByteBuffer> _outputBuffers = new Map<int, ByteBuffer>();
  Map<int, TensorBuffer> _outputTensorBuffers = new Map<int, TensorBuffer>();
  Map<int, String> _outputTensorNames = new Map<int, String>();

  bool init=false;

  TensorflowAdapter(){
  }

  Future initModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('model.tflite');

      final outputTensors = _interpreter!.getOutputTensors();
      _outputShapes = [];
      _outputTypes = [];
      for (final tensor in outputTensors) {
        _outputShapes.add(tensor.shape);
        _outputTypes.add(tensor.type);
      }

      outputTensors.asMap().forEach((i, tensor) {
        TensorBuffer output =
        TensorBuffer.createFixedSize(tensor.shape, tensor.type);
        _outputTensorBuffers[i] = output;
        _outputBuffers[i] = output.buffer;
        _outputTensorNames[i] = tensor.name;
      });

      print('-- outputTensors.length=' + outputTensors.length.toString());
      init=true;
    } on Exception catch (e) {
      print('-- initModel '+e.toString());
    }
  }

  Future<List<TfliteResult>> detect(File imagefile) async {
    if (init == false)
      await new Future.delayed(new Duration(seconds:1));
    if (init == false)
      return [];

    print('-- detect1');

    TensorImage inputImage = TensorImage.fromFile(imagefile);
    inputImage = getProcessedImage(inputImage);

    print('-- detect2');

    final inputs = [inputImage.buffer];
    _interpreter!.runForMultipleInputs(inputs, _outputBuffers);

    for (int i = 0; i < _outputTensorBuffers.length; i++) {
      TensorBuffer buffer = _outputTensorBuffers[i]!;
      print("${_outputTensorNames[i]}: ${buffer.getDoubleList()}");
    }

    print('-- detect3');
    return [];
  }

  /// square
  TensorImage getProcessedImage(TensorImage inputImage) {
    final padSize = 1280;
    imageProcessor ??= ImageProcessorBuilder()
      // crop
      .add(ResizeWithCropOrPadOp(padSize, padSize))
      // resize
      .add(ResizeOp(inputSize, inputSize, ResizeMethod.BILINEAR),
    ).build();
    return imageProcessor!.process(inputImage);
  }
}

/// TensorFlow Lite Result
class TfliteResult {
  TfliteResult(this.id, this.label, this.score, this.location);

  int id;
  String label;
  double score; // 0-1
  Rect location;

  Rect getRenderLocation(Size actualPreviewSize, double pixelRatio) {
    final ratioX = pixelRatio;
    final ratioY = ratioX;

    final transLeft = max(0.1, location.left * ratioX);
    final transTop = max(0.1, location.top * ratioY);
    final transWidth = min(
      location.width * ratioX,
      actualPreviewSize.width,
    );
    final transHeight = min(
      location.height * ratioY,
      actualPreviewSize.height,
    );
    final transformedRect =
    Rect.fromLTWH(transLeft, transTop, transWidth, transHeight);
    return transformedRect;
  }
}