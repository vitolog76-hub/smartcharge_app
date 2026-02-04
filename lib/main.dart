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
  
  DateTime? lockedStartDate; // Aggiungi questa qui
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

  final List<Color> _monthColors = [
    Colors.blueAccent, Colors.lightBlueAccent, Colors.cyanAccent,
    Colors.tealAccent, Colors.greenAccent, Colors.limeAccent,
    Colors.yellowAccent, Colors.orangeAccent, Colors.deepOrangeAccent,
    Colors.pinkAccent, Colors.purpleAccent, Colors.indigoAccent,
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _fetchRemoteModels(); 
    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (t) => _updateClock());
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  void _fetchRemoteModels() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('ev_models').orderBy('brand').get();
      if (snapshot.docs.isNotEmpty) {
        setState(() { remoteEvDatabase = snapshot.docs.map((doc) => doc.data()).toList(); });
      }
    } catch (e) { debugPrint("Firestore: $e"); }
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
        _showSnack("Backup recuperato: ${history.length} cariche");
      } else {
        setState(() => userId = newId);
        await prefs.setString('uid', newId);
        await _forceFirebaseSync();
        _showSnack("Nuovo profilo creato su Cloud");
      }
    } catch (e) { _showSnack("Errore Sync", isError: true); }
  }

  void _updateClock() {
    setState(() { now = DateTime.now(); });
    _recalcSchedule();
    if (isActive) {
      if (now.isAfter(fullStartDate!) && currentSoc < socTarget) {
        if (!isCharging) setState(() { isWaiting = false; isCharging = true; });
        _processCharging();
      } else if (now.isBefore(fullStartDate!)) {
        if (!isWaiting) setState(() { isWaiting = true; isCharging = false; });
        _lastTick = now;
      } else if (currentSoc >= socTarget) { _toggleSystem(); _save(true); }
    }
  }

  void _processCharging() async {
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
        currentSoc = (currentSoc + socAdded).clamp(0.0, 100.0); 
      });
      prefs.setDouble('currentSoc', currentSoc);
      prefs.setDouble('energySession', energySession);
      prefs.setInt('last_timestamp', nowCharge.millisecondsSinceEpoch);
    }
    _lastTick = nowCharge;
  }

  void _recalcSchedule() {
    DateTime target = DateTime(now.year, now.month, now.day, targetTimeInput.hour, targetTimeInput.minute);
    if (target.isBefore(now)) target = target.add(const Duration(days: 1));
    
    // Calcoliamo il tempo necessario basandoci sul socTarget meno quello attuale
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
    wallboxPwr = (prefs.getDouble('pwr') ?? 3.7).clamp(1.5, 11.0);
    costPerKwh = prefs.getDouble('cost') ?? 0.25;
    socStart = prefs.getDouble('soc_s') ?? 20.0;
    socTarget = prefs.getDouble('soc_t') ?? 80.0;
    targetTimeInput = TimeOfDay(hour: prefs.getInt('targetHour') ?? 7, minute: prefs.getInt('targetMinute') ?? 0);
    isActive = prefs.getBool('isActive') ?? false;
    currentSoc = prefs.getDouble('currentSoc') ?? socStart;
    energySession = prefs.getDouble('energySession') ?? 0.0;
    
    // RECUPERO ORA CONGELATA
    String? lockedStr = prefs.getString('lockedStartDate');
    if (lockedStr != null) lockedStartDate = DateTime.parse(lockedStr);

    _costCtrl.text = costPerKwh.toStringAsFixed(2);
    _capCtrl.text = batteryCap.toStringAsFixed(1);
    _pwrCtrl.text = wallboxPwr.toStringAsFixed(1);
    _uidCtrl.text = userId;
    
    final data = prefs.getString('logs');
    if (data != null) history = List<Map<String, dynamic>>.from(jsonDecode(data));
  });

  if (isActive) {
    _processCharging(); // Questo recupera i minuti persi mentre l'app era chiusa
  }
  _recalcSchedule();
  _forceFirebaseSync();
}

  void _updateParams({double? pwr, double? cap, double? cost}) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (pwr != null) { wallboxPwr = pwr.clamp(1.5, 11.0); _pwrCtrl.text = wallboxPwr.toStringAsFixed(1); }
      if (cap != null) { batteryCap = cap; _capCtrl.text = batteryCap.toStringAsFixed(1); }
      if (cost != null) { costPerKwh = cost; _costCtrl.text = cost.toStringAsFixed(2); }
    });
    if (pwr != null) prefs.setDouble('pwr', wallboxPwr);
    if (cap != null) { prefs.setDouble('cap', batteryCap); prefs.setString('vehicleName', selectedVehicle); }
    if (cost != null) prefs.setDouble('cost', costPerKwh);
    _recalcSchedule();
    _forceFirebaseSync();
  }

  void _toggleSystem() async {
  HapticFeedback.mediumImpact();
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    isActive = !isActive;
    if (!isActive) { 
      isWaiting = false; isCharging = false; _lastTick = null; 
      lockedStartDate = null; // Sblocca l'orario
      prefs.remove('last_timestamp');
      prefs.remove('lockedStartDate');
    } else { 
      _lastTick = DateTime.now(); 
      prefs.setInt('last_timestamp', _lastTick!.millisecondsSinceEpoch);
      
      // CONGELA L'ORA DI INIZIO ADESSO
      double kwhNeeded = ((socTarget - currentSoc) / 100) * batteryCap;
      int mins = ((kwhNeeded.clamp(0.0, 500) / wallboxPwr) * 60).round();
      DateTime target = DateTime(now.year, now.month, now.day, targetTimeInput.hour, targetTimeInput.minute);
      if (target.isBefore(now)) target = target.add(const Duration(days: 1));
      
      lockedStartDate = target.subtract(Duration(minutes: mins));
      prefs.setString('lockedStartDate', lockedStartDate!.toIso8601String());
      
      prefs.setDouble('soc_s', socStart);
      prefs.setDouble('currentSoc', currentSoc);
    }
  });
  prefs.setBool('isActive', isActive);
}

  void _save(bool tot) async {
    double kwh = tot ? (((socTarget - socStart)/100)*batteryCap) : energySession;
    if (kwh < 0) kwh = 0;
    _addLogEntry(DateTime.now(), kwh);
    setState(() { 
      if(tot) currentSoc = socTarget; 
      energySession = 0; isActive = false; isCharging = false; isWaiting = false; _lastTick = null;
    });
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('currentSoc', currentSoc);
    prefs.setDouble('energySession', 0.0);
    prefs.setBool('isActive', false);
    prefs.remove('last_timestamp');
  }

  void _addLogEntry(DateTime date, double kwh) async {
    final prefs = await SharedPreferences.getInstance();
    final log = {'date': date.toIso8601String(), 'kwh': kwh, 'cost': kwh * costPerKwh};
    setState(() { 
      history.insert(0, log);
      history.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
    });
    prefs.setString('logs', jsonEncode(history));
    _forceFirebaseSync();
    _showSnack("Salvato su Cloud!");
  }

  void _deleteCharge(int index) async {
    final removedItem = history[index];
    setState(() => history.removeAt(index));
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('logs', jsonEncode(history));
    _forceFirebaseSync();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text("Carica eliminata"),
      action: SnackBarAction(label: "ANNULLA", onPressed: () async {
        setState(() {
          history.insert(index, removedItem);
          history.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
        });
        prefs.setString('logs', jsonEncode(history));
        _forceFirebaseSync();
      }),
    ));
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.redAccent : const Color(0xFF101A26)));
  }

  Widget _liquidBackground() {
    return AnimatedBuilder(
      animation: _bgController, 
      builder: (context, child) => Stack(children: [
        Container(color: const Color(0xFF01080E)), 
        Positioned(top: -130 + (math.sin(_bgController.value * 2 * math.pi) * 50), left: -70, child: _glassCircle(600, Colors.cyanAccent.withOpacity(0.20))),
        Positioned(bottom: 30 + (math.cos(_bgController.value * 2 * math.pi) * 40), right: -120, child: _glassCircle(500, Colors.blueAccent.withOpacity(0.25))),
        Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: Container(color: Colors.black.withOpacity(0.25)))),
      ]),
    );
  }

  Widget _glassCircle(double s, Color c) => Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, c.withOpacity(0.1), Colors.transparent], stops: const [0.0, 0.45, 1.0])));

  @override
  Widget build(BuildContext context) {
    Color statusCol = isCharging ? Colors.greenAccent : (isWaiting ? Colors.orangeAccent : Colors.cyanAccent);
    return Scaffold(
      body: Stack(children: [
        _liquidBackground(),
        SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
          _header(),
          _compactMainRow(),
          _statusBadge(statusCol, isCharging ? "CARICA IN CORSO" : (isWaiting ? "IN ATTESA" : "SISTEMA OFF")),
          const SizedBox(height: 25),
          _premiumBatterySection(currentSoc), 
          _energyEstimates(),
          _paramSliders(), 
          const Spacer(),
          _controls(),
          const SizedBox(height: 15),
          _actionButtons(),
          const SizedBox(height: 10),
        ]))),
      ]),
    );
  }

  Widget _header() => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white30), onPressed: _showSettings),
    const Text("SMART CHARGE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.cyanAccent, fontSize: 18)),
    IconButton(icon: const Icon(Icons.history, color: Colors.cyanAccent), onPressed: _showHistory),
  ]));

  Widget _compactMainRow() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    // MODIFICA QUI: Se attivo usa l'ora bloccata, se spento usa quella calcolata
    _dateCol("INIZIO", isActive ? lockedStartDate : fullStartDate, isWaiting ? Colors.orangeAccent : Colors.white24),
    
    Column(children: [
      Text(DateFormat('HH:mm').format(now), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w100, fontFamily: 'monospace')),
      Text(DateFormat('EEE d MMM').format(now).toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white38)),
    ]),
    _dateCol("FINE", fullEndDate, Colors.cyanAccent),
  ]);

  Widget _dateCol(String t, DateTime? d, Color c) => Column(children: [
    Text(t, style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold)),
    Text(d != null ? DateFormat('HH:mm').format(d) : "--:--", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c)),
  ]);

  Widget _premiumBatterySection(double soc) {
    Color batteryColor = soc > 80 ? const Color(0xFF00FF95) : (soc > 30 ? const Color(0xFF00E5FF) : const Color(0xFFFF4D00));
    return Container(
      height: 115, padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Stack(children: [
          Container(color: const Color(0xFF020F16)),
          AnimatedBuilder(animation: _bgController, builder: (context, child) => CustomPaint(size: const Size(double.infinity, 115), painter: TechFlowPainter((soc / 100).clamp(0.0, 1.0), batteryColor, _bgController.value, isCharging))),
          Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(soc.toStringAsFixed(2).replaceFirst('.', ','), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w200, color: Colors.white, letterSpacing: -1)),
            const SizedBox(width: 4),
            const Text("%", style: TextStyle(fontSize: 20, color: Colors.white38)),
          ])),
        ])
      ),
    );
  }

  Widget _energyEstimates() {
    double kwh = (((socTarget - currentSoc) / 100) * batteryCap).clamp(0.0, 500.0);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _infoLabel("DA CARICARE", "${kwh.toStringAsFixed(1)} kWh", Colors.orangeAccent),
      _infoLabel("COSTO STIMATO", "€ ${(kwh * costPerKwh).toStringAsFixed(2)}", Colors.greenAccent),
    ]));
  }

  Widget _infoLabel(String l, String v, Color c) => Column(children: [Text(l, style: const TextStyle(fontSize: 9, color: Colors.white38)), Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c))]);
  Widget _statusBadge(Color col, String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: col.withOpacity(0.2))), child: Text(text, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.bold)));

  Widget _paramSliders() => Column(children: [
    _sliderRow("POTENZA WALLBOX", "${wallboxPwr.toStringAsFixed(1)} kW", wallboxPwr, 1.5, 11.0, 0.1, Colors.orangeAccent, (v) => _updateParams(pwr: v)),
    const SizedBox(height: 10),
    _sliderRowWithAction("CAPACITÀ BATTERIA", "${batteryCap.toStringAsFixed(1)} kWh", batteryCap, 10, 150, 0.1, Colors.cyanAccent, (v) => _updateParams(cap: v), _showVehicleSelector),
    Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: Colors.amberAccent.withOpacity(0.1), width: 0.5))),
          child: Text(
            selectedVehicle.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 4, fontFamily: 'monospace', color: Colors.amberAccent,
              shadows: [
                Shadow(color: Colors.orangeAccent.withOpacity(0.8), blurRadius: 10),
                Shadow(color: Colors.orangeAccent.withOpacity(0.5), blurRadius: 20),
                Shadow(color: Colors.amberAccent.withOpacity(0.3), blurRadius: 30),
              ],
            ),
          ),
        ),
      ),
    ),
  ]);

  Widget _sliderRow(String lab, String val, double v, double min, double max, double step, Color c, Function(double) onC) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(lab, style: const TextStyle(fontSize: 10, color: Colors.white38)), 
      Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))
    ]),
    Row(children: [
      IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.white24), onPressed: () => onC((v - step).clamp(min, max))),
      Expanded(child: Slider(value: v.clamp(min, max), min: min, max: max, activeColor: c, onChanged: onC)),
      IconButton(icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.white24), onPressed: () => onC((v + step).clamp(min, max))),
    ]),
  ]);

  Widget _sliderRowWithAction(String lab, String val, double v, double min, double max, double step, Color c, Function(double) onC, VoidCallback onAct) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(lab, style: const TextStyle(fontSize: 10, color: Colors.white38)),
      GestureDetector(onTap: onAct, child: Row(children: [
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)), 
        const SizedBox(width: 5), 
        const Icon(Icons.search, size: 16, color: Colors.cyanAccent)
      ])),
    ]),
    Row(children: [
      IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.white24), onPressed: () => onC((v - step).clamp(min, max))),
      Expanded(child: Slider(value: v.clamp(min, max), min: min, max: max, activeColor: c, onChanged: onC)),
      IconButton(icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.white24), onPressed: () => onC((v + step).clamp(min, max))),
    ]),
  ]);

  Widget _controls() => Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
    _touchControl("SoC START", "${socStart.toInt()}%", () => _verticalSlider(true)),
    _touchControl("SoC TARGET", "${socTarget.toInt()}%", () => _verticalSlider(false)),
    _touchControl("TARGET ORA", targetTimeInput.format(context), _pickTime),
  ]);

  Widget _touchControl(String l, String v, VoidCallback t) => InkWell(onTap: t, child: Column(children: [Text(l, style: const TextStyle(fontSize: 9, color: Colors.white38)), Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.cyanAccent))]));

  Widget _actionButtons() => Column(children: [
    SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _toggleSystem, style: ElevatedButton.styleFrom(backgroundColor: isActive ? Colors.redAccent : Colors.cyanAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(isActive ? "STOP SISTEMA" : "ATTIVA SMART CHARGE", style: const TextStyle(fontWeight: FontWeight.w900)))),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: OutlinedButton(onPressed: () => _save(false), child: const Text("SAVE PARTIAL"))),
      const SizedBox(width: 10),
      Expanded(child: ElevatedButton(onPressed: () => _save(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black), child: const Text("SAVE TOTAL"))),
    ]),
  ]);

  void _showSettings() {
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: const Color(0xFF0A141D),
      title: const Text("CONFIGURAZIONE"),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _settingField("COSTO €/kWh", _costCtrl),
        _settingField("POWER kW", _pwrCtrl),
        _settingField("CAPACITY kWh", _capCtrl),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _uidCtrl, decoration: const InputDecoration(labelText: "USER ID"), style: const TextStyle(fontSize: 10, fontFamily: 'monospace'))),
          IconButton(icon: const Icon(Icons.copy, size: 18, color: Colors.cyanAccent), onPressed: () { Clipboard.setData(ClipboardData(text: _uidCtrl.text)); _showSnack("ID copiato!"); }),
        ]),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { _updateParams(cost: double.tryParse(_costCtrl.text.replaceAll(',', '.')), pwr: double.tryParse(_pwrCtrl.text.replaceAll(',', '.')), cap: double.tryParse(_capCtrl.text.replaceAll(',', '.'))); _syncUser(_uidCtrl.text); Navigator.pop(c); }, child: const Text("SALVA"))),
      ])),
    ));
  }

  Widget _settingField(String l, TextEditingController c) => TextField(controller: c, decoration: InputDecoration(labelText: l), keyboardType: TextInputType.number);

  void _showVehicleSelector() {
    String? selectedBrand;
    List<String> brands = remoteEvDatabase.map((e) => e['brand'] as String).toSet().toList()..sort();
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF0A141D), isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))), builder: (c) => StatefulBuilder(builder: (context, setModalState) {
      List<Map<String, dynamic>> models = selectedBrand == null ? [] : remoteEvDatabase.where((e) => e['brand'] == selectedBrand).toList()..sort((a,b) => a['model'].compareTo(b['model']));
      return SizedBox(height: MediaQuery.of(context).size.height * 0.8, child: Column(children: [
        const SizedBox(height: 15),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.all(20), child: Row(children: [if (selectedBrand != null) IconButton(icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent), onPressed: () => setModalState(() => selectedBrand = null)), Text(selectedBrand ?? "SELEZIONA MARCA", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent))])),
        Expanded(child: selectedBrand == null ? ListView.builder(itemCount: brands.length, itemBuilder: (context, i) => ListTile(title: Text(brands[i]), onTap: () => setModalState(() => selectedBrand = brands[i]))) : ListView.builder(itemCount: models.length, itemBuilder: (context, i) => ListTile(title: Text(models[i]['model']), subtitle: Text("${models[i]['cap']} kWh"), onTap: () { setState(() { selectedVehicle = "${models[i]['brand']} ${models[i]['model']}"; batteryCap = (models[i]['cap'] as num).toDouble(); }); _updateParams(cap: batteryCap); Navigator.pop(context); })))
      ]));
    }));
  }

  void _verticalSlider(bool start) {
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, st) {
      return AlertDialog(
        backgroundColor: const Color(0xFF0A141D), 
        content: SizedBox(
          height: 380, 
          child: Column(
            children: [
              IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent, size: 35), onPressed: () => st(() { 
                if (start) { socStart = (socStart + 1).clamp(0, 100); currentSoc = socStart; } else { socTarget = (socTarget + 1).clamp(0, 100); }
              })),
              Text("${(start ? socStart : socTarget).toInt()}%", style: const TextStyle(fontSize: 36, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
              Expanded(child: RotatedBox(quarterTurns: 3, child: Slider(value: start ? socStart : socTarget, min: 0, max: 100, activeColor: Colors.cyanAccent, onChanged: (v) { st(() { if (start) { socStart = v.roundToDouble(); currentSoc = v.roundToDouble(); } else { socTarget = v.roundToDouble(); } }); }))),
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.cyanAccent, size: 35), onPressed: () => st(() { 
                if (start) { socStart = (socStart - 1).clamp(0, 100); currentSoc = socStart; } else { socTarget = (socTarget - 1).clamp(0, 100); }
              })),
              const SizedBox(height: 15),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { 
                final prefs = await SharedPreferences.getInstance();
                if(start) { prefs.setDouble('soc_s', socStart); prefs.setDouble('currentSoc', currentSoc); }
                else { prefs.setDouble('soc_t', socTarget); }
                setState(() {}); 
                Navigator.pop(c); 
              }, child: const Text("CONFERMA")))
            ],
          )
        )
      );
    }));
  }

  void _pickTime() async { 
    final t = await showTimePicker(context: context, initialTime: targetTimeInput); 
    if(t != null) { 
      setState(() { targetTimeInput = t; }); 
      final prefs = await SharedPreferences.getInstance(); 
      prefs.setInt('targetHour', t.hour); 
      prefs.setInt('targetMinute', t.minute); 
      _recalcSchedule();
    } 
  }

  void _showManualEntry(Function setModal) {
    DateTime manualDate = DateTime.now();
    TimeOfDay manualTime = TimeOfDay.now();
    final TextEditingController kwhCtrl = TextEditingController();
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, st) => AlertDialog(
      backgroundColor: const Color(0xFF0A141D),
      title: const Text("INSERIMENTO MANUALE", style: TextStyle(color: Colors.cyanAccent, fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(DateFormat('dd/MM/yyyy').format(manualDate)), leading: const Icon(Icons.calendar_today), onTap: () async { final d = await showDatePicker(context: context, initialDate: manualDate, firstDate: DateTime(2020), lastDate: DateTime.now()); if(d != null) st(() => manualDate = d); }),
        ListTile(title: Text(manualTime.format(context)), leading: const Icon(Icons.access_time), onTap: () async { final t = await showTimePicker(context: context, initialTime: manualTime); if(t != null) st(() => manualTime = t); }),
        TextField(controller: kwhCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "kWh caricati", suffixText: "kWh")),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("ANNULLA")),
        ElevatedButton(onPressed: () {
          double? k = double.tryParse(kwhCtrl.text.replaceAll(',', '.'));
          if (k != null) {
            DateTime finalDt = DateTime(manualDate.year, manualDate.month, manualDate.day, manualTime.hour, manualTime.minute);
            _addLogEntry(finalDt, k);
            Navigator.pop(c);
            setModal(() {}); 
          }
        }, child: const Text("SALVA"))
      ],
    )));
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF010A0F), isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))), 
      builder: (c) => StatefulBuilder(builder: (context, setModal) {
        Map<String, double> monthlyData = {}; 
        for (var log in history) {
          DateTime dt = DateTime.parse(log['date']);
          String key = DateFormat('MM/yy').format(dt);
          monthlyData[key] = (monthlyData[key] ?? 0) + (log['kwh'] ?? 0);
        }
        var sortedMonthKeys = monthlyData.keys.toList().reversed.toList();
        double maxKwh = monthlyData.values.isEmpty ? 1 : monthlyData.values.reduce(math.max);
        double totalKwh = history.fold(0, (s, i) => s + (i['kwh'] ?? 0));
        double totalCost = history.fold(0, (s, i) => s + (i['cost'] ?? 0));

        return SizedBox(height: MediaQuery.of(context).size.height * 0.85, child: Column(children: [
            const SizedBox(height: 15), 
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("ANALISI CONSUMI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.cyanAccent)),
              Row(children: [
                IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent), onPressed: () => _showManualEntry(setModal)),
                IconButton(icon: const Icon(Icons.download, color: Colors.greenAccent), onPressed: _exportCSV),
              ])
            ])),
            if (monthlyData.isNotEmpty) Container(
              height: 140, padding: const EdgeInsets.symmetric(horizontal: 10), 
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal, reverse: true, 
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end, 
                  children: List.generate(sortedMonthKeys.length, (index) {
                    String label = sortedMonthKeys[index];
                    int monthNum = int.parse(label.split('/')[0]) - 1; 
                    Color barColor = _monthColors[monthNum % 12];
                    double h = (monthlyData[label]! / maxKwh) * 80;
                    return Container(
                      width: 50, margin: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text("${monthlyData[label]!.toInt()}", style: TextStyle(fontSize: 9, color: barColor, fontWeight: FontWeight.bold)), 
                        const SizedBox(height: 4),
                        Container(width: 25, height: h.clamp(5, 80), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [barColor, barColor.withOpacity(0.1)]), borderRadius: BorderRadius.circular(4))), 
                        const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38))
                      ]),
                    ); 
                  }).reversed.toList(),
                ),
              )
            ),
            Container(padding: const EdgeInsets.all(15), margin: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                Column(children: [const Text("KWH TOT", style: TextStyle(fontSize: 10, color: Colors.white38)), Text(totalKwh.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.cyanAccent))]), 
                Column(children: [const Text("SPESA TOT", style: TextStyle(fontSize: 10, color: Colors.white38)), Text("€ ${totalCost.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.greenAccent))])
            ])),
            Expanded(child: ListView.builder(itemCount: history.length, itemBuilder: (c, i) {
                final item = history[i];
                return Dismissible(
                  key: Key(item['date'] + i.toString()), direction: DismissDirection.endToStart, 
                  background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.redAccent.withOpacity(0.2), child: const Icon(Icons.delete_outline, color: Colors.redAccent)),
                  onDismissed: (direction) { _deleteCharge(i); setModal(() {}); },
                  child: ListTile(
                    leading: const Icon(Icons.bolt, color: Colors.white12), 
                    title: Text(DateFormat('dd MMMM HH:mm', 'it_IT').format(DateTime.parse(item['date']))), 
                    subtitle: Text("${item['kwh'].toStringAsFixed(2)} kWh"), 
                    trailing: Text("€ ${item['cost'].toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ),
                );
            }))
        ]));
      })
    );
  }

  void _exportCSV() { String csv = "Data;kWh;Costo\n"; for (var l in history) csv += "${l['date']};${l['kwh']};${l['cost']}\n"; Clipboard.setData(ClipboardData(text: csv)); _showSnack("CSV Copiato!"); }
}

class TechFlowPainter extends CustomPainter {
  final double pct; final Color color; final double anim; final bool isPulsing;
  TechFlowPainter(this.pct, this.color, this.anim, this.isPulsing);

  @override
  void paint(Canvas canvas, Size size) {
    final double currentWidth = size.width * pct;
    if (currentWidth <= 0) return;
    canvas.clipRect(Rect.fromLTWH(0, 0, currentWidth, size.height));
    Paint fillPaint = Paint()..shader = LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [color.withOpacity(0.3), color, color.withOpacity(0.8)]).createShader(Rect.fromLTWH(0, 0, currentWidth, size.height));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, currentWidth, size.height), const Radius.circular(0)), fillPaint);
    if (isPulsing) {
      final double scanPos = (anim * currentWidth * 2) - currentWidth;
      Paint scanPaint = Paint()..shader = LinearGradient(colors: [Colors.transparent, Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.6), Colors.white.withOpacity(0.3), Colors.transparent], stops: const [0.0, 0.4, 0.5, 0.6, 1.0]).createShader(Rect.fromLTWH(scanPos, 0, currentWidth * 0.4, size.height));
      canvas.drawRect(Rect.fromLTWH(scanPos, 0, currentWidth * 0.4, size.height), scanPaint);
      final random = math.Random(42);
      Paint particlePaint = Paint()..color = Colors.white.withOpacity(0.4);
      for(int i=0; i<5; i++) {
        double px = random.nextDouble() * currentWidth;
        double py = random.nextDouble() * size.height;
        canvas.drawCircle(Offset(px, py), 1.5, particlePaint);
      }
    }
  }
  @override bool shouldRepaint(CustomPainter oldDelegate) => true;
}
