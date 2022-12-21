import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as image_lib;
import 'package:object_detector/image_recognition/classifier.dart';
import 'package:object_detector/image_recognition/recognition.dart';
import 'package:object_detector/image_recognition/image_utils.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class IsolateUtils {
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();

  SendPort? get sendPort => _sendPort;

  Future<void> start() async {
    await Isolate.spawn<SendPort>(
      entryPoint,
      _receivePort.sendPort,
    );

    _sendPort = await _receivePort.first;
  }

  static void entryPoint(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (final IsolateData isolateData in port) {
      Classifier classifier = Classifier(
        interpreter: Interpreter.fromAddress(isolateData.interpreterAddress),
        labels: isolateData.labels,
      );
      image_lib.Image? image =
          ImageUtils.convertCameraImage(isolateData.cameraImage);
      if (image != null) {
        if (Platform.isAndroid) {
          image = image_lib.copyRotate(image, 90);
        }
        List<Recognition>? results = classifier.classify(image);
        isolateData.responsePort?.send(results);
      }
    }
  }
}

class IsolateData {
  CameraImage cameraImage;
  int interpreterAddress;
  List<String> labels;
  SendPort? responsePort;

  IsolateData(
    this.cameraImage,
    this.interpreterAddress,
    this.labels,
    this.responsePort,
  );
}
