import 'dart:async';
import 'dart:convert';
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
        scaffoldBackgroundColor: const Color(0xFF020609), 
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

class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
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
  AnimationController? _pulseController;

  List<Map<String, dynamic>> history = [];
  final TextEditingController _costCtrl = TextEditingController();
  final TextEditingController _capCtrl = TextEditingController();
  final TextEditingController _pwrCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (t) => _updateClock());
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulseController?.dispose();
    _costCtrl.dispose();
    _capCtrl.dispose();
    _pwrCtrl.dispose();
    super.dispose();
  }

  // --- LOGICA CORE ---

  void _showSnack(String msg, {bool isError = false}) {
    HapticFeedback.lightImpact(); 
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline, 
             color: isError ? Colors.redAccent : Colors.greenAccent, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
      backgroundColor: const Color(0xFF101A26),
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isError ? Colors.redAccent.withOpacity(0.5) : Colors.greenAccent.withOpacity(0.5),
          width: 1,
        ),
      ),
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
        _showSnack("Dati sincronizzati");
      } else {
        setState(() => userId = newId);
        prefs.setString('uid', newId);
        _showSnack("Nuovo ID impostato");
      }
    } catch (e) { _showSnack("Errore sincronizzazione", isError: true); }
  }

  void _updateClock() {
    setState(() { now = DateTime.now(); });
    _recalcSchedule();
    if (isActive) {
      if (fullStartDate != null) {
        if (now.isBefore(fullStartDate!)) {
          if (!isWaiting) setState(() { isWaiting = true; isCharging = false; });
        } else if (now.isAfter(fullStartDate!) && currentSoc < socTarget) {
          if (!isCharging) {
             setState(() { isWaiting = false; isCharging = true; _lastTick = now; });
             _showSnack("Ricarica avviata!");
          }
          _processCharging();
        } else if (currentSoc >= socTarget) {
          _toggleSystem();
          _save(true);
        }
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
    if (kwhNeeded < 0) kwhNeeded = 0;
    double hoursNeeded = kwhNeeded / wallboxPwr;
    int minutesNeeded = (hoursNeeded * 60).round();
    setState(() {
      fullEndDate = target;
      fullStartDate = target.subtract(Duration(minutes: minutesNeeded));
    });
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('uid') ?? const Uuid().v4();
    if (prefs.getString('uid') == null) prefs.setString('uid', userId);
    setState(() {
      batteryCap = (prefs.getDouble('cap') ?? 44.0).clamp(30.0, 90.0);
      wallboxPwr = (prefs.getDouble('pwr') ?? 3.7).clamp(1.0, 22.0);
      costPerKwh = prefs.getDouble('cost') ?? 0.25;
      socStart = prefs.getDouble('soc_s') ?? 20.0;
      socTarget = prefs.getDouble('soc_t') ?? 80.0;
      currentSoc = socStart;
      _costCtrl.text = costPerKwh.toStringAsFixed(2);
      _capCtrl.text = batteryCap.toStringAsFixed(0);
      _pwrCtrl.text = wallboxPwr.toStringAsFixed(1);
      final data = prefs.getString('logs');
      if (data != null) history = List<Map<String, dynamic>>.from(jsonDecode(data));
    });
    _recalcSchedule();
  }

  void _updateParams({double? pwr, double? cap, double? cost}) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (pwr != null) { wallboxPwr = pwr; _pwrCtrl.text = pwr.toStringAsFixed(1); }
      if (cap != null) { batteryCap = cap; _capCtrl.text = cap.toStringAsFixed(0); }
      if (cost != null) { costPerKwh = cost; _costCtrl.text = cost.toStringAsFixed(2); }
    });
    if (pwr != null) prefs.setDouble('pwr', pwr);
    if (cap != null) prefs.setDouble('cap', cap);
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

  void _deleteHistoryItem(int index) async {
    setState(() => history.removeAt(index));
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('logs', jsonEncode(history));
    try { await FirebaseFirestore.instance.collection('users').doc(userId).update({'history': history}); } catch(e){}
    _showSnack("Ricarica eliminata");
  }

  void _save(bool tot) async {
    double kwh = tot ? (((socTarget - socStart)/100)*batteryCap) : energySession;
    final log = {'date': DateTime.now().toIso8601String(), 'kwh': kwh, 'cost': kwh * costPerKwh};
    setState(() { history.insert(0, log); if(tot) { currentSoc = socTarget; } energySession = 0; isActive = false; });
    (await SharedPreferences.getInstance()).setString('logs', jsonEncode(history));
    try { await FirebaseFirestore.instance.collection('users').doc(userId).set({'history': history, 'lastUpdate': DateTime.now()}); } catch(e){}
    _showSnack("Ricarica archiviata: ${kwh.toStringAsFixed(2)} kWh");
  }

  // --- LOGICA ESPORTAZIONE CSV CON TOTALI ---

  void _exportHistoryToCSV(String? monthFilter) {
    String csv = "Data;Ora;kWh;Costo(Euro)\n";
    double totalKwh = 0;
    double totalCost = 0;

    var filteredLogs = history.where((log) {
      if (monthFilter == null) return true;
      DateTime date = DateTime.parse(log['date']);
      return DateFormat('MM/yyyy').format(date) == monthFilter;
    }).toList();

    if (filteredLogs.isEmpty) {
      _showSnack("Nessun dato da esportare", isError: true);
      return;
    }

    for (var log in filteredLogs) {
      DateTime dt = DateTime.parse(log['date']);
      double kwh = log['kwh'] ?? 0.0;
      double cost = log['cost'] ?? 0.0;
      totalKwh += kwh;
      totalCost += cost;

      csv += "${DateFormat('dd/MM/yyyy').format(dt)};" 
             "${DateFormat('HH:mm').format(dt)};"
             "${kwh.toStringAsFixed(2).replaceFirst('.', ',')};"
             "${cost.toStringAsFixed(2).replaceFirst('.', ',')}\n";
    }

    // Aggiunta riga Totale in fondo
    csv += "\nTOTALE;;${totalKwh.toStringAsFixed(2).replaceFirst('.', ',')};${totalCost.toStringAsFixed(2).replaceFirst('.', ',')}\n";

    Clipboard.setData(ClipboardData(text: csv));
    _showSnack("CSV con totali copiato!");
  }

  // --- UI WIDGETS ---

  @override
  Widget build(BuildContext context) {
    Color statusCol = isCharging ? Colors.greenAccent : (isWaiting ? Colors.orangeAccent : Colors.cyanAccent);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _header(),
              _compactMainRow(),
              const SizedBox(height: 5),
              _statusBadge(statusCol, isCharging ? "CARICA IN CORSO" : (isWaiting ? "IN ATTESA" : "SISTEMA OFF")),
              const SizedBox(height: 12),
              _horizontalBatteryWide(currentSoc), 
              _energyEstimates(),
              const SizedBox(height: 15),
              _paramSliders(), 
              const Spacer(),
              _controls(),
              const SizedBox(height: 12),
              _actionButtons(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(icon: const Icon(Icons.settings_outlined, size: 24), onPressed: _showSettings),
      const Text("SMART CHARGE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.cyanAccent, fontSize: 20)),
      IconButton(icon: const Icon(Icons.history, color: Colors.cyanAccent, size: 24), onPressed: _showHistory),
    ]),
  );

  Widget _compactMainRow() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      _dateCol("INIZIO", fullStartDate, isWaiting ? Colors.orangeAccent : Colors.white38),
      Column(children: [
        Text(DateFormat('HH:mm').format(now), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w100, fontFamily: 'monospace', height: 1)),
        Text(DateFormat('EEE d MMM').format(now).toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.white38)),
      ]),
      _dateCol("FINE", fullEndDate, Colors.cyanAccent),
    ],
  );

  Widget _dateCol(String t, DateTime? d, Color c) => SizedBox(width: 70, child: Column(children: [
    Text(t, style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold)),
    Text(d != null ? DateFormat('HH:mm').format(d) : "--:--", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c)),
  ]));

  Widget _horizontalBatteryWide(double soc) {
    Color batteryColor = soc > 85 ? Colors.greenAccent : (soc > 40 ? Colors.yellowAccent : (soc > 20 ? Colors.orangeAccent : Colors.redAccent));
    return AnimatedBuilder(
      animation: _pulseController!,
      builder: (context, child) {
        double glow = (isCharging || isWaiting) ? _pulseController!.value * 12 : 1;
        return Column(children: [
          Row(children: [
            Expanded(child: Container(
              height: 60, padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: batteryColor.withOpacity(0.5), width: 1.5), boxShadow: [BoxShadow(color: batteryColor.withOpacity(0.1), blurRadius: glow)]),
              child: Row(children: List.generate(10, (i) {
                bool fill = soc >= (i + 1) * 10 - 5; 
                return Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 1.5), decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), gradient: fill ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [batteryColor, batteryColor.withOpacity(0.5)]) : null, color: fill ? null : Colors.white.withAlpha(10))));
              })),
            )),
            Container(width: 5, height: 18, decoration: BoxDecoration(color: batteryColor.withOpacity(0.4), borderRadius: const BorderRadius.only(topRight: Radius.circular(3), bottomRight: Radius.circular(3)))),
          ]),
          const SizedBox(height: 4),
          Text("${soc.toStringAsFixed(2)}%", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: batteryColor)),
        ]);
      }
    );
  }

  Widget _energyEstimates() {
    double kwh = ((socTarget - currentSoc) / 100) * batteryCap;
    if (kwh < 0) kwh = 0;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _infoLabel("DA CARICARE", "${kwh.toStringAsFixed(1)} kWh", Colors.orangeAccent),
      _infoLabel("COSTO STIMATO", "€ ${(kwh * costPerKwh).toStringAsFixed(2)}", Colors.greenAccent),
    ]));
  }

  Widget _infoLabel(String l, String v, Color c) => Column(children: [Text(l, style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold)), Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c))]);

  Widget _statusBadge(Color col, String text) => AnimatedBuilder(
    animation: _pulseController!,
    builder: (context, child) {
      double opacity = isCharging ? (0.3 + (_pulseController!.value * 0.7)) : 1.0;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
        decoration: BoxDecoration(
          color: col.withOpacity(isCharging ? 0.1 * opacity : 0.1), 
          borderRadius: BorderRadius.circular(15), 
          border: Border.all(color: col.withOpacity(isCharging ? 0.5 * opacity : 0.3))
        ), 
        child: Opacity(
          opacity: opacity,
          child: Text(text, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2))
        )
      );
    }
  );

  Widget _paramSliders() => Column(children: [
    _sliderRow("POTENZA WALLBOX", "${wallboxPwr.toStringAsFixed(1)} kW", wallboxPwr, 1, 22, Colors.orangeAccent, (v) { _updateParams(pwr: v); HapticFeedback.selectionClick(); }),
    const SizedBox(height: 8),
    _sliderRow("CAPACITÀ BATTERIA", "${batteryCap.toInt()} kWh", batteryCap, 30, 90, Colors.cyanAccent, (v) { _updateParams(cap: v); HapticFeedback.selectionClick(); }),
  ]);

  Widget _sliderRow(String lab, String val, double v, double min, double max, Color c, Function(double) onC) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(lab, style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)), Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))]),
    SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)), child: Slider(value: v, min: min, max: max, activeColor: c, onChanged: onC)),
  ]);

  Widget _controls() => Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
    _touchControl("SoC INIZIALE", "${socStart.toInt()}%", () => _verticalSlider(true)),
    _touchControl("SoC FINALE", "${socTarget.toInt()}%", () => _verticalSlider(false)),
    _touchControl("TARGET ORA", targetTimeInput.format(context), _pickTime),
  ]);

  Widget _touchControl(String l, String v, VoidCallback t) => InkWell(onTap: t, child: Column(children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)), Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.cyanAccent))]));

  Widget _actionButtons() => Column(children: [
    SizedBox(width: double.infinity, height: 45, child: ElevatedButton(onPressed: _toggleSystem, style: ElevatedButton.styleFrom(backgroundColor: isActive ? Colors.redAccent : Colors.cyanAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(isActive ? "STOP SISTEMA" : "ATTIVA SMART CHARGE", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)))),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: OutlinedButton(onPressed: () => _save(false), child: const Text("SALVA PARZIALE", style: TextStyle(fontSize: 11)))),
      const SizedBox(width: 8),
      Expanded(child: ElevatedButton(onPressed: () => _save(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black), child: const Text("SALVA TOTALE", style: TextStyle(fontSize: 11)))),
    ]),
  ]);

  void _showSettings() {
    final TextEditingController idCtrl = TextEditingController(text: userId);
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: const Color(0xFF101A26),
      title: const Text("CONFIGURAZIONE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: idCtrl, decoration: InputDecoration(labelText: "USER CODE", labelStyle: const TextStyle(fontSize: 12), suffixIcon: IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () { Clipboard.setData(ClipboardData(text: idCtrl.text)); _showSnack("Codice copiato"); }))),
          const SizedBox(height: 10),
          _settingField("COSTO €/kWh", _costCtrl),
          _settingField("POTENZA WALLBOX (kW)", _pwrCtrl),
          _settingField("CAPACITÀ BATTERIA (kWh)", _capCtrl),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: () { 
              HapticFeedback.heavyImpact(); 
              _updateParams(
                cost: double.tryParse(_costCtrl.text),
                pwr: double.tryParse(_pwrCtrl.text),
                cap: double.tryParse(_capCtrl.text),
              );
              _syncUser(idCtrl.text); 
              Navigator.pop(c); 
              _showSnack("Impostazioni salvate");
            }, 
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)), 
            child: const Text("SALVA E SINCRONIZZA")
          )
        ]),
      ),
    ));
  }

  Widget _settingField(String l, TextEditingController c) => TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l, labelStyle: const TextStyle(fontSize: 12)));

  void _verticalSlider(bool start) {
    double val = start ? socStart : socTarget;
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, st) => AlertDialog(
      backgroundColor: const Color(0xFF101A26),
      title: Text(start ? "SoC Iniziale" : "SoC Finale"),
      content: SizedBox(height: 250, child: Column(children: [
        Text("${val.toInt()}%", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        Expanded(child: RotatedBox(quarterTurns: 3, child: Slider(value: val, min: 0, max: 100, activeColor: Colors.cyanAccent, onChanged: (v) { 
          HapticFeedback.selectionClick();
          st(()=>val=v); 
          setState((){ if(start){socStart=v;currentSoc=v;}else{socTarget=v;} _recalcSchedule(); }); 
        }))),
      ])),
    )));
  }

  void _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: targetTimeInput);
    if(t != null) {
      HapticFeedback.lightImpact();
      setState(() { targetTimeInput = t; });
      _recalcSchedule();
      _showSnack("Orario aggiornato: ${t.format(context)}");
    }
  }

  // --- CRONOLOGIA CON FILTRI E EXPORT ---

  void _showHistory() {
    String? currentMonthFilter;

    showModalBottomSheet(
      context: context, 
      backgroundColor: const Color(0xFF101A26), 
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (context, setModalState) {
          Set<String> availableMonths = history.map((e) => 
            DateFormat('MM/yyyy').format(DateTime.parse(e['date']))).toSet();

          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("CRONOLOGIA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.cyanAccent)),
                    IconButton(
                      icon: const Icon(Icons.file_download, color: Colors.greenAccent),
                      onPressed: () => _exportHistoryToCSV(currentMonthFilter),
                    )
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(children: [
                  ChoiceChip(
                    label: const Text("Tutti"),
                    selected: currentMonthFilter == null,
                    onSelected: (s) => setModalState(() => currentMonthFilter = null),
                  ),
                  ...availableMonths.map((m) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(m),
                      selected: currentMonthFilter == m,
                      onSelected: (s) => setModalState(() => currentMonthFilter = s ? m : null),
                    ),
                  )),
                ]),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: history.isEmpty 
                ? const Center(child: Text("Nessuna ricarica salvata", style: TextStyle(color: Colors.white24)))
                : ListView.builder(
                    itemCount: history.length, 
                    itemBuilder: (c, i) {
                      DateTime logDate = DateTime.parse(history[i]['date']);
                      String monthYear = DateFormat('MM/yyyy').format(logDate);
                      if (currentMonthFilter != null && monthYear != currentMonthFilter) return const SizedBox.shrink();

                      return Dismissible(
                        key: Key(history[i]['date'] + i.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight, 
                          padding: const EdgeInsets.only(right: 20), 
                          color: Colors.redAccent, 
                          child: const Icon(Icons.delete_forever, color: Colors.white)
                        ),
                        onDismissed: (dir) => _deleteHistoryItem(i),
                        child: ListTile(
                          title: Text(DateFormat('dd/MM HH:mm').format(logDate)),
                          subtitle: Text("${history[i]['kwh'].toStringAsFixed(2)} kWh"),
                          trailing: Text("€ ${history[i]['cost'].toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        ),
                      );
                    }
                  ),
              ),
            ]),
          );
        }
      )
    );
  }
}
