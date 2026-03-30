import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models.dart';
import '../services/api.dart';

class OrderTrackingScreen extends StatefulWidget {
  final OrderSummary order;
  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _api = ApiClient();
  GoogleMapController? _controller;
  Timer? _timer;
  
  Store? _store;
  DeliveryInfo? _delivery;
  Set<Marker> _markers = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialLoad();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _updateTracking());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    try {
      debugPrint('📍 OrderTracking: Loading store and delivery info for order ${widget.order.orderId}');
      if (widget.order.storeId != null) {
        _store = await _api.getStore(id: widget.order.storeId!);
        debugPrint('📍 OrderTracking: Store loaded - ${_store?.name} (${_store?.latitude}, ${_store?.longitude})');
      }
      _delivery = await _api.getDeliveryByOrderId(orderId: widget.order.orderId);
      if (_delivery != null) {
        debugPrint('📍 OrderTracking: Delivery found - Driver: ${_delivery?.driverName}, Status: ${_delivery?.status}');
        debugPrint('📍 OrderTracking: Delivery location - (${_delivery?.currentLatitude}, ${_delivery?.currentLongitude})');
      } else {
        debugPrint('📍 OrderTracking: No delivery assigned yet');
      }
      _updateMarkers();
      if (mounted) setState(() { _error = null; });
    } catch (e) {
      debugPrint('❌ Tracking load error: $e');
      if (mounted) setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _updateTracking() async {
    try {
      final d = await _api.getDeliveryByOrderId(orderId: widget.order.orderId);
      if (d != null && mounted) {
        setState(() {
          _delivery = d;
          _updateMarkers();
        });
        if (d.currentLatitude != null && d.currentLongitude != null) {
          _controller?.animateCamera(
            CameraUpdate.newLatLng(LatLng(d.currentLatitude!, d.currentLongitude!)),
          );
        }
      }
    } catch (e) {
      debugPrint('Tracking update error: $e');
    }
  }

  void _updateMarkers() {
    final newMarkers = <Marker>{};

    // Store Marker
    if (_store != null && _store!.latitude != null && _store!.longitude != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('store'),
        position: LatLng(_store!.latitude!, _store!.longitude!),
        infoWindow: InfoWindow(title: _store!.name, snippet: 'Pickup Point'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }

    // Customer Marker
    if (widget.order.deliveryLatitude != null && widget.order.deliveryLongitude != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('delivery'),
        position: LatLng(widget.order.deliveryLatitude!, widget.order.deliveryLongitude!),
        infoWindow: const InfoWindow(title: 'You', snippet: 'Delivery Point'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    // Driver Marker
    if (_delivery != null && _delivery!.currentLatitude != null && _delivery!.currentLongitude != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(_delivery!.currentLatitude!, _delivery!.currentLongitude!),
        infoWindow: InfoWindow(title: _delivery!.driverName ?? 'Driver', snippet: 'Current Location'),
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
              Text('Loading tracking information...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Track Order #${widget.order.orderId}')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading tracking: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _initialLoad, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    LatLng initialCameraPos = const LatLng(6.9271, 79.8612); // Default to Colombo
    if (_delivery?.currentLatitude != null && _delivery?.currentLongitude != null) {
      initialCameraPos = LatLng(_delivery!.currentLatitude!, _delivery!.currentLongitude!);
    } else if (widget.order.deliveryLatitude != null && widget.order.deliveryLongitude != null) {
      initialCameraPos = LatLng(widget.order.deliveryLatitude!, widget.order.deliveryLongitude!);
    } else if (_store?.latitude != null && _store?.longitude != null) {
      initialCameraPos = LatLng(_store!.latitude!, _store!.longitude!);
    } else if (_markers.isNotEmpty) {
      initialCameraPos = _markers.first.position;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Track Order #${widget.order.orderId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateTracking,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: initialCameraPos, zoom: 14),
              onMapCreated: (c) => _controller = c,
              markers: _markers,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: const Icon(Icons.delivery_dining, color: Colors.orange),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _delivery?.status ?? 'PREPARING',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(_delivery?.driverName ?? 'Awaiting driver assignment...'),
                      if (_delivery != null && _delivery!.currentLatitude == null)
                        const Text(
                          'Driver location not yet available',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                    ],
                  ),
                ),
                if (_delivery?.driverPhone != null)
                  IconButton(
                    icon: const Icon(Icons.phone, color: Colors.green),
                    onPressed: () {}, // TODO: Launch dialer
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
