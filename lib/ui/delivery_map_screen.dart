import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models.dart';
import '../services/api.dart';

class DeliveryMapScreen extends StatefulWidget {
  final DeliveryInfo delivery;
  final OrderSummary order;
  const DeliveryMapScreen({super.key, required this.delivery, required this.order});

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  final _api = ApiClient();
  GoogleMapController? _controller;
  StreamSubscription<Position>? _positionStream;
  
  Store? _store;
  Set<Marker> _markers = {};
  Position? _currentPosition;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      debugPrint('🗺️ DeliveryMap: Initializing driver map for order ${widget.order.orderId}');
      
      // 1. Get Store Cords
      if (widget.order.storeId != null) {
        _store = await _api.getStore(id: widget.order.storeId!);
        debugPrint('🗺️ DeliveryMap: Store loaded - ${_store?.name} (${_store?.latitude}, ${_store?.longitude})');
      }

      // 2. Request Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('🗺️ DeliveryMap: Location permission requested: $permission');
      }

      // 3. Start Tracking
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        _currentPosition = await Geolocator.getCurrentPosition();
        debugPrint('🗺️ DeliveryMap: Current position: (${_currentPosition?.latitude}, ${_currentPosition?.longitude})');
        
        if (_currentPosition != null) {
          await _updateBackend(_currentPosition!);
        }

        _positionStream = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((pos) {
          if (mounted) {
            setState(() {
              _currentPosition = pos;
              _updateMarkers();
              _updateBackend(pos);
            });
            _controller?.animateCamera(CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)));
          }
        }, onError: (e) {
          debugPrint('❌ DeliveryMap: Position stream error: $e');
        });
      } else {
        debugPrint('⚠️ DeliveryMap: Location permission not granted: $permission');
      }
      
      _updateMarkers();
    } catch (e) {
      debugPrint('❌ DeliveryMap Init Error: $e');
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _updateBackend(Position pos) async {
    try {
      await _api.updateDelivery(
        id: widget.delivery.id,
        currentLatitude: pos.latitude,
        currentLongitude: pos.longitude,
      );
    } catch (e) {
      debugPrint('Backend Update Error: $e');
    }
  }

  void _updateMarkers() {
    final newMarkers = <Marker>{};

    // Store Marker (Pickup)
    if (_store != null && _store!.latitude != null && _store!.longitude != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(_store!.latitude!, _store!.longitude!),
        infoWindow: InfoWindow(title: _store!.name, snippet: 'Pickup Point'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }

    // Delivery Marker (Dropoff)
    if (widget.order.deliveryLatitude != null && widget.order.deliveryLongitude != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: LatLng(widget.order.deliveryLatitude!, widget.order.deliveryLongitude!),
        infoWindow: const InfoWindow(title: 'Customer', snippet: 'Delivery Point'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    // Current Marker (Driver)
    if (_currentPosition != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('current'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        infoWindow: const InfoWindow(title: 'My Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    setState(() { _markers = newMarkers; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Starting GPS tracking for delivery...'),
            ],
          ),
        ),
      );
    }

    final initialPos = _currentPosition != null 
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : (_markers.isNotEmpty ? _markers.first.position : const LatLng(6.9271, 79.8612));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Navigation'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initialPos, zoom: 15),
            onMapCreated: (c) => _controller = c,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Order Status: ${widget.order.status}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Divider(),
                    if (_currentPosition != null)
                      Text(
                        'Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            debugPrint('Navigate button pressed');
                          }, // TODO: Launch Maps for Navigation
                          icon: const Icon(Icons.navigation),
                          label: const Text('Navigate'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                             try {
                               String newStatus = widget.delivery.status == 'PENDING' ? 'PICKED_UP' : 'DELIVERED';
                               debugPrint('🗺️ Updating delivery status: ${widget.delivery.status} -> $newStatus');
                               await _api.updateDelivery(id: widget.delivery.id, status: newStatus);
                               if (mounted) Navigator.pop(context);
                             } catch (e) {
                               debugPrint('❌ Status update error: $e');
                               if (mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                               }
                             }
                          },
                          child: const Text('Update Status'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
