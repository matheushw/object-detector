import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:object_detector/image_recognition/classifier.dart';
import 'package:object_detector/image_recognition/recognition.dart';
import 'package:object_detector/camera_view_singleton.dart';
import 'package:object_detector/image_recognition/isolate_utils.dart';

const double phoneWidth = 1200;
const double phoneHeight = 2400;

class CameraView extends StatefulWidget {
  final Function(List<Recognition> recognitions) resultsCallback;

  const CameraView(this.resultsCallback, {Key? key}) : super(key: key);

  @override
  CameraViewState createState() => CameraViewState();
}

class CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  late List<CameraDescription> cameras;
  late CameraController cameraController;
  late bool predicting;
  late Classifier classifier;
  late IsolateUtils isolateUtils;

  @override
  void initState() {
    super.initState();
    initStateAsync();
  }

  void initStateAsync() async {
    WidgetsBinding.instance.addObserver(this);
    isolateUtils = IsolateUtils();

    await isolateUtils.start();

    initializeCamera();

    classifier = Classifier();
    predicting = false;
  }

  void initializeCamera() async {
    cameras = await availableCameras();
    cameraController = CameraController(cameras[0], ResolutionPreset.veryHigh,
        enableAudio: false);

    cameraController.initialize().then((_) async {
      await cameraController.startImageStream(onLatestImageAvailable);
      Size screenSize = const Size(phoneWidth, phoneHeight);
      CameraViewSingleton.inputImageSize = screenSize;
      CameraViewSingleton.screenSize = screenSize;
      CameraViewSingleton.ratio = phoneWidth / phoneHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!cameraController.value.isInitialized) {
      return Container();
    }

    return AspectRatio(
      aspectRatio: phoneWidth / phoneHeight,
      child: CameraPreview(cameraController),
    );
  }

  onLatestImageAvailable(CameraImage cameraImage) async {
    if (predicting) {
      return;
    }

    setState(() {
      predicting = true;
    });

    var isolateData = IsolateData(
      cameraImage,
      classifier.interpreter!.address,
      classifier.labels!,
      null,
    );

    List<Recognition> recognitions = await inference(isolateData);

    widget.resultsCallback(recognitions);
    setState(() {
      predicting = false;
    });
  }

  Future<List<Recognition>> inference(IsolateData isolateData) async {
    ReceivePort responsePort = ReceivePort();
    isolateUtils.sendPort
        ?.send(isolateData..responsePort = responsePort.sendPort);
    var results = await responsePort.first;
    return results;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
        cameraController.stopImageStream();
        break;
      case AppLifecycleState.resumed:
        if (!cameraController.value.isStreamingImages) {
          await cameraController.startImageStream(onLatestImageAvailable);
        }
        break;
      default:
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController.dispose();
    super.dispose();
  }
}
