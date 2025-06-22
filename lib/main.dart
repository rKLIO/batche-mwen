import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Covoiturage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeMapPage(),
    );
  }
}

class HomeMapPage extends StatefulWidget {
  const HomeMapPage({super.key});

  @override
  State<HomeMapPage> createState() => _HomeMapPageState();
}

class _HomeMapPageState extends State<HomeMapPage> {
  GoogleMapController? mapController;
  BitmapDescriptor? _customIcon;
  bool _locationLoaded = false;
  LatLng _currentPosition = const LatLng(48.8566, 2.3522);
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  TimeOfDay? _selectedTime;

  String? _distance;
  String? _duration;

  final DraggableScrollableController _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _loadCustomMarker();
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _locationLoaded = true;
    });

    if (mapController != null) {
      mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
    }
  }

  Future<void> _loadCustomMarker() async {
    _customIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/marker.png',
    );
    _addMarkers();
    setState(() {});
  }

  void _addMarkers() {
    final positions = [
      LatLng(48.8584, 2.2945),
      LatLng(48.8606, 2.3376),
    ];

    for (int i = 0; i < positions.length; i++) {
      _markers.add(
        Marker(
          markerId: MarkerId('marker_$i'),
          position: positions[i],
          icon: _customIcon ?? BitmapDescriptor.defaultMarker,
        ),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_locationLoaded) {
      mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
    }
  }

  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    final apiKey = 'AIzaSyC6WGs0R4omeJlaqkWFa6WWOt41CuDMHCc';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$apiKey',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK') {
        final location = data['results'][0]['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
      }
    }
    return null;
  }

  Future<void> drawRoute(LatLng start, LatLng end) async {
    final apiKey = 'AIzaSyC6WGs0R4omeJlaqkWFa6WWOt41CuDMHCc';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$apiKey',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final points = _decodePolyline(data['routes'][0]['overview_polyline']['points']);
      final leg = data['routes'][0]['legs'][0];

      setState(() {
        _distance = leg['distance']['text'];
        _duration = leg['duration']['text'];
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          width: 5,
          points: points,
        ));
      });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return polyline;
  }

  void _showSearchTripSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      const Center(child: Icon(Icons.drag_handle)),
                      const SizedBox(height: 10),
                      Text(
                        'Rechercher un trajet',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _startController,
                        decoration: const InputDecoration(
                          labelText: 'Lieu de départ',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.isEmpty)
                                ? 'Veuillez entrer un lieu'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _endController,
                        decoration: const InputDecoration(
                          labelText: 'Lieu d\'arrivée',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.isEmpty)
                                ? 'Veuillez entrer un lieu'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time),
                        title: Text(
                          _selectedTime == null
                              ? 'Heure de départ'
                              : 'Heure choisie : ${_selectedTime!.format(context)}',
                        ),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (picked != null) {
                              setModalState(() {
                                _selectedTime = picked;
                              });
                            }
                          },
                          child: const Text('Sélectionner'),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            if (_selectedTime == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Veuillez choisir une heure')),
                              );
                              return;
                            }
                            final start = await getCoordinatesFromAddress(_startController.text);
                            final end = await getCoordinatesFromAddress(_endController.text);
                            if (start == null || end == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Adresse non trouvée')),
                              );
                              return;
                            }
                            Navigator.pop(context);
                            setState(() {
                              _markers.clear();
                              _markers.add(Marker(markerId: const MarkerId('start'), position: start));
                              _markers.add(Marker(markerId: const MarkerId('end'), position: end));
                            });
                            await drawRoute(start, end);
                          }
                        },
                        child: const Text('Rechercher'),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMenu(ScrollController scrollController) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        controller: scrollController,
        children: [
          const SizedBox(height: 10),
          const Center(child: Icon(Icons.drag_handle)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text("Rechercher un trajet"),
            onPressed: () => _showSearchTripSheet(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.directions_car),
            label: const Text("Proposer un trajet"),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité à venir')),
              );
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text("Derniers trajets",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (int i = 0; i < 5; i++)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text("Trajet #${i + 1}"),
              subtitle: const Text("Départ → Arrivée"),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: const [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text('Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profil'),
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Paramètres'),
            ),
            ListTile(
              leading: Icon(Icons.support),
              title: Text('Support'),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("Carte"),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 12.0,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          if (_distance != null && _duration != null)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'Distance : $_distance | Durée : $_duration',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.1,
            minChildSize: 0.1,
            maxChildSize: 0.5,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: _buildMenu(scrollController),
              );
            },
          ),
        ],
      ),
    );
  }
}
