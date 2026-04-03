import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerScreen extends StatefulWidget {
  @override
  _MapPickerScreenState createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _selectedLocation;
  double _radius = 100.0; // Default 100m
  GoogleMapController? _mapController;

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(3.055, 101.700), // Default fallback
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position position = await Geolocator.getCurrentPosition();
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
    );
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = {};
    Set<Circle> circles = {};

    if (_selectedLocation != null) {
      markers.add(
        Marker(markerId: MarkerId('selected'), position: _selectedLocation!),
      );
      circles.add(
        Circle(
          circleId: CircleId('radius'),
          center: _selectedLocation!,
          radius: _radius,
          fillColor: Colors.blue.withOpacity(0.2),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Select Location'),
        actions: [
          if (_selectedLocation != null)
            IconButton(
              icon: Icon(Icons.check),
              onPressed: () {
                Navigator.pop(context, {
                  'latitude': _selectedLocation!.latitude,
                  'longitude': _selectedLocation!.longitude,
                  'radius': _radius.toInt(),
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _defaultPosition,
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: true,
              markers: markers,
              circles: circles,
              onTap: (LatLng location) {
                setState(() {
                  _selectedLocation = location;
                });
              },
            ),
          ),
          if (_selectedLocation != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text('Radius: ${_radius.toInt()}m'),
                  Expanded(
                    child: Slider(
                      value: _radius,
                      min: 50,
                      max: 1000,
                      divisions: 19,
                      onChanged: (value) => setState(() => _radius = value),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
