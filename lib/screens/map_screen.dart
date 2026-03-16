import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  // 默认中心点：伦敦 UCL 附近 (你可以随便改)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(51.5246, -0.1340),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _loadHistoricalMeals(); // 页面加载时，去云端拉取所有吃过饭的坐标
  }

  // 核心功能：从 Firestore 抓取历史数据并打在地图上
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
        // 假设我们在 Day 1 存的 location 是 "51.52, -0.13" 格式的字符串
        if (data['location'] != null && data['location'].toString().contains(',')) {
          final parts = data['location'].toString().split(',');
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());

          if (lat != null && lng != null) {
            tempMarkers.add(
              Marker(
                markerId: MarkerId(doc.id),
                position: LatLng(lat, lng),
                // 高分点：Marker 的点击气泡展示环境与饮食数据
                infoWindow: InfoWindow(
                  title: "${data['food_name']} (${data['calories']} Kcal)",
                  snippet: "Ambient Noise: ${data['decibel']} dB",
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ),
            );
          }
        }
      }

      setState(() {
        _markers.addAll(tempMarkers);
      });
    } catch (e) {
      debugPrint("Failed to load map markers: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 沉浸式的全屏地图
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _initialPosition,
        markers: _markers,
        myLocationEnabled: true, // 允许显示用户当前蓝点
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
      ),
      // 回到当前位置的按钮
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80), // 避开底部导航栏
        child: FloatingActionButton(
          backgroundColor: Colors.white,
          onPressed: () {
            // 你可以通过 geolocator 获取当前位置并移动镜头，这里暂时省略
          },
          child: const Icon(Icons.my_location, color: Colors.green),
        ),
      ),
    );
  }
}