import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _controller;
  LatLng? _selectedLocation;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (_selectedLocation == null) {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
              timeLimit: const Duration(seconds: 5));
          _selectedLocation = LatLng(pos.latitude, pos.longitude);
        }
      } catch (e) {
        debugPrint('Location capture failed: $e');
      }
    }
    
    // Default to Colombo if everything fails
    _selectedLocation ??= const LatLng(6.9271, 79.8612);

    if (mounted) {
      setState(() {
        _loading = false;
      });
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
      );
    }
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Delivery Location'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation ?? const LatLng(6.9271, 79.8612),
                    zoom: 15,
                  ),
                  onMapCreated: (controller) => _controller = controller,
                  onTap: _onMapTapped,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: _selectedLocation == null
                      ? {}
                      : {
                          Marker(
                            markerId: const MarkerId('selected-location'),
                            position: _selectedLocation!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueRed),
                            infoWindow: const InfoWindow(title: 'Delivery Pin'),
                          )
                        },
                ),
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: FilledButton(
                    onPressed: _selectedLocation == null
                        ? null
                        : () {
                            Navigator.of(context).pop(_selectedLocation);
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Confirm Location'),
                  ),
                ),
              ],
            ),
    );
  }
}
