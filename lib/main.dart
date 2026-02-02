import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(const SmartChargeApp());
}

class SmartChargeApp extends StatelessWidget {
  const SmartChargeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.cyanAccent,
        scaffoldBackgroundColor: const Color(0xFF020507),
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
  double batteryCapacity = 44.0;
  double wallboxPower = 3.7;
  double energyCost = 0.25; 
  double currentSoc = 20.0;
  double targetSoc = 80.0;
  TimeOfDay endChargeTime = const TimeOfDay(hour: 7, minute: 0);

  double simulatedSoc = 20.0;
  double energyDeliveredInSession = 0.0;
  bool isWaiting = false;
  bool isCharging = false;
  
  Timer? _ticker;
  DateTime? calculatedStartTime;
  DateTime? lastTimestamp;
  List<Map<String, dynamic>> chargeLogs = [];
  String? _userId;

  final TextEditingController _capController = TextEditingController();
  final TextEditingController _pwrDefController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  late AnimationController _pulseController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _loadAllData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('user_id');
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString('user_id', id);
    }
    _userId = id;

    final data = prefs.getString('charge_logs');
    
    setState(() {
      if (data != null) chargeLogs = List<Map<String, dynamic>>.from(jsonDecode(data));
      batteryCapacity = prefs.getDouble('default_battery_capacity') ?? 44.0;
      wallboxPower = prefs.getDouble('current_wallbox_power') ?? 3.7;
      energyCost = prefs.getDouble('energy_cost') ?? 0.25;
      _capController.text = batteryCapacity.toString();
      _pwrDefController.text = wallboxPower.toString();
      _costController.text = energyCost.toString();
      currentSoc = prefs.getDouble('current_soc') ?? 20.0;
      targetSoc = prefs.getDouble('target_soc') ?? 80.0;
      int? savedMinutes = prefs.getInt('end_charge_minutes');
      if (savedMinutes != null) endChargeTime = TimeOfDay(hour: savedMinutes ~/ 60, minute: savedMinutes % 60);
      isWaiting = prefs.getBool('is_waiting') ?? false;
      isCharging = prefs.getBool('is_charging') ?? false;
      simulatedSoc = currentSoc;
      energyDeliveredInSession = prefs.getDouble('session_energy') ?? 0.0;
    });

    _fetchLogsFromFirebase();
    _updateCalculation();
    if (isWaiting || isCharging) { lastTimestamp = DateTime.now(); _startHardTicker(); }
  }

  Future<void> _fetchLogsFromFirebase() async {
    if (_userId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('logs')
          .orderBy('date', descending: true)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final List<Map<String, dynamic>> firebaseLogs = snapshot.docs.map((doc) => doc.data()).toList();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('charge_logs', jsonEncode(firebaseLogs));
        setState(() { chargeLogs = firebaseLogs; });
      }
    } catch (e) {
      debugPrint("Errore sincronizzazione Firebase: $e");
    }
  }

  Future<void> _syncSettingsToFirebase() async {
    if (_userId == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(_userId).set({
        'settings': {
          'batteryCapacity': batteryCapacity,
          'wallboxPower': wallboxPower,
          'energyCost': energyCost,
          'targetSoc': targetSoc,
          'lastUpdated': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firebase Sync Error: $e");
    }
  }

  double get _totalEnergyRequired => ((targetSoc - currentSoc) / 100) * batteryCapacity;
  double get _remainingEnergy => _totalEnergyRequired - energyDeliveredInSession;

  void _updateCalculation() {
    if (targetSoc <= currentSoc) { calculatedStartTime = null; return; }
    double hoursNeeded = _totalEnergyRequired / wallboxPower;
    final now = DateTime.now();
    DateTime targetDateTime = DateTime(now.year, now.month, now.day, endChargeTime.hour, endChargeTime.minute);
    if (targetDateTime.isBefore(now)) targetDateTime = targetDateTime.add(const Duration(days: 1));
    setState(() {
      calculatedStartTime = targetDateTime.subtract(Duration(milliseconds: (hoursNeeded * 3600000).round()));
      if (!isCharging && !isWaiting) {
        simulatedSoc = currentSoc;
        energyDeliveredInSession = 0.0;
      }
    });
  }

  void _startHardTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      if (isCharging) {
        final double secondsPassed = now.difference(lastTimestamp!).inSeconds.toDouble();
        double addedKwh = (wallboxPower * secondsPassed) / 3600;
        setState(() {
          energyDeliveredInSession += addedKwh;
          simulatedSoc += (addedKwh / batteryCapacity) * 100;
          if (simulatedSoc >= targetSoc) {
            energyDeliveredInSession = _totalEnergyRequired;
            simulatedSoc = targetSoc;
            currentSoc = targetSoc;
            _stopSimulation();
          }
        });
        _saveCurrentState();
      } else if (isWaiting && calculatedStartTime != null) {
        if (now.isAfter(calculatedStartTime!)) { setState(() { isWaiting = false; isCharging = true; }); _saveCurrentState(); }
      }
      lastTimestamp = now;
    });
  }

  void _stopSimulation() { _ticker?.cancel(); setState(() { isCharging = false; isWaiting = false; }); _saveCurrentState(); }

  Future<void> _saveCurrentState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('current_soc', currentSoc);
    await prefs.setBool('is_waiting', isWaiting);
    await prefs.setBool('is_charging', isCharging);
    await prefs.setDouble('session_energy', energyDeliveredInSession);
    await prefs.setDouble('current_wallbox_power', wallboxPower);
    await prefs.setDouble('target_soc', targetSoc);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildCyberHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 15),
                    _buildMainSection(),
                    const SizedBox(height: 15),
                    _buildRealtimeCounter(),
                    const SizedBox(height: 15),
                    _buildQuickPowerSelector(),
                    const SizedBox(height: 15),
                    _buildControlInputs(),
                    const SizedBox(height: 15),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCyberHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.cyanAccent.withOpacity(0.1), width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.settings, color: Colors.white38, size: 20), onPressed: _showSettingsDialog),
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) => Text("PROVA2", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.cyanAccent, shadows: [Shadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: _glowController.value * 15)])),
          ),
          IconButton(icon: const Icon(Icons.analytics, color: Colors.cyanAccent, size: 20), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => LogView(logs: chargeLogs, costPerKwh: energyCost, userId: _userId)))),
        ],
      ),
    );
  }

  Widget _buildMainSection() {
    double totale = _totalEnergyRequired < 0 ? 0 : _totalEnergyRequired;
    double mancanti = _remainingEnergy < 0 ? 0 : _remainingEnergy;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCyberBattery(),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            children: [
              _compactStat("ENERGIA TOTALE", "${totale.toStringAsFixed(1)} kWh", "${(totale * energyCost).toStringAsFixed(2)} €", Colors.cyanAccent),
              const SizedBox(height: 8),
              _compactStat("MANCANTI", "${mancanti.toStringAsFixed(1)} kWh", "In ricarica...", Colors.orangeAccent),
              const SizedBox(height: 8),
              _compactStat("AVVIO PREVISTO", calculatedStartTime != null ? DateFormat('HH:mm').format(calculatedStartTime!) : "--:--", "Target: ${endChargeTime.format(context)}", Colors.white70),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compactStat(String label, String value, String sub, Color color) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 7, color: Colors.white38, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        Text(sub, style: TextStyle(fontSize: 8, color: color.withOpacity(0.5))),
      ]),
    );
  }

  Widget _buildRealtimeCounter() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) => Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12), border: Border.all(color: isCharging ? Colors.greenAccent.withOpacity(0.3) : Colors.white10)),
        child: Column(children: [
          Text("+ ${energyDeliveredInSession.toStringAsFixed(3)} kWh", style: TextStyle(color: isCharging ? Colors.greenAccent : Colors.white24, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
          if (isCharging) Text("${(energyDeliveredInSession * energyCost).toStringAsFixed(2)} €", style: const TextStyle(fontSize: 10, color: Colors.greenAccent)),
        ]),
      ),
    );
  }

  Widget _buildQuickPowerSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Text("Pwr", style: TextStyle(fontSize: 10, color: Colors.white38)),
        Expanded(child: Slider(value: wallboxPower, min: 1.0, max: 22.0, divisions: 42, activeColor: Colors.orangeAccent, onChanged: (v) { setState(() { wallboxPower = v; _updateCalculation(); }); _saveCurrentState(); _syncSettingsToFirebase(); })),
        Text("${wallboxPower.toStringAsFixed(1)} kW", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent, fontSize: 11)),
      ]),
    );
  }

  Widget _buildControlInputs() {
    return Row(children: [
      Expanded(child: _smallControl("SoC START", "${currentSoc.toInt()}%", () => _showVerticalSlider("ATTUALE", currentSoc, (v) => setState(() => currentSoc = v)))),
      const SizedBox(width: 8),
      Expanded(child: _smallControl("SoC TARGET", "${targetSoc.toInt()}%", () => _showVerticalSlider("TARGET", targetSoc, (v) { setState(() => targetSoc = v); _syncSettingsToFirebase(); }))),
      const SizedBox(width: 8),
      Expanded(child: _smallControl("FINE", endChargeTime.format(context), () async {
        final t = await showTimePicker(context: context, initialTime: endChargeTime);
        if (t != null) setState(() { endChargeTime = t; _updateCalculation(); });
      })),
    ]);
  }

  Widget _smallControl(String label, String value, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)), child: Column(children: [
      Text(label, style: const TextStyle(fontSize: 7, color: Colors.white38)),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
    ])));
  }

  void _showVerticalSlider(String title, double val, Function(double) onChg) {
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (context, setI) => AlertDialog(
      backgroundColor: const Color(0xFF0F171E),
      contentPadding: const EdgeInsets.symmetric(vertical: 20),
      content: SizedBox(height: 250, child: Column(children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 10),
        Text("${val.toInt()}%", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.cyanAccent)),
        Expanded(child: RotatedBox(quarterTurns: 3, child: Slider(value: val, min: 0, max: 100, divisions: 100, activeColor: Colors.cyanAccent, onChanged: (v) { setI(() => val = v); onChg(v); _updateCalculation(); }))),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("CONFERMA")),
      ])),
    )));
  }

  void _showSettingsDialog() {
    final TextEditingController _idRecController = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: const Color(0xFF0F171E), 
      title: const Text("SETTINGS & ACCOUNT", style: TextStyle(fontSize: 16)), 
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              const Text("IL TUO ID (Copia per recupero):", style: TextStyle(fontSize: 8, color: Colors.white38)),
              SelectableText(_userId ?? "...", style: const TextStyle(fontSize: 10, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 15),
          TextField(controller: _capController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Capacità (kWh)")),
          TextField(controller: _costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Costo (€/kWh)")),
          const Divider(height: 30),
          const Text("RECUPERA ACCOUNT", style: TextStyle(fontSize: 10, color: Colors.cyanAccent)),
          TextField(controller: _idRecController, decoration: const InputDecoration(labelText: "Inserisci vecchio ID", labelStyle: TextStyle(fontSize: 10))),
        ]),
      ), 
      actions: [
        TextButton(onPressed: () async {
          if (_idRecController.text.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_id', _idRecController.text.trim());
            Navigator.pop(c);
            _loadAllData();
          }
        }, child: const Text("RECUPERA ID", style: TextStyle(color: Colors.orangeAccent))),
        ElevatedButton(onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          setState(() { batteryCapacity = double.tryParse(_capController.text) ?? 44.0; energyCost = double.tryParse(_costController.text) ?? 0.25; wallboxPower = double.tryParse(_pwrDefController.text) ?? 3.7; });
          await prefs.setDouble('default_battery_capacity', batteryCapacity); await prefs.setDouble('energy_cost', energyCost); await prefs.setDouble('current_wallbox_power', wallboxPower);
          _updateCalculation(); 
          _syncSettingsToFirebase();
          Navigator.pop(c);
        }, child: const Text("SALVA"))
      ]
    ));
  }

  Widget _buildCyberBattery() {
    Color activeColor = isCharging ? Colors.greenAccent : Colors.cyanAccent;
    return Container(width: 80, height: 140, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(15), border: Border.all(color: activeColor.withOpacity(0.4), width: 2)), child: Stack(alignment: Alignment.bottomCenter, children: [
      ClipRRect(borderRadius: BorderRadius.circular(13), child: FractionallySizedBox(heightFactor: (simulatedSoc / 100).clamp(0.01, 1.0), widthFactor: 1, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [activeColor.withOpacity(0.6), activeColor.withOpacity(0.1)]))))),
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("${simulatedSoc.toInt()}%", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Icon(isCharging ? Icons.bolt : Icons.power, size: 14, color: activeColor)]))
    ]));
  }

  Widget _buildActionButtons() {
    return Column(children: [
      SizedBox(width: double.infinity, height: 40, child: ElevatedButton(onPressed: _controlSimulation, style: ElevatedButton.styleFrom(backgroundColor: isCharging || isWaiting ? Colors.redAccent.withOpacity(0.1) : Colors.cyanAccent.withOpacity(0.1), foregroundColor: isCharging || isWaiting ? Colors.redAccent : Colors.cyanAccent, side: BorderSide(color: isCharging || isWaiting ? Colors.redAccent : Colors.cyanAccent, width: 2)), child: Text(isCharging ? "STOP" : (isWaiting ? "CANCEL" : "START SMART CHARGE"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _smallBtn("SAVE", Icons.save, Colors.greenAccent, () async { if (energyDeliveredInSession > 0.01) { await _addLogEntry(energyDeliveredInSession); setState(() { currentSoc = simulatedSoc; energyDeliveredInSession = 0.0; _updateCalculation(); }); } })),
        const SizedBox(width: 8),
        Expanded(child: _smallBtn("FULL", Icons.bolt, Colors.orangeAccent, () async { if (targetSoc > currentSoc) { await _addLogEntry(_totalEnergyRequired); setState(() { currentSoc = targetSoc; simulatedSoc = targetSoc; energyDeliveredInSession = 0.0; _updateCalculation(); }); } })),
      ])
    ]);
  }

  Widget _smallBtn(String l, IconData i, Color c, VoidCallback p) => OutlinedButton.icon(onPressed: p, icon: Icon(i, size: 12), label: Text(l, style: const TextStyle(fontSize: 9)), style: OutlinedButton.styleFrom(foregroundColor: c, side: BorderSide(color: c.withOpacity(0.5))));

  void _controlSimulation() { if (isWaiting || isCharging) { _stopSimulation(); } else { if (calculatedStartTime == null) return; setState(() { isWaiting = true; simulatedSoc = currentSoc; energyDeliveredInSession = 0.0; lastTimestamp = DateTime.now(); }); _saveCurrentState(); _startHardTicker(); } }

  Future<void> _addLogEntry(double kwh) async {
    final prefs = await SharedPreferences.getInstance();
    final logId = DateTime.now().millisecondsSinceEpoch;
    final dateStr = DateTime.now().toIso8601String();
    final newLog = {'id': logId, 'date': dateStr, 'kwh': kwh, 'cost': kwh * energyCost};
    
    setState(() { chargeLogs.insert(0, newLog); }); 
    await prefs.setString('charge_logs', jsonEncode(chargeLogs));
    
    if (_userId != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(_userId).collection('logs').doc(logId.toString()).set(newLog);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("DATABASE AGGIORNATO!"), backgroundColor: Colors.green),
          );
        }
      } catch (e) { 
        debugPrint("Firebase Error: $e");
      }
    }
  }
}

class LogView extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  final double costPerKwh;
  final String? userId;
  const LogView({super.key, required this.logs, required this.costPerKwh, this.userId});
  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late List<Map<String, dynamic>> localLogs;
  String selectedFilter = "Tutto";
  @override
  void initState() { super.initState(); localLogs = List.from(widget.logs); }

  List<Map<String, dynamic>> get filteredLogs {
    if (selectedFilter == "Tutto") return localLogs;
    return localLogs.where((log) => DateFormat('MMMM yyyy').format(DateTime.parse(log['date'])) == selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    Set<String> months = localLogs.map((e) => DateFormat('MMMM yyyy').format(DateTime.parse(e['date']))).toSet();
    double totalKwh = filteredLogs.fold(0, (sum, item) => sum + item['kwh']);
    double totalCost = filteredLogs.fold(0, (sum, item) => sum + (item['cost'] ?? 0));
    return Scaffold(
      appBar: AppBar(title: const Text("LOGS"), actions: [
        DropdownButton<String>(
          value: selectedFilter,
          underline: const SizedBox(),
          items: ["Tutto", ...months].map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => selectedFilter = v!),
        ),
        const SizedBox(width: 10),
      ]),
      body: Column(children: [
        Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(15)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _logStat("kWh", totalKwh.toStringAsFixed(1)),
          _logStat("SPESA", "${totalCost.toStringAsFixed(2)} €"),
        ])),
        Expanded(child: ListView.builder(itemCount: filteredLogs.length, itemBuilder: (c, i) => ListTile(
          title: Text(DateFormat('dd/MM HH:mm').format(DateTime.parse(filteredLogs[i]['date']))),
          subtitle: Text("${filteredLogs[i]['kwh'].toStringAsFixed(2)} kWh"),
          trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text("${(filteredLogs[i]['cost'] ?? 0).toStringAsFixed(2)} €", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent), onPressed: () async {
              final id = filteredLogs[i]['id'];
              final prefs = await SharedPreferences.getInstance();
              setState(() { localLogs.removeWhere((l) => l['id'] == id); });
              await prefs.setString('charge_logs', jsonEncode(localLogs));
              if (widget.userId != null) {
                FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('logs').doc(id.toString()).delete();
              }
            }),
          ]),
        ))),
      ]),
    );
  }
  Widget _logStat(String l, String v) => Column(children: [Text(l, style: const TextStyle(fontSize: 9, color: Colors.white38)), Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.cyanAccent))]);
}
