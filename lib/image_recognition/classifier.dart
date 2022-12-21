import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_lib;
import 'package:object_detector/image_recognition/recognition.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

class Classifier {
  Interpreter? _interpreter;
  List<String>? _labels;

  static const String modelFileName = "detect.tflite";
  static const String labelFileName = "labelmap.txt";
  static const int inputSize = 300;
  static const double threshold = 0.5;
  static const int numResults = 10;

  ImageProcessor? imageProcessor;
  int? padSize;
  List<List<int>>? _outputShapes;
  List<TfLiteType>? _outputTypes;

  Classifier({
    Interpreter? interpreter,
    List<String>? labels,
  }) {
    loadModel(interpreter: interpreter);
    loadLabels(labels: labels);
  }

  void loadModel({Interpreter? interpreter}) async {
    try {
      _interpreter = interpreter ??
          await Interpreter.fromAsset(
            modelFileName,
            options: InterpreterOptions()..threads = 4,
          );

      var outputTensors = _interpreter?.getOutputTensors();
      _outputShapes = [];
      _outputTypes = [];
      outputTensors?.forEach((tensor) {
        _outputShapes?.add(tensor.shape);
        _outputTypes?.add(tensor.type);
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error while creating interpreter: $e");
      }
    }
  }

  void loadLabels({List<String>? labels}) async {
    try {
      _labels = labels ?? await FileUtil.loadLabels("assets/$labelFileName");
    } catch (e) {
      if (kDebugMode) {
        print("Error while loading labels: $e");
      }
    }
  }

  TensorImage? getProcessedImage(TensorImage? inputImage) {
    if (inputImage != null && imageProcessor == null) {
      padSize = max(inputImage.height, inputImage.width);
      imageProcessor = ImageProcessorBuilder()
          .add(ResizeWithCropOrPadOp(padSize!, padSize!))
          .add(ResizeOp(inputSize, inputSize, ResizeMethod.BILINEAR))
          .build();
      inputImage = imageProcessor?.process(inputImage);
      return inputImage;
    }

    return null;
  }

  List<Recognition>? classify(image_lib.Image image) {
    if (_interpreter == null) {
      if (kDebugMode) {
        print("Interpreter not initialized");
      }
      return null;
    }

    TensorImage? inputImage = TensorImage.fromImage(image);
    inputImage = getProcessedImage(inputImage);

    TensorBuffer outputLocations = TensorBufferFloat(_outputShapes![0]);
    TensorBuffer outputClasses = TensorBufferFloat(_outputShapes![1]);
    TensorBuffer outputScores = TensorBufferFloat(_outputShapes![2]);
    TensorBuffer numLocations = TensorBufferFloat(_outputShapes![3]);

    List<Object> inputs =
        inputImage?.buffer != null ? [inputImage!.buffer] : [];

    Map<int, Object> outputs = {
      0: outputLocations.buffer,
      1: outputClasses.buffer,
      2: outputScores.buffer,
      3: numLocations.buffer,
    };

    _interpreter?.runForMultipleInputs(inputs, outputs);

    int resultsCount = min(numResults, numLocations.getIntValue(0));

    int labelOffset = 1;

    List<Rect> locations = BoundingBoxUtils.convert(
      tensor: outputLocations,
      valueIndex: [1, 0, 3, 2],
      boundingBoxAxis: 2,
      boundingBoxType: BoundingBoxType.BOUNDARIES,
      coordinateType: CoordinateType.RATIO,
      height: inputSize,
      width: inputSize,
    );

    List<Recognition> recognitions = [];

    for (int i = 0; i < resultsCount; i++) {
      var score = outputScores.getDoubleValue(i);
      var labelIndex = outputClasses.getIntValue(i) + labelOffset;
      var label = _labels?.elementAt(labelIndex);

      if (score > threshold) {
        Rect? transformedRect = imageProcessor?.inverseTransformRect(
            locations[i], image.height, image.width);

        if (label != null && transformedRect != null) {
          recognitions.add(
            Recognition(i, label, score, transformedRect),
          );
        }
      }
    }

    return recognitions;
  }

  Interpreter? get interpreter => _interpreter;

  List<String>? get labels => _labels;
}
