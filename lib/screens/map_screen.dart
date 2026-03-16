import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart'; // 引入定位包

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  // 默认初始位置
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
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());

          if (lat != null && lng != null) {
            // 优化：处理分贝数值的小数点
            double rawDb = 0.0;
            if (data['decibel'] != null) {
              rawDb = double.tryParse(data['decibel'].toString()) ?? 0.0;
            }

            tempMarkers.add(
              Marker(
                markerId: MarkerId(doc.id),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(
                  title: "${data['food_name']} (${data['calories']} Kcal)",
                  snippet:
                      "Ambient Noise: ${rawDb.toStringAsFixed(1)} dB", // 修正长长的小数点
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
              ),
            );
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

  // 新功能：移动镜头到用户当前真实位置
  Future<void> _goToMyLocation() async {
    if (_mapController == null) return;
    try {
      Position position = await Geolocator.getCurrentPosition();
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15.0,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Could not get location: $e");
    }
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
            },
          ),
          // 顶部加个渐变遮罩，让时间栏更好看
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
        ],
      ),
      // 定位按钮和刷新按钮
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
