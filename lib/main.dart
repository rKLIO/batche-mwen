import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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
  LatLng _currentPosition = const LatLng(48.8566, 2.3522); // Paris (exemple)
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
  }

  @override
  void dispose() {
    super.dispose();
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
      LatLng(48.8584, 2.2945), // Tour Eiffel
      LatLng(48.8606, 2.3376), // Louvre
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
      mapController?.animateCamera(
        CameraUpdate.newLatLng(_currentPosition),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer( // Menu latéral
        child: ListView(
          padding: EdgeInsets.zero,
          children: const [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
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
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          DraggableScrollableSheet(
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
                child: ListView(
                  controller: scrollController,
                  children: [
                    const SizedBox(height: 10),
                    const Center(child: Icon(Icons.drag_handle)),
                    const ListTile(
                      leading: Icon(Icons.search),
                      title: Text("Rechercher un trajet"),
                    ),
                    const ListTile(
                      leading: Icon(Icons.directions_car),
                      title: Text("Proposer un trajet"),
                    ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                      child: Text("Derniers trajets", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    for (int i = 0; i < 5; i++) // Liste statique de 5 trajets
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: Text("Trajet #${i + 1}"),
                        subtitle: const Text("Départ → Arrivée"),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
