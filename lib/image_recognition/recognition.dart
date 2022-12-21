import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:object_detector/camera_view_singleton.dart';

class Recognition {
  final int _id;
  final String _label;
  final double _score;
  final Rect? _location;

  Recognition(this._id, this._label, this._score, [this._location]);

  int get id => _id;

  String get label => _label;

  double get score => _score;

  Rect? get location => _location;

  Rect get renderLocation {
    double ratioX = CameraViewSingleton.ratio!;
    double ratioY = ratioX;

    double transLeft = max(0.1, (location?.left ?? 0) * ratioX);
    double transTop = max(0.1, (location?.top ?? 0) * ratioY);
    double transWidth = min((location?.width ?? 0) * ratioX,
        CameraViewSingleton.actualPreviewSize.width);
    double transHeight = min((location?.height ?? 0) * ratioY,
        CameraViewSingleton.actualPreviewSize.height);

    return Rect.fromLTWH(
      transLeft,
      transTop,
      transWidth,
      transHeight,
    );
  }

  @override
  String toString() {
    return 'Recognition(id: $id, label: $label, score: $score, location: $location)';
  }
}
