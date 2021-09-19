import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import "dart:async";
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math';

class TfliteAdapter {
  Interpreter? _interpreter = null;
  List<String> _labels = [];
  static int _inputSize = 224;

  Map<int, ByteBuffer> _outputBuffers = new Map<int, ByteBuffer>();
  Map<int, TensorBuffer> _outputTensorBuffers = new Map<int, TensorBuffer>();
  Map<int, String> _outputTensorNames = new Map<int, String>();

  bool init = false;

  TensorflowAdapter(){}

  Future initModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('model.tflite');
      final outputTensors = _interpreter!.getOutputTensors();
      outputTensors.asMap().forEach((i, tensor) {
        TensorBuffer output = TensorBuffer.createFixedSize(tensor.shape, tensor.type);
        _outputTensorBuffers[i] = output;
        _outputBuffers[i] = output.buffer;
        _outputTensorNames[i] = tensor.name;
      });

      print('-- outputTensors length='+outputTensors.length.toString()); //1
      print('-- outputTensor[0] shape='+outputTensors[0].shape.toString()); //[1, 5]
      print('-- outputTensor[0] type='+outputTensors[0].type.toString()); //TfLiteType.uint8
      print('-- outputTensor[0] name='+outputTensors[0].name); //Identity

      /// load labels
      final labelData = await rootBundle.loadString('assets/labels.txt');
      final labelList = labelData.split('\n');
      _labels = labelList;

      init = true;
    } on Exception catch (e) {
      print('-- initModel '+e.toString());
    }
  }

  Future<TfResult> detect(File imagefile) async {
    if (init == false) {
      await initModel();
    }
    if (init == false) {
      return TfResult();
    }
    TfResult res = TfResult();
    try {
      TensorImage inputImage = TensorImage.fromFile(imagefile);
      inputImage = getProcessedImage(inputImage);
      res = await run(inputImage);
    } on Exception catch (e) {
      print('-- detect catch='+e.toString());
    }
    return res;
  }

  Future<TfResult> run(TensorImage inputImage) async {
    TfResult res = TfResult();
    try {
      final inputs = [inputImage.buffer];

      // RUN
      _interpreter!.runForMultipleInputs(inputs, _outputBuffers);

      for (int i = 0; i < _outputTensorBuffers.length; i++) {
        TensorBuffer buffer = _outputTensorBuffers[i]!;
        for (int j = 0; j < buffer.getDoubleList().length; j++) {
          TfOutput r = TfOutput();
          r.label = _labels.length>j ? _labels[j] : '-';
          r.score = buffer.getDoubleList()[j];
          res.outputs.add(r);
        }
      }
    } on Exception catch (e) {
      print('-- run Exception='+e.toString());
    }

    res.outputs.sort((b,a) => a.score.compareTo(b.score));
    print('-- '+res.outputs[0].score.toString()+' '+res.outputs[0].label+' '+res.outputs[1].score.toString()+' '+res.outputs[1].label);
    return res;
  }

  /// square image
  TensorImage getProcessedImage(TensorImage inputImage) {
    print('-- TensorImage '+inputImage.width.toString() +' '+ inputImage.height.toString());
    int cropSize = min(inputImage.height, inputImage.width);
    ImageProcessor? imageProcessor = ImageProcessorBuilder()
      .add(ResizeWithCropOrPadOp(cropSize, cropSize)) // Center crop
      .add(ResizeOp(_inputSize, _inputSize, ResizeMethod.BILINEAR), // Resize 224x224
    ).build();
    return imageProcessor.process(inputImage);
  }
}

/// TensorFlow Result
class TfOutput {
  double score = 0.0;
  String label = "";
}
class TfResult {
  List<TfOutput> outputs = [];
  Rect rect = Rect.fromLTWH(0,0,0,0);
}