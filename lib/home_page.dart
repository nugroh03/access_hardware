// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:access_hoardware/local_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    Key? key,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late File cameraFile;
  String location = 'Null, Press Button';
  String Address = 'search';
  bool gps = false;
  bool finger = false;
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
//
  final LocalAuthentication auth = LocalAuthentication();
  _SupportState _supportState = _SupportState.unknown;
  bool? _canCheckBiometrics;
  List<BiometricType>? _availableBiometrics;
  String _authorized = 'Not Authorized';
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    auth.isDeviceSupported().then(
          (bool isSupported) => setState(() => _supportState = isSupported
              ? _SupportState.supported
              : _SupportState.unsupported),
        );
  }

  openCamera() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(
        source: ImageSource.camera, maxWidth: 898, maxHeight: 898);
  }

  openGallery() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 898, maxHeight: 898);
  }

  //GPS----------------------------------------------------------------->

  Future<Position> _getGeoLocationPosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      await Geolocator.openLocationSettings();
      return Future.error('Location services are disabled.');
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> GetAddressFromLatLong(Position position) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      print(placemarks);
      Placemark place = placemarks[0];

      setState(() {
        Address =
            '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}';
      });
    } catch (e) {}
  }

//FingerPrint -------------------------------------------------------------->
  Future<void> _checkBiometrics() async {
    late bool canCheckBiometrics;
    try {
      canCheckBiometrics = await auth.canCheckBiometrics;
    } on PlatformException catch (e) {
      canCheckBiometrics = false;
      print(e);
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _canCheckBiometrics = canCheckBiometrics;
    });
  }

  Future<void> _getAvailableBiometrics() async {
    late List<BiometricType> availableBiometrics;
    try {
      availableBiometrics = await auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      availableBiometrics = <BiometricType>[];
      print(e);
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _availableBiometrics = availableBiometrics;
    });
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      setState(() {
        _isAuthenticating = true;
        _authorized = 'Authenticating';
      });
      authenticated = await auth.authenticate(
          localizedReason: 'Let OS determine authentication method',
          useErrorDialogs: true,
          stickyAuth: true);
      setState(() {
        _isAuthenticating = false;
      });
    } on PlatformException catch (e) {
      print(e);
      setState(() {
        _isAuthenticating = false;
        _authorized = 'Error - ${e.message}';
      });
      return;
    }
    if (!mounted) {
      return;
    }

    setState(
        () => _authorized = authenticated ? 'Authorized' : 'Not Authorized');
  }

  Future<void> _authenticateWithBiometrics() async {
    bool authenticated = false;
    try {
      setState(() {
        _isAuthenticating = true;
        _authorized = 'Authenticating';
      });
      authenticated = await auth.authenticate(
          localizedReason:
              'Scan your fingerprint (or face or whatever) to authenticate',
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: true);
      setState(() {
        _isAuthenticating = false;
        _authorized = 'Authenticating';
      });
    } on PlatformException catch (e) {
      print(e);
      setState(() {
        _isAuthenticating = false;
        _authorized = 'Error - ${e.message}';
      });
      return;
    }
    if (!mounted) {
      return;
    }

    final String message = authenticated ? 'Authorized' : 'Not Authorized';
    setState(() {
      _authorized = message;
    });
  }

  Future<void> _cancelAuthentication() async {
    await auth.stopAuthentication();
    setState(() => _isAuthenticating = false);
  }

  @override
  Widget build(BuildContext context) {
    //display image selected from gallery

    return Scaffold(
      body: Container(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () {
                      openCamera();
                    },
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [Icon(Icons.camera), Text("Camera")],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      Position position = await _getGeoLocationPosition();
                      location =
                          'Lat: ${position.latitude} , Long: ${position.longitude}';
                      GetAddressFromLatLong(position);
                      setState(() {
                        gps = !gps;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [Icon(Icons.location_on), Text("GPS")],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      openGallery();
                    },
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [Icon(Icons.grid_4x4), Text("Gallery")],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final isAuthenticated = await LocalAuthApi.authenticate();

                      if (isAuthenticated) {
                        print("sukses");
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.fingerprint),
                          Text("Finger Print")
                        ],
                      ),
                    ),
                  )
                ],
              ),
              if (gps)
                Container(
                  child: Column(
                    children: [
                      Text(
                        'Coordinates Points',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        location,
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        'ADDRESS',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text('${Address}'),
                    ],
                  ),
                ),
              Container(
                  child: Column(
                children: [
                  Container(
                      child: Column(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          if (_supportState == _SupportState.unknown)
                            const CircularProgressIndicator()
                          else if (_supportState == _SupportState.supported)
                            const Text('This device is supported')
                          else
                            const Text('This device is not supported'),
                          const Divider(height: 100),
                          Text('Can check biometrics: $_canCheckBiometrics\n'),
                          ElevatedButton(
                            child: const Text('Check biometrics'),
                            onPressed: _checkBiometrics,
                          ),
                          const Divider(height: 100),
                          Text('Available biometrics: $_availableBiometrics\n'),
                          ElevatedButton(
                            child: const Text('Get available biometrics'),
                            onPressed: _getAvailableBiometrics,
                          ),
                          const Divider(height: 100),
                          Text('Current State: $_authorized\n'),
                          if (_isAuthenticating)
                            ElevatedButton(
                              onPressed: _cancelAuthentication,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const <Widget>[
                                  Text('Cancel Authentication'),
                                  Icon(Icons.cancel),
                                ],
                              ),
                            )
                          else
                            Column(
                              children: <Widget>[
                                ElevatedButton(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const <Widget>[
                                      Text('Authenticate'),
                                      Icon(Icons.perm_device_information),
                                    ],
                                  ),
                                  onPressed: _authenticate,
                                ),
                                ElevatedButton(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(_isAuthenticating
                                          ? 'Cancel'
                                          : 'Authenticate: biometrics only'),
                                      const Icon(Icons.fingerprint),
                                    ],
                                  ),
                                  onPressed: _authenticateWithBiometrics,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ))
                ],
              ))
            ],
          ),
        ),
      ),
    );
  }
}

enum _SupportState {
  unknown,
  supported,
  unsupported,
}
