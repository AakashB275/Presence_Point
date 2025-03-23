import 'package:flutter/material.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static Future<void> checkAndRequestLocation(BuildContext context) async {
    loc.Location location = loc.Location();
    bool serviceEnabled;
    PermissionStatus permissionStatus;

    // Check if GPS is enabled
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        _showAlertDialog(
            context, "GPS Required", "Please enable location services.");
        return;
      }
    }

    // Check location permission
    permissionStatus = await Permission.location.status;
    if (!permissionStatus.isGranted) {
      permissionStatus = await Permission.location.request();
      if (!permissionStatus.isGranted) {
        _showAlertDialog(
            context, "Permission Denied", "Location permission is required.");
      }
    }
  }

  static void _showAlertDialog(
      BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }
}
