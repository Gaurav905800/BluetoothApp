import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothFinderScreen extends StatefulWidget {
  const BluetoothFinderScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _BluetoothFinderScreenState createState() => _BluetoothFinderScreenState();
}

class _BluetoothFinderScreenState extends State<BluetoothFinderScreen> {
  FlutterBluePlus flutterBlue = FlutterBluePlus();
  List<BluetoothDevice> devicesList = [];
  bool isScanning = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (!devicesList.contains(r.device)) {
          setState(() {
            devicesList.add(r.device);
          });
        }
      }
      if (results.isNotEmpty) {
        setState(() {
          isLoading = false;
        });
      }
    });
  }

  Future<void> requestPermissions() async {
    var bluetoothStatus = await Permission.bluetooth.status;

    if (!bluetoothStatus.isGranted) {
      await Permission.bluetooth.request();
      bluetoothStatus = await Permission.bluetooth.status;
    }

    if (bluetoothStatus.isGranted) {
      var locationStatus = await Permission.locationWhenInUse.status;
      if (!locationStatus.isGranted) {
        await Permission.locationWhenInUse.request();
      }
    }
  }

  Future<void> checkBluetoothAndLocationStatus() async {
    // Check if Bluetooth is on
    // ignore: deprecated_member_use
    var isBluetoothOn = await FlutterBluePlus.isOn;
    if (!isBluetoothOn) {
      await requestBluetoothPermission();
      return;
    }

    var locationStatus = await Permission.locationWhenInUse.status;
    if (!locationStatus.isGranted) {
      await requestLocationPermission();
      return;
    }

    await startScan();
  }

  Future<void> requestBluetoothPermission() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Bluetooth'),
        content: const Text('Bluetooth is off. Please turn it on to continue.'),
        actions: [
          TextButton(
            onPressed: () async {
              await FlutterBluePlus.turnOn();
              // ignore: use_build_context_synchronously
              Navigator.of(context).pop();
              await checkBluetoothAndLocationStatus();
            },
            child: const Text('Turn On'),
          ),
        ],
      ),
    );
  }

  Future<void> requestLocationPermission() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Location'),
        content: const Text(
            'Location services are off. Please turn them on to continue.'),
        actions: [
          TextButton(
            onPressed: () async {
              await Permission.locationWhenInUse.request();
              // ignore: use_build_context_synchronously
              Navigator.of(context).pop();
              await checkBluetoothAndLocationStatus();
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Future<void> startScan() async {
    setState(() {
      isLoading = true;
      isScanning = true;
    });

    await requestPermissions();
    devicesList.clear();
    FlutterBluePlus.startScan();
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    setState(() {
      isScanning = false;
      isLoading = false;
    });
  }

  Future<void> refreshDevices() async {
    await stopScan();
    await startScan();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connect();
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      // ignore: deprecated_member_use
      SnackBar(content: Text('Connected to ${device.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Finder'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: isScanning ? stopScan : checkBluetoothAndLocationStatus,
            child: Text(isScanning ? 'Stop Scan' : 'Start Scan'),
          ),
          const Divider(
            color: Colors.grey,
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refreshDevices,
              child: devicesList.isEmpty && !isLoading
                  ? const Center(
                      child: Text("No devices found."),
                    )
                  : ListView.builder(
                      itemCount: devicesList.length,
                      itemBuilder: (context, index) {
                        final device = devicesList[index];
                        return ListTile(
                          // ignore: deprecated_member_use
                          title: Text(device.name.isEmpty
                              ? 'Unknown Device'
                              // ignore: deprecated_member_use
                              : device.name),
                          // ignore: deprecated_member_use
                          subtitle: Text(device.id.toString()),
                          trailing: IconButton(
                            icon: const Icon(Icons.bluetooth_connected),
                            onPressed: () => connectToDevice(device),
                            color: Colors.blue,
                          ),
                          onTap: () {
                            connectToDevice(device);
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
