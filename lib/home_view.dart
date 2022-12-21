import 'package:flutter/material.dart';
import 'package:object_detector/image_recognition/recognition.dart';
import 'package:object_detector/components/box_widget.dart';

import 'components/camera_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  HomeViewState createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> {
  List<Recognition>? results;
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          CameraView(resultsCallback),
          boundingBoxes(results),
        ],
      ),
    );
  }

  Widget boundingBoxes(List<Recognition>? results) {
    if (results == null) {
      return Container();
    }
    return Stack(
      children: results.map((boxes) => BoxWidget(result: boxes)).toList(),
    );
  }

  void resultsCallback(List<Recognition> results) {
    setState(() {
      this.results = results;
    });
  }
}
