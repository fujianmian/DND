import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';

class MapPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final double? initialRadius;

  const MapPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialRadius,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _selectedLocation;
  double _radius = 100.0;
  GoogleMapController? _mapController;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<String> _suggestions = [];

  // TODO: Replace with your actual Google Cloud API Key
  final String _placesApiKey = dotenv.env['GOOGLE_MAPS_API_KEY']?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
      _radius = widget.initialRadius ?? 100.0;
    } else {
      _determinePosition();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  CameraPosition get _initialPosition {
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      return CameraPosition(
        target: LatLng(widget.initialLatitude!, widget.initialLongitude!),
        zoom: 16.0,
      );
    }
    return const CameraPosition(target: LatLng(3.055, 101.700), zoom: 14.4746);
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

  // Fetches autocomplete suggestions from Google Places API
  Future<void> _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    // Base URL
    String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$_placesApiKey';

    // 1. PRIORITIZE LOCAL RESULTS (Location Biasing)
    // We use the current map location or a default Malaysia coordinate to bias the search.
    // radius=50000 biases the search heavily toward places within 50km.
    final LatLng biasLoc = _selectedLocation ?? const LatLng(3.055, 101.700);
    url += '&location=${biasLoc.latitude},${biasLoc.longitude}&radius=50000';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            // 2. LIMIT TO 3 OPTIONS
            // We map the descriptions and grab only the first 3 items
            _suggestions = (data['predictions'] as List)
                .map((p) => p['description'] as String)
                .take(3)
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
  }

  // Converts the selected address string back into coordinates
  Future<void> _searchLocation(String address) async {
    // Hide keyboard and clear dropdown
    _searchFocusNode.unfocus();
    setState(() {
      _suggestions = [];
      _searchController.text = address;
    });

    if (address.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final target = LatLng(loc.latitude, loc.longitude);

        setState(() {
          _selectedLocation = target;
        });

        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16.0));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location details could not be resolved.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = {};
    Set<Circle> circles = {};

    if (_selectedLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('selected'),
          position: _selectedLocation!,
        ),
      );
      circles.add(
        Circle(
          circleId: const CircleId('radius'),
          center: _selectedLocation!,
          radius: _radius,
          fillColor: Colors.blue.withOpacity(0.2),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ),
      );
    }

    // Check if the keyboard is open
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          if (_selectedLocation != null)
            IconButton(
              icon: const Icon(Icons.check),
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
      body: Stack(
        children: [
          // Background Map Layer
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: markers,
            circles: circles,
            onTap: (LatLng location) {
              // Dismiss keyboard and dropdown when tapping map
              _searchFocusNode.unfocus();
              setState(() {
                _suggestions = [];
                _selectedLocation = location;
              });
            },
          ),

          // Search Bar & Dropdown Layer
          Positioned(
            top: 16.0,
            left: 16.0,
            right: 16.0,
            child: Column(
              children: [
                // Search Input Field
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search house plate or place...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                            ),
                            onPressed: _determinePosition,
                            tooltip: 'Current Location',
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),

                // Autocomplete Dropdown List
                if (_suggestions.isNotEmpty && _searchFocusNode.hasFocus)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 250,
                        ), // Limit dropdown height
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on_outlined),
                              title: Text(suggestion),
                              onTap: () => _searchLocation(suggestion),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Radius Slider Layer (Hidden when keyboard is active)
          if (_selectedLocation != null && !isKeyboardOpen)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Card(
                  margin: const EdgeInsets.all(16.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        // Wrap Text in a SizedBox with fixed width so the slider doesn't shift
                        SizedBox(
                          width:
                              130, // Slightly wider to fit the separated Row safely
                          child: Row(
                            children: [
                              const Text(
                                'Radius: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              // Dedicated fixed-width box for the number
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '${_radius.toInt()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign
                                      .right, // Anchors the text to the right, next to the 'm'
                                ),
                              ),
                              const Text(
                                'm',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _radius,
                            min: 50,
                            max: 1000,
                            divisions: 19,
                            onChanged: (value) {
                              // Only play sound/haptic when the slider value actually snaps to a new division
                              if (value != _radius) {
                                // 1. Play a subtle selection click vibration
                                HapticFeedback.selectionClick();
                                // 2. Play the system UI "tik" click sound
                                SystemSound.play(SystemSoundType.click);

                                setState(() => _radius = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
