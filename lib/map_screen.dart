import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_map_app/marker_data.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<MarkerData> _markerData = [];
  List<Marker> _markers = [];
  LatLng? _selectedPostion;
  LatLng? _mylocation;
  LatLng? _draggedPosition;
  bool _isDragging = false;
  TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    //test if the service is enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error("Location services are disabled!");
    }
    /* */
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error("Location permissions are denied!");
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error("Location permissions are denied forever!");
    }
    //get the location present
    return await Geolocator.getCurrentPosition();
  }

  //show current location
  void _showCurrentLocation() async {
    try {
      Position position = await _determinePosition();
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      _mapController.move(currentLatLng, 9.2);
      setState(() {
        _mylocation = currentLatLng;
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  //add marker anywhere you want to
  void _addMarker(LatLng position, String title, String description) {
    setState(() {
      final markerData = MarkerData(
          position: position, title: title, description: description);
      _markerData.add(markerData);
      _markers.add(Marker(
          point: position,
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: () {},
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 5,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                ),
                const Icon(
                  Icons.location_on,
                  size: 40,
                  color: Colors.redAccent,
                )
              ],
            ),
          )));
    });
  }

  //show marker dialog
  void _showMarkerDialog(BuildContext context, LatLng position) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descController = TextEditingController();

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Add Marker'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                    ),
                  ),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isEmpty ||
                        descController.text.isEmpty) {
                      showDialog(
                        context: context,
                        builder: (context) => const AlertDialog(
                          title: Text('Error'),
                          content: Text('Please fill in all fields.'),
                        ),
                      );
                      return;
                    }
                    _addMarker(
                        position, titleController.text, descController.text);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            ));
  }

  //show marker information when tapped
  void showMarkerInfo(MarkerData markerData) {
    const url = "https://docs.fleaflet.dev/";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(markerData.title),
        content: Text(markerData.description),
        actions: [
          ElevatedButton(
            onPressed: () {
              launchUrl(Uri.parse(url));
            },
            child: const Text('Visit Website'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  //search features
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        // _isSearching = false;
      });
      return;
    }

    final url =
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5';

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);
    if (data.isNotEmpty) {
      setState(() {
        _searchResults = data;
      });
    } else {
      setState(() {
        _searchResults = [];
      });
    }
  }

  //move to specified location
  void _moveToLocation(double lat, double lon) {
    LatLng location = LatLng(lat, lon);
    _mapController.move(location, 9.2);
    setState(() {
      _selectedPostion = location;
      _searchResults = [];
      _isSearching = false;
      _searchController.clear();
    });
  }

  //initState to add listeners
  @override
  void initState() {
    // TODO: implement initState

    super.initState();
    _searchController.addListener(() {
      _searchPlaces(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(21.028511, 105.804817),
              initialZoom: 9.2,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(
                        Uri.parse('https://openstreetmap.org/copyright')),
                  ),
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}
