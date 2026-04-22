import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart'; // Location package

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  // Default initial position
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(51.5246, -0.1340),
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    _loadHistoricalMeals();
  }

  Future<void> _loadHistoricalMeals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .get();

      Set<Marker> tempMarkers = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['location'] != null &&
            data['location'].toString().contains(',')) {
          final parts = data['location'].toString().split(',');
          if (parts.length >= 2) {
            final lat = double.tryParse(parts[0].trim());
            final lng = double.tryParse(parts[1].trim());

            if (lat != null && lng != null) {
              // Optimization: format decibel decimals
              double rawDb = 0.0;
              if (data['decibel'] != null) {
                rawDb = double.tryParse(data['decibel'].toString()) ?? 0.0;
              }

              BitmapDescriptor markerIcon;
              final int calories = (data['calories'] as num? ?? 0).toInt();
              if (calories < 400) {
                markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
              } else if (calories < 700) {
                markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
              } else {
                markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
              }

              tempMarkers.add(
                Marker(
                  markerId: MarkerId(doc.id),
                  position: LatLng(lat, lng),
                  infoWindow: InfoWindow(
                    title: "${data['food_name']} (${data['calories']} Kcal)",
                    snippet: "${rawDb.toStringAsFixed(1)} dB · ${_formatTimestamp(data['timestamp'])}",
                  ),
                  icon: markerIcon,
                ),
              );
            }
          }
        }
      }

      setState(() {
        _markers.clear();
        _markers.addAll(tempMarkers);
      });
    } catch (e) {
      debugPrint("Failed to load map markers: $e");
    }
  }

  // Feature: Move camera to user's current physical location with timeout and retry logic
  Future<void> _goToMyLocation() async {
    if (_mapController == null) return;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 15.0),
        ),
      );
    } catch (e) {
      debugPrint("Location timeout or error: $e. Trying last known position...");
      // Fallback to last known position if timeout occurs
      try {
        Position? last = await Geolocator.getLastKnownPosition();
        if (last != null && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: LatLng(last.latitude, last.longitude), zoom: 15.0),
            ),
          );
        }
      } catch (lastError) {
        debugPrint("Could not even get last known position: $lastError");
      }
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return "${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return "";
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              // Add a small delay to ensure the controller is fully ready
              Future.delayed(const Duration(milliseconds: 500), _goToMyLocation);
            },
          ),
          // Top gradient mask for a better looking status bar
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withAlpha(200), Colors.transparent],
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Calories",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  _legendItem(Colors.green, "< 400 Kcal"),
                  _legendItem(Colors.orange, "400–700 Kcal"),
                  _legendItem(Colors.red, "> 700 Kcal"),
                ],
              ),
            ),
          ),
        ],
      ),
      // Location and refresh buttons
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: "refresh_btn",
              backgroundColor: Colors.white,
              onPressed: _loadHistoricalMeals,
              mini: true,
              child: const Icon(Icons.refresh, color: Colors.green),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: "location_btn",
              backgroundColor: Colors.white,
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location, color: Colors.green),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
