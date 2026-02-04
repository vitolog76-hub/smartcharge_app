import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; 
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT', null);
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAjKI3YdGvyjTcjX9NH5EZBxS5eGN1saf4",
        authDomain: "smartcharge-2406b.firebaseapp.com",
        projectId: "smartcharge-2406b",
        storageBucket: "smartcharge-2406b.firebasestorage.app",
        messagingSenderId: "5458306840",
        appId: "1:5458306840:web:c36bfc00b2271e51f5206d",
      ),
    );
  } catch (e) { debugPrint("Firebase Bypass: $e"); }
  runApp(const SmartChargeApp());
}

class SmartChargeApp extends StatelessWidget {
  const SmartChargeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark, 
        scaffoldBackgroundColor: const Color(0xFF010A0F), 
        primaryColor: Colors.cyanAccent, 
        useMaterial3: true,
      ),
      home: const Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  String userId = "";
  String selectedVehicle = "Manuale / Altro";
  List<Map<String, dynamic>> remoteEvDatabase = []; 
  
  double batteryCap = 44.0; 
  double wallboxPwr = 3.7; 
  double costPerKwh = 0.25;
  double socStart = 20.0;
  double socTarget = 80.0;
  double currentSoc = 20.0;
  double energySession = 0.0;
  TimeOfDay targetTimeInput = const TimeOfDay(hour: 7, minute: 0);
  
  DateTime? lockedStartDate; 
  DateTime now = DateTime.now();
  DateTime? fullStartDate;
  DateTime? fullEndDate;

  bool isActive = false;
  bool isWaiting = false;
  bool isCharging = false;

  Timer? _clockTimer;
  DateTime? _lastTick;
  late AnimationController _bgController;

  List<Map<String, dynamic>> history = [];
  final TextEditingController _costCtrl = TextEditingController();
  final TextEditingController _capCtrl = TextEditingController();
  final TextEditingController _pwrCtrl = TextEditingController();
  final TextEditingController _uidCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _fetchRemoteModels(); 
    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (t) => _updateClock());
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _bgController.dispose();
    super.dispose();
  }

  void _fetchRemoteModels() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('ev_models').orderBy('brand').get();
      if (snapshot.docs.isNotEmpty) {
        setState(() { remoteEvDatabase = snapshot.docs.map((doc) => doc.data()).toList(); });
      }
    } catch (e) { debugPrint("Firestore: $e"); }
  }

  // --- LOGICA DI SINCRONIZZAZIONE CORRETTA ---
  void _syncUser(String newId) async {
    if (newId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(newId).get();
      if (doc.exists) {
        var data = doc.data()!;
        setState(() {
          userId = newId;
          if (data['history'] != null) {
            history = List<Map<String, dynamic>>.from(data['history']);
            history.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
          }
          if (data['batteryCap'] != null) batteryCap = (data['batteryCap'] as num).toDouble();
          if (data['wallboxPwr'] != null) wallboxPwr = (data['wallboxPwr'] as num).toDouble();
          if (data['vehicle'] != null) selectedVehicle = data['vehicle'];
        });
        await prefs.setString('uid', newId);
        await prefs.setString('logs', jsonEncode(history));
        _showSnack("Backup recuperato con successo!");
      } else {
        setState(() => userId = newId);
        await prefs.setString('uid', newId);
        _forceFirebaseSync();
        _showSnack("Nuovo ID registrato.");
      }
    } catch (e) { _showSnack("Errore sincronizzazione", isError: true); }
  }

  Future<void> _forceFirebaseSync() async {
    if (userId.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'history': history,
        'vehicle': selectedVehicle,
        'batteryCap': batteryCap,
        'wallboxPwr': wallboxPwr,
        'costPerKwh': costPerKwh,
        'lastUpdate': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) { debugPrint("Firebase Sync Error: $e"); }
  }

  // --- LOGICA DI ARRESTO CORRETTA (80%) ---
  void _updateClock() {
    setState(() { now = DateTime.now(); });
    _recalcSchedule();
    
    if (isActive) {
      // CONTROLLO DI ARRESTO: Se il SoC attuale raggiunge il target, ferma tutto
      if (currentSoc >= socTarget) {
        _toggleSystem(); // Spegne isActive, isCharging, ecc.
        _save(true);    // Apre il pop-up di riepilogo
        return; 
      }

      if (now.isAfter(fullStartDate!)) {
        if (!isCharging) setState(() { isWaiting = false; isCharging = true; });
        _processCharging();
      } else {
        if (!isWaiting) setState(() { isWaiting = true; isCharging = false; });
        _lastTick = now;
      }
    }
  }

  void _processCharging() async {
    if (currentSoc >= socTarget) return;

    final nowCharge = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    
    if (_lastTick == null) {
      int? lastTs = prefs.getInt('last_timestamp');
      _lastTick = lastTs != null ? DateTime.fromMillisecondsSinceEpoch(lastTs) : nowCharge;
    }
    
    double ms = nowCharge.difference(_lastTick!).inMilliseconds.toDouble();
    if (ms > 0) {
      double kwhAdded = (wallboxPwr * (ms / 3600000));
      double socAdded = (kwhAdded / batteryCap) * 100;
      setState(() { 
        energySession += kwhAdded; 
        currentSoc = (currentSoc + socAdded).clamp(0.0, socTarget); 
      });
      prefs.setDouble('currentSoc', currentSoc);
      prefs.setDouble('energySession', energySession);
      prefs.setInt('last_timestamp', nowCharge.millisecondsSinceEpoch);
    }
    _lastTick = nowCharge;
  }

  // --- RESTO DEL CODICE (Mantenuto dal tuo main.dart) ---
  void _recalcSchedule() {
    DateTime target = DateTime(now.year, now.month, now.day, targetTimeInput.hour, targetTimeInput.minute);
    if (target.isBefore(now)) target = target.add(const Duration(days: 1));
    double kwhNeeded = ((socTarget - currentSoc) / 100) * batteryCap;
    int mins = ((kwhNeeded.clamp(0.0, 500) / wallboxPwr) * 60).round();
    setState(() { 
      fullEndDate = target; 
      fullStartDate = target.subtract(Duration(minutes: mins)); 
    });
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('uid') ?? const Uuid().v4();
    selectedVehicle = prefs.getString('vehicleName') ?? "Manuale / Altro";
    setState(() {
      batteryCap = (prefs.getDouble('cap') ?? 44.0);
      wallboxPwr = (prefs.getDouble('pwr') ?? 3.7);
      costPerKwh = prefs.getDouble('cost') ?? 0.25;
      socStart = prefs.getDouble('soc_s') ?? 20.0;
      socTarget = prefs.getDouble('soc_t') ?? 80.0;
      targetTimeInput = TimeOfDay(hour: prefs.getInt('targetHour') ?? 7, minute: prefs.getInt('targetMinute') ?? 0);
      isActive = prefs.getBool('isActive') ?? false;
      currentSoc = prefs.getDouble('currentSoc') ?? socStart;
      energySession = prefs.getDouble('energySession') ?? 0.0;
      _costCtrl.text = costPerKwh.toStringAsFixed(2);
      _capCtrl.text = batteryCap.toStringAsFixed(1);
      _pwrCtrl.text = wallboxPwr.toStringAsFixed(1);
      _uidCtrl.text = userId;
      final data = prefs.getString('logs');
      if (data != null) history = List<Map<String, dynamic>>.from(jsonDecode(data));
    });
    if (isActive) _processCharging();
    _recalcSchedule();
  }

  void _updateParams({double? pwr, double? cap, double? cost}) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (pwr != null) { wallboxPwr = pwr; _pwrCtrl.text = pwr.toStringAsFixed(1); }
      if (cap != null) { batteryCap = cap; _capCtrl.text = cap.toStringAsFixed(1); }
      if (cost != null) { costPerKwh = cost; _costCtrl.text = cost.toStringAsFixed(2); }
    });
    if (pwr != null) prefs.setDouble('pwr', wallboxPwr);
    if (cap != null) prefs.setDouble('cap', batteryCap);
    if (cost != null) prefs.setDouble('cost', costPerKwh);
    _recalcSchedule();
    _forceFirebaseSync();
  }

  void _toggleSystem() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isActive = !isActive;
      if (!isActive) { isWaiting = false; isCharging = false; _lastTick = null; prefs.remove('last_timestamp'); }
      else { _lastTick = DateTime.now(); prefs.setInt('last_timestamp', _lastTick!.millisecondsSinceEpoch); }
    });
    prefs.setBool('isActive', isActive);
  }

  void _save(bool tot) async {
    double kwh = tot ? (((socTarget - socStart) / 100) * batteryCap) : energySession;
    if (kwh < 0) kwh = 0;
    double cost = kwh * costPerKwh;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF0A141D),
        title: const Text("RICARICA COMPLETATA"),
        content: Text("Hai caricato ${kwh.toStringAsFixed(2)} kWh\nCosto stimato: € ${cost.toStringAsFixed(2)}"),
        actions: [
          TextButton(onPressed: () { Navigator.pop(c); _resetAfterSession(tot); }, child: const Text("CHIUDI")),
          ElevatedButton(onPressed: () { Navigator.pop(c); _addLogEntry(DateTime.now(), kwh); _resetAfterSession(tot); }, child: const Text("SALVA NEL LOG")),
        ],
      ),
    );
  }

  void _resetAfterSession(bool tot) async {
    setState(() { if (tot) currentSoc = socTarget; energySession = 0; isActive = false; isCharging = false; isWaiting = false; });
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('currentSoc', currentSoc);
    prefs.setDouble('energySession', 0.0);
    prefs.setBool('isActive', false);
    prefs.remove('last_timestamp');
  }

  void _addLogEntry(DateTime date, double kwh) {
    final log = {'date': date.toIso8601String(), 'kwh': kwh, 'cost': kwh * costPerKwh};
    setState(() { history.insert(0, log); });
    _forceFirebaseSync();
  }

  // --- UI WIDGETS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        _liquidBackground(),
        SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
          _header(),
          _compactMainRow(),
          const SizedBox(height: 25),
          _premiumBatterySection(currentSoc), 
          _energyEstimates(),
          _paramSliders(), 
          const Spacer(),
          _controls(),
          const SizedBox(height: 15),
          _actionButtons(),
        ]))),
      ]),
    );
  }

  Widget _liquidBackground() => AnimatedBuilder(animation: _bgController, builder: (context, child) => Container(color: const Color(0xFF01080E)));
  Widget _header() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.settings), onPressed: _showSettings), const Text("SMART CHARGE"), IconButton(icon: const Icon(Icons.history), onPressed: () {})]);
  Widget _compactMainRow() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(DateFormat('HH:mm').format(now), style: const TextStyle(fontSize: 40))]);
  Widget _premiumBatterySection(double soc) => Container(height: 100, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)), child: Center(child: Text("${soc.toStringAsFixed(1)}%")));
  Widget _energyEstimates() => const SizedBox(height: 20);
  Widget _paramSliders() => Column(children: [_sliderRow("POTENZA", "${wallboxPwr}kW", wallboxPwr, 1.5, 11.0, (v) => _updateParams(pwr: v))]);
  Widget _sliderRow(String l, String v, double val, double min, double max, Function(double) onC) => Slider(value: val, min: min, max: max, onChanged: onC);
  Widget _controls() => Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Text("START ${socStart.toInt()}%"), Text("TARGET ${socTarget.toInt()}%")]);
  Widget _actionButtons() => ElevatedButton(onPressed: _toggleSystem, child: Text(isActive ? "STOP" : "START"));

  void _showSettings() {
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: const Color(0xFF0A141D),
      title: const Text("IMPOSTAZIONI"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _uidCtrl, decoration: const InputDecoration(labelText: "USER ID")),
        ElevatedButton(onPressed: () { _syncUser(_uidCtrl.text); Navigator.pop(c); }, child: const Text("SINCRONIZZA")),
      ]),
    ));
  }

  void _showSnack(String m, {bool isError = false}) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? Colors.red : Colors.blueGrey)); }
}