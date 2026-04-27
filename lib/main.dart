import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shake/shake.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Emergency App',
      theme: ThemeData.dark(),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> contacts = [];
  final TextEditingController _controller = TextEditingController();

  late stt.SpeechToText _speech;
  Timer? trackingTimer;
  bool isDangerMode = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    loadContacts();

    // 📳 Shake trigger
    ShakeDetector.autoStart(
      onPhoneShake: () {
        sendSOS(context);
      },
    );
  }

  // 💾 Save contacts
  Future<void> saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('contacts', contacts);
  }

  // 📂 Load contacts
  Future<void> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      contacts = prefs.getStringList('contacts') ?? [];
    });
  }

  // 📍 Get location
  Future<Position> getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception("Location OFF");

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return await Geolocator.getCurrentPosition();
  }

  // 📩 Send SMS
  Future<void> sendSMS(String message) async {
    for (String number in contacts) {
      final Uri smsUri = Uri.parse("sms:$number?body=$message");
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }
    }
  }

  // 🎤 Voice trigger
  void startListening() async {
    bool available = await _speech.initialize();

    if (available) {
      _speech.listen(
        onResult: (result) {
          String words = result.recognizedWords.toLowerCase();

          if (words.contains("help") ||
              words.contains("emergency") ||
              words.contains("save me")) {
            sendSOS(context);
          }
        },
      );
    }
  }

  // 📍 Live tracking
  void startLiveTracking() {
    trackingTimer?.cancel();

    trackingTimer =
        Timer.periodic(const Duration(seconds: 15), (timer) async {
      Position position = await getLocation();

      String msg =
          "📍 LIVE:\nhttps://www.google.com/maps?q=${position.latitude},${position.longitude}";

      await sendSMS(msg);
    });
  }

  void stopTracking() {
    trackingTimer?.cancel();
  }

  // 🚨 SOS
  void sendSOS(BuildContext context) async {
    try {
      Position position = await getLocation();

      String msg =
          "🚨 EMERGENCY ALERT!\n📍 https://www.google.com/maps?q=${position.latitude},${position.longitude}\n🕒 ${DateTime.now()}";

      await sendSMS(msg);

      if (isDangerMode) {
        startLiveTracking();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚨 SOS Sent!"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // ➕ Add contact
  void addContact() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        contacts.add(_controller.text);
        _controller.clear();
      });
      saveContacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E2C), Color(0xFF2D2D44)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              const Text(
                "Emergency Alert",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 30),

              // 🔴 SOS BUTTON
              GestureDetector(
                onTap: () => sendSOS(context),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.redAccent, Colors.red],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.7),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "SOS",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 🎤 Voice button
              ElevatedButton.icon(
                onPressed: startListening,
                icon: const Icon(Icons.mic),
                label: const Text("Voice SOS"),
              ),

              // 🔴 Danger Mode
              Card(
                margin: const EdgeInsets.all(10),
                child: SwitchListTile(
                  title: const Text("Danger Mode"),
                  subtitle: const Text("Auto live tracking"),
                  value: isDangerMode,
                  onChanged: (value) {
                    setState(() => isDangerMode = value);
                    if (!value) stopTracking();
                  },
                ),
              ),

              const Text("Add Emergency Contact"),

              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white10,
                    hintText: "Enter phone number",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),

              ElevatedButton(
                onPressed: addContact,
                child: const Text("Add Contact"),
              ),

              Expanded(
                child: ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    return Card(
                      color: Colors.white10,
                      child: ListTile(
                        leading: const Icon(Icons.phone),
                        title: Text(contacts[index]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}