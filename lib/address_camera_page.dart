import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:translator/translator.dart';

import 'address_camera_helper.dart';

class AddressCamera extends StatefulWidget {
  const AddressCamera({super.key});

  @override
  State<AddressCamera> createState() => _AddressCameraState();
}

class _AddressCameraState extends State<AddressCamera> {
  @override
  void initState() {
    super.initState();
    addAllPermission();
  }

  Position? _currentPosition;
  Stream<Position>? _positionStream;
  String _address = "";
  CameraController? _cameraController;
  final _translator = GoogleTranslator();
  Timer? _timer;
  String _currentTime = "";

  Future<void> addAllPermission() async {
    await Permission.camera.request();
    await Permission.storage.request();
    await Permission.location.request();

    final cameras = await availableCameras();
    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
    );
    await _cameraController?.initialize();
    timer();
    _getLocation();
  }

  void timer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      formatDateTime(DateTime.now());
    });
  }

  void formatDateTime(DateTime dateTime) {
    String formattedDateTime = DateFormat(
      'dd-MM-yyyy HH:mm:ss',
    ).format(dateTime);
    Duration offset = dateTime.timeZoneOffset;
    String sign = offset.isNegative ? '-' : '+';
    String twoDigits(int n) => n.abs().toString().padLeft(2, '0');
    String offsetHours = twoDigits(offset.inHours);
    String offsetMinutes = twoDigits(offset.inMinutes.remainder(60));
    setState(() {
      _currentTime = "$formattedDateTime GMT$sign$offsetHours:$offsetMinutes";
    });
  }

  void _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _address = 'Location not available');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );

    _positionStream!.listen((Position position) async {
      setState(() => _currentPosition = position);
      String add = await getAddress(position);
      var hindi = await _translator.translate(add, from: "en", to: "hi");
      setState(() {
        _currentPosition = position;
        _address = hindi.text;
      });
    });
  }

  getAddress(Position position) async {
    try {
      List<Placemark> placeMark = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placeMark.isNotEmpty) {
        final place = placeMark.first;
        return '${place.name}, ${place.locality}\n${place.administrativeArea}, ${place.country}';
      }
      return '';
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
    }
  }

  Future<void> getImage() async {
    try {
      final picture = await _cameraController?.takePicture();
      var captureTime = _currentTime;
      final croppedFile = await AddressCameraHelper.cropImage(picture!.path);
      if (croppedFile == null) return;

      var text =
          "$_address\nlat: ${_currentPosition!.latitude}, long: ${_currentPosition!.longitude}\n$captureTime";
      final finalImage = await AddressCameraHelper.overlayText(
        croppedFile,
        text,
      );

      final tempDir = await getTemporaryDirectory();
      final savePath = path.join(
        tempDir.path,
        'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final saved = await finalImage.copy(savePath);
      await GallerySaver.saveImage(saved.path).then(
        (value) => {
          if (context.mounted) showMessage(context, "Saved Image Successfully"),
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
    }
  }

  static Future<void> showMessage(BuildContext context, String message) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text("Address Camera")),
      body:
          _cameraController == null ||
              !_cameraController!.value.isInitialized ||
              _currentPosition == null ||
              _address.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(child: CameraPreview(_cameraController!)),
                Positioned(
                  bottom: 20,
                  left: 10,
                  right: 10,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(153),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: GoogleMap(
                                        mapToolbarEnabled: false,
                                        zoomControlsEnabled: false,
                                        liteModeEnabled: true,
                                        myLocationEnabled: true,
                                        myLocationButtonEnabled: false,
                                        initialCameraPosition: CameraPosition(
                                          target: LatLng(
                                            _currentPosition!.latitude,
                                            _currentPosition!.longitude,
                                          ),
                                          zoom: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      "$_address\nlat: ${_currentPosition!.latitude}, long: ${_currentPosition!.longitude}\n$_currentTime",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: getImage,
                        iconSize: 50,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.circle, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
