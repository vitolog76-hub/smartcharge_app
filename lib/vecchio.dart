import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  } catch (e) { debugPrint("Firebase Bypass"); }
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
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
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
  double batteryCap = 44.0; 
  double wallboxPwr = 3.7; 
  double costPerKwh = 0.25;
  double socStart = 20.0;
  double socTarget = 80.0;
  double currentSoc = 20.0;
  double energySession = 0.0;
  TimeOfDay targetTimeInput = const TimeOfDay(hour: 7, minute: 0);
  
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
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (t) => _updateClock());
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _bgController.dispose();
    _costCtrl.dispose();
    _capCtrl.dispose();
    _pwrCtrl.dispose();
    _uidCtrl.dispose();
    super.dispose();
  }

  // --- LOGICA CORE ---
  void _showSnack(String msg, {bool isError = false}) {
    HapticFeedback.lightImpact(); 
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFF101A26),
    ));
  }

  void _syncUser(String newId) async {
    if (newId.isEmpty || newId == userId) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(newId).get();
      if (doc.exists) {
        setState(() {
          userId = newId;
          if (doc.data()?['history'] != null) {
            history = List<Map<String, dynamic>>.from(doc.data()?['history']);
            prefs.setString('logs', jsonEncode(history));
          }
        });
        prefs.setString('uid', newId);
        _showSnack("Dati recuperati con successo!");
      } else {
        setState(() => userId = newId);
        prefs.setString('uid', newId);
        _showSnack("Nuovo ID impostato");
      }
    } catch (e) { _showSnack("Errore Sincronizzazione", isError: true); }
  }

  void _updateClock() {
    setState(() { now = DateTime.now(); });
    _recalcSchedule();
    if (isActive && fullStartDate != null) {
      if (now.isAfter(fullStartDate!) && currentSoc < socTarget) {
        if (!isCharging) setState(() { isWaiting = false; isCharging = true; _lastTick = now; });
        _processCharging();
      } else if (now.isBefore(fullStartDate!)) {
        if (!isWaiting) setState(() { isWaiting = true; isCharging = false; });
      } else if (currentSoc >= socTarget) {
        _toggleSystem();
        _save(true);
      }
    }
  }

  void _processCharging() {
    if (_lastTick == null) return;
    final nowCharge = DateTime.now();
    double ms = nowCharge.difference(_lastTick!).inMilliseconds.toDouble();
    if (ms > 0) {
      double kwhAdded = (wallboxPwr * (ms / 3600000));
      double socAdded = (kwhAdded / batteryCap) * 100;
      setState(() { energySession += kwhAdded; currentSoc += socAdded; });
    }
    _lastTick = nowCharge;
  }

  void _recalcSchedule() {
    DateTime target = DateTime(now.year, now.month, now.day, targetTimeInput.hour, targetTimeInput.minute);
    if (target.isBefore(now)) target = target.add(const Duration(days: 1));
    double kwhNeeded = ((socTarget - currentSoc) / 100) * batteryCap;
    int mins = ((kwhNeeded.clamp(0, 500) / wallboxPwr) * 60).round();
    setState(() { fullEndDate = target; fullStartDate = target.subtract(Duration(minutes: mins)); });
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('uid') ?? const Uuid().v4();
    setState(() {
      batteryCap = (prefs.getDouble('cap') ?? 44.0);
      wallboxPwr = (prefs.getDouble('pwr') ?? 3.7).clamp(1.5, 11.0);
      costPerKwh = prefs.getDouble('cost') ?? 0.25;
      socStart = prefs.getDouble('soc_s') ?? 20.0;
      socTarget = prefs.getDouble('soc_t') ?? 80.0;
      currentSoc = socStart;
      _costCtrl.text = costPerKwh.toStringAsFixed(2);
      _capCtrl.text = batteryCap.toStringAsFixed(0);
      _pwrCtrl.text = wallboxPwr.toStringAsFixed(1);
      _uidCtrl.text = userId;
      final data = prefs.getString('logs');
      if (data != null) history = List<Map<String, dynamic>>.from(jsonDecode(data));
    });
    _recalcSchedule();
  }

  void _updateParams({double? pwr, double? cap, double? cost}) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (pwr != null) { wallboxPwr = pwr.clamp(1.5, 11.0); _pwrCtrl.text = wallboxPwr.toStringAsFixed(1); }
      if (cap != null) { batteryCap = cap; _capCtrl.text = cap.toStringAsFixed(0); }
      if (cost != null) { costPerKwh = cost; _costCtrl.text = cost.toStringAsFixed(2); }
    });
    if (pwr != null) prefs.setDouble('pwr', wallboxPwr);
    if (cap != null) prefs.setDouble('cap', batteryCap);
    if (cost != null) prefs.setDouble('cost', costPerKwh);
    _recalcSchedule();
  }

  void _toggleSystem() {
    HapticFeedback.mediumImpact();
    setState(() {
      isActive = !isActive;
      if (!isActive) { isWaiting = false; isCharging = false; }
      else { _recalcSchedule(); _lastTick = DateTime.now(); }
    });
  }

  void _save(bool tot) async {
    double kwh = tot ? (((socTarget - socStart)/100)*batteryCap) : energySession;
    final log = {'date': DateTime.now().toIso8601String(), 'kwh': kwh, 'cost': kwh * costPerKwh};
    setState(() { history.insert(0, log); if(tot) currentSoc = socTarget; energySession = 0; isActive = false; });
    (await SharedPreferences.getInstance()).setString('logs', jsonEncode(history));
    try { await FirebaseFirestore.instance.collection('users').doc(userId).set({'history': history, 'lastUpdate': DateTime.now()}); } catch(e){}
    _showSnack("Dati salvati nel Cloud!");
  }

  void _exportHistoryToCSV(String? filter) {
    String csv = "Data;kWh;Costo\n";
    var filtered = history.where((l) => filter == null || DateFormat('MM/yyyy').format(DateTime.parse(l['date'])) == filter).toList();
    for (var l in filtered) {
      csv += "${DateFormat('dd/MM HH:mm').format(DateTime.parse(l['date']))};${l['kwh'].toStringAsFixed(2)};${l['cost'].toStringAsFixed(2)}\n";
    }
    Clipboard.setData(ClipboardData(text: csv));
    _showSnack("CSV Copiato!");
  }

  // --- UI BACKGROUND ---
  Widget _liquidBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return Stack(
          children: [
            Container(color: const Color(0xFF020B12)),
            Positioned(
              top: -100 + (math.sin(_bgController.value * 2 * math.pi) * 50),
              left: -50 + (math.cos(_bgController.value * 2 * math.pi) * 50),
              child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.cyanAccent.withOpacity(0.08), Colors.transparent]))),
            ),
            Positioned(
              bottom: 100 + (math.cos(_bgController.value * 2 * math.pi) * 40),
              right: -80 + (math.sin(_bgController.value * 2 * math.pi) * 60),
              child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.blueAccent.withOpacity(0.1), Colors.transparent]))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color statusCol = isCharging ? Colors.greenAccent : (isWaiting ? Colors.orangeAccent : Colors.cyanAccent);
    return Scaffold(
      body: Stack(
        children: [
          _liquidBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                _header(),
                _compactMainRow(),
                _statusBadge(statusCol, isCharging ? "CARICA IN CORSO" : (isWaiting ? "IN ATTESA" : "SISTEMA OFF")),
                const SizedBox(height: 15),
                _horizontalBatteryWide(currentSoc), 
                _energyEstimates(),
                const SizedBox(height: 10),
                _paramSliders(), 
                const Spacer(),
                _controls(),
                const SizedBox(height: 15),
                _actionButtons(),
                const SizedBox(height: 10),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white30), onPressed: _showSettings),
      const Text("SMART CHARGE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.cyanAccent, fontSize: 18)),
      IconButton(icon: const Icon(Icons.history, color: Colors.cyanAccent), onPressed: _showHistory),
    ]),
  );

  Widget _compactMainRow() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    _dateCol("INIZIO", fullStartDate, isWaiting ? Colors.orangeAccent : Colors.white24),
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

  Widget _horizontalBatteryWide(double soc) {
    Color batteryColor = soc > 80 ? Colors.greenAccent : (soc > 30 ? Colors.cyanAccent : Colors.orangeAccent);
    return Container(
      height: 65, padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Stack(alignment: Alignment.center, children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: soc/100, backgroundColor: Colors.transparent, color: batteryColor.withOpacity(0.3), minHeight: 60)),
        Text("${soc.toStringAsFixed(1)}%", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: batteryColor)),
      ]),
    );
  }

  Widget _energyEstimates() {
    double kwh = (((socTarget - currentSoc) / 100) * batteryCap).clamp(0, 500);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 15), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _infoLabel("DA CARICARE", "${kwh.toStringAsFixed(1)} kWh", Colors.orangeAccent),
      _infoLabel("COSTO STIMATO", "€ ${(kwh * costPerKwh).toStringAsFixed(2)}", Colors.greenAccent),
    ]));
  }

  Widget _infoLabel(String l, String v, Color c) => Column(children: [Text(l, style: const TextStyle(fontSize: 9, color: Colors.white38)), Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c))]);

  Widget _statusBadge(Color col, String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: col.withOpacity(0.2))), child: Text(text, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.bold)));

  Widget _paramSliders() => Column(children: [
    _sliderRow("POTENZA WALLBOX", "${wallboxPwr.toStringAsFixed(1)} kW", wallboxPwr, 1.5, 11.0, 0.1, Colors.orangeAccent, (v) => _updateParams(pwr: v)),
    const SizedBox(height: 10),
    _sliderRow("CAPACITÀ BATTERIA", "${batteryCap.toInt()} kWh", batteryCap, 10, 150, 1.0, Colors.cyanAccent, (v) => _updateParams(cap: v)),
  ]);

  Widget _sliderRow(String lab, String val, double v, double min, double max, double step, Color c, Function(double) onC) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(lab, style: const TextStyle(fontSize: 10, color: Colors.white38)), Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))]),
    Row(children: [
      IconButton(icon: Icon(Icons.remove_circle_outline, color: c.withOpacity(0.3), size: 20), onPressed: () => onC((v - step).clamp(min, max))),
      Expanded(child: Slider(value: v.clamp(min, max), min: min, max: max, activeColor: c, onChanged: onC)),
      IconButton(icon: Icon(Icons.add_circle_outline, color: c.withOpacity(0.3), size: 20), onPressed: () => onC((v + step).clamp(min, max))),
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

  // --- IMPOSTAZIONI AGGIORNATE CON USER ID ---
  void _showSettings() {
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: const Color(0xFF0A141D),
      title: const Text("CONFIGURAZIONE", style: TextStyle(color: Colors.cyanAccent)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _settingField("COSTO €/kWh", _costCtrl),
          _settingField("POWER kW", _pwrCtrl),
          _settingField("CAPACITY kWh", _capCtrl),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const Text("USER ID (Device Sync)", style: TextStyle(fontSize: 10, color: Colors.white38)),
          TextField(controller: _uidCtrl, decoration: const InputDecoration(hintText: "Incolla il tuo ID qui")),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () { 
              _updateParams(
                cost: double.tryParse(_costCtrl.text.replaceAll(',', '.')), 
                pwr: double.tryParse(_pwrCtrl.text.replaceAll(',', '.')), 
                cap: double.tryParse(_capCtrl.text.replaceAll(',', '.'))
              ); 
              _syncUser(_uidCtrl.text);
              Navigator.pop(c); 
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            child: const Text("SALVA TUTTO")
          )
        ]),
      ),
    ));
  }

  Widget _settingField(String l, TextEditingController c) => TextField(controller: c, decoration: InputDecoration(labelText: l), keyboardType: const TextInputType.numberWithOptions(decimal: true));

  // --- SLIDER VERTICALE AGGIORNATO CON +/- ---
  void _verticalSlider(bool start) {
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, st) {
      double val = start ? socStart : socTarget;
      return AlertDialog(
        backgroundColor: const Color(0xFF0A141D), 
        content: SizedBox(height: 300, child: Column(children: [
          Text("${val.toInt()}%", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
          const SizedBox(height: 10),
          IconButton(icon: const Icon(Icons.add_circle_outline, size: 30), onPressed: () {
            double newVal = (val + 1).clamp(0, 100);
            setState(() { if(start){socStart=newVal;currentSoc=newVal;}else{socTarget=newVal;} _recalcSchedule(); });
            st(() {});
          }),
          Expanded(child: RotatedBox(quarterTurns: 3, child: Slider(
            value: val, min: 0, max: 100, activeColor: Colors.cyanAccent, 
            onChanged: (v) { st(() {}); setState((){ if(start){socStart=v;currentSoc=v;}else{socTarget=v;} _recalcSchedule(); }); }
          ))),
          IconButton(icon: const Icon(Icons.remove_circle_outline, size: 30), onPressed: () {
            double newVal = (val - 1).clamp(0, 100);
            setState(() { if(start){socStart=newVal;currentSoc=newVal;}else{socTarget=newVal;} _recalcSchedule(); });
            st(() {});
          }),
        ]))
      );
    }));
  }

  void _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: targetTimeInput);
    if(t != null) { setState(() { targetTimeInput = t; }); _recalcSchedule(); }
  }

  void _showHistory() {
    String? currentMonthFilter;
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF0A141D), isScrollControlled: true, builder: (c) => StatefulBuilder(builder: (context, setModalState) {
      var filtered = history.where((l) => currentMonthFilter == null || DateFormat('MM/yyyy').format(DateTime.parse(l['date'])) == currentMonthFilter).toList();
      double tK = filtered.fold(0, (s, i) => s + (i['kwh'] ?? 0));
      double tC = filtered.fold(0, (s, i) => s + (i['cost'] ?? 0));
      return SizedBox(height: MediaQuery.of(context).size.height * 0.8, child: Column(children: [
        Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("HISTORY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.cyanAccent)),
          IconButton(icon: const Icon(Icons.download, color: Colors.greenAccent), onPressed: () => _exportHistoryToCSV(currentMonthFilter))
        ])),
        if (history.isNotEmpty) Container(
          padding: const EdgeInsets.all(20), margin: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            Column(children: [const Text("ENERGY", style: TextStyle(fontSize: 10, color: Colors.white38)), Text("${tK.toStringAsFixed(1)} kWh", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.cyanAccent))]),
            Column(children: [const Text("COST", style: TextStyle(fontSize: 10, color: Colors.white38)), Text("€ ${tC.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.greenAccent))]),
          ]),
        ),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          ChoiceChip(label: const Text("All"), selected: currentMonthFilter == null, onSelected: (s) => setModalState(() => currentMonthFilter = null)),
          ...history.map((e) => DateFormat('MM/yyyy').format(DateTime.parse(e['date']))).toSet().map((m) => Padding(padding: const EdgeInsets.only(left: 8), child: ChoiceChip(label: Text(m), selected: currentMonthFilter == m, onSelected: (s) => setModalState(() => currentMonthFilter = s ? m : null)))),
        ])),
        Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (c, i) => ListTile(title: Text(DateFormat('dd/MM HH:mm').format(DateTime.parse(filtered[i]['date']))), subtitle: Text("${filtered[i]['kwh'].toStringAsFixed(2)} kWh"), trailing: Text("€ ${filtered[i]['cost'].toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)))))
      ]));
    }));
  }
}
