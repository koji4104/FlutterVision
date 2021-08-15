import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import "dart:async";
import 'dart:typed_data';
import 'package:flutter/services.dart';

class TfliteAdapter {
  Interpreter? _interpreter = null;
  List<String> _labels = [];
  static const double threshold = 0.6;
  static const int numResults = 10;
  int _inputSize = 224;
  ImageProcessor? imageProcessor;
  List<List<int>> _outputShapes = [];
  List<TfLiteType> _outputTypes = [];

  Map<int, ByteBuffer> _outputBuffers = new Map<int, ByteBuffer>();
  Map<int, TensorBuffer> _outputTensorBuffers = new Map<int, TensorBuffer>();
  Map<int, String> _outputTensorNames = new Map<int, String>();

  bool init=false;

  TensorflowAdapter(){}

  Future initModel() async {
    try {
      _inputSize = 224;
      _interpreter = await Interpreter.fromAsset('model.tflite');

      final outputTensors = _interpreter!.getOutputTensors();
      _outputShapes = [];
      _outputTypes = [];
      for (final tensor in outputTensors) {
        _outputShapes.add(tensor.shape);
        _outputTypes.add(tensor.type);
      }

      outputTensors.asMap().forEach((i, tensor) {
        TensorBuffer output = TensorBuffer.createFixedSize(tensor.shape, tensor.type);
        _outputTensorBuffers[i] = output;
        _outputBuffers[i] = output.buffer;
        _outputTensorNames[i] = tensor.name;
      });

      /// load labels
      final labelData = await rootBundle.loadString('assets/labels.txt');
      final labelList = labelData.split('\n');
      _labels = labelList;

      init=true;
    } on Exception catch (e) {
      print('-- initModel '+e.toString());
    }
  }

  Future<List<TfResult>> detect(File imagefile) async {
    if (init == false)
      await new Future.delayed(new Duration(seconds:1));
    if (init == false)
      return [];

    List<TfResult> res = [];
    try {
      TensorImage inputImage = TensorImage.fromFile(imagefile);
      inputImage = getProcessedImage(inputImage);
      final inputs = [inputImage.buffer];

      // RUN
      _interpreter!.runForMultipleInputs(inputs, _outputBuffers);

      for (int i = 0; i < _outputTensorBuffers.length; i++) {
        TensorBuffer buffer = _outputTensorBuffers[i]!;
        for (int j = 0; j < buffer.getDoubleList().length; j++) {
          TfResult r = TfResult();
          r.label = _labels[j];
          r.score = buffer.getDoubleList()[j];
          res.add(r);
        }
      }
    } on Exception catch (e) {
      print('-- detect catch='+e.toString());
    }
    res.sort((b,a) => a.score.compareTo(b.score));
    return res;
  }

  /// square
  TensorImage getProcessedImage(TensorImage inputImage) {
    final padSize = 1080;
    imageProcessor ??= ImageProcessorBuilder()
      // crop
      .add(ResizeWithCropOrPadOp(padSize, padSize))
      // resize
      .add(ResizeOp(_inputSize, _inputSize, ResizeMethod.BILINEAR),
    ).build();
    return imageProcessor!.process(inputImage);
  }
}

/// TensorFlow Lite Result
class TfResult {
  String label = "";
  double score = 0.0;
}
class TfResults {
  List<TfResult> outputs = [];
}