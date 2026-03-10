import 'package:flutter/material.dart';

class OfficeLocation {
  String lat;
  String lng;
  String radius;

  OfficeLocation({
    required this.lat,
    required this.lng,
    required this.radius,
  });
}

class OfficeProvider extends ChangeNotifier {
  OfficeLocation _location = OfficeLocation(
    lat: '-7.291547',
    lng: '112.759209',
    radius: '100',
  );

  OfficeLocation get location => _location;

  void updateLat(String lat) {
    _location.lat = lat;
    notifyListeners();
  }

  void updateLng(String lng) {
    _location.lng = lng;
    notifyListeners();
  }

  void updateRadius(String radius) {
    _location.radius = radius;
    notifyListeners();
  }
}
