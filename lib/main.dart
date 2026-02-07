<<<<<<< HEAD
=======
import 'package:http/http.dart' as http;
>>>>>>> c44e1c6 (Sblocco definitivo: rimosso APK e attivato ponte API)
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

const Map<String, Map<String, String>> localizedValues = {
  'it': {
    'start': 'INIZIO', 
    'end': 'FINE', 
    'target': 'TARGET', 
    'status_off': 'SISTEMA OFF',
    'status_wait': 'IN ATTESA', 
    'status_charging': 'IN CARICA', 
    'settings': 'IMPOSTAZIONI',
    'priority': 'Priorità Batteria', 
    'priorita_sottotitolo': 'Completa la carica anche se l\'orario è scaduto',
    'save': 'SALVA', 
    'history': 'CRONOLOGIA',
    'summary': 'RIEPILOGO',
    'energy': 'Energia',
    'cost': 'Costo',
    'discard': 'SCARTA',
    'save_partial': 'SALVA PARZIALE',
    'save_total': 'SALVA TOTALE',
    'da_caricare': 'DA CARICARE',
    'costo_stimato': 'COSTO STIMATO',
    'potenza_wallbox': 'POTENZA WALLBOX',
    'capacita_batteria': 'CAPACITÀ BATTERIA',
    'btn_stop': 'STOP SISTEMA',
    'btn_attiva': 'ATTIVA SMART CHARGE',
    'lingua': 'Lingua',
    'costo_kwh': 'COSTO €/kWh',
    'potenza_kw': 'POTENZA kW',
    'capacita_kwh': 'CAPACITÀ kWh',
    'analisi_consumi': 'ANALISI CONSUMI',
    'inserimento_manuale': 'INSERIMENTO MANUALE',
    'conferma_titolo': 'CONFERMA',
    'elimina_messaggio': 'Vuoi davvero eliminare questa sessione?',
    'elimina_bottone': 'ELIMINA',
    'annulla': 'ANNULLA',
    'domanda_salva': 'Vuoi salvare questa ricarica nel log?',
    'select_brand': 'SELEZIONA MARCA',
  },
  'en': {
    'start': 'START', 
    'end': 'END', 
    'target': 'TARGET', 
    'status_off': 'SYSTEM OFF',
    'status_wait': 'WAITING', 
    'status_charging': 'CHARGING', 
    'settings': 'SETTINGS',
    'priority': 'Battery Priority', 
    'priorita_sottotitolo': 'Complete charge even if time expired',
    'save': 'SAVE', 
    'history': 'HISTORY',
    'summary': 'SUMMARY',
    'energy': 'Energy',
    'cost': 'Cost',
    'discard': 'DISCARD',
    'save_partial': 'PARTIAL SAVE',
    'save_total': 'TOTAL SAVE',
    'da_caricare': 'TO CHARGE',
    'costo_stimato': 'EST. COST',
    'potenza_wallbox': 'WALLBOX POWER',
    'capacita_batteria': 'BATTERY CAPACITY',
    'btn_stop': 'STOP SYSTEM',
    'btn_attiva': 'ACTIVATE SMART CHARGE',
    'lingua': 'Language',
    'costo_kwh': 'COST €/kWh',
    'potenza_kw': 'POWER kW',
    'capacita_kwh': 'CAPACITY kWh',
    'analisi_consumi': 'CONSUMPTION ANALYSIS',
    'inserimento_manuale': 'MANUAL ENTRY',
    'conferma_titolo': 'CONFIRM',
    'elimina_messaggio': 'Do you really want to delete this session?',
    'elimina_bottone': 'DELETE',
    'annulla': 'CANCEL',
    'domanda_salva': 'Do you want to save this charge to the log?',
    'select_brand': 'SELECT BRAND',
  },
  'fr': {
    'start': 'DÉBUT', 
    'end': 'FIN', 
    'target': 'CIBLE', 
    'status_off': 'SYSTÈME OFF',
    'status_wait': 'EN ATTENTE', 
    'status_charging': 'EN CHARGE', 
    'settings': 'PARAMÈTRES',
    'priority': 'Priorité Batterie', 
    'priorita_sottotitolo': 'Terminer la charge même se le temps est écoulé',
    'save': 'ENREGISTRER', 
    'history': 'HISTORIQUE',
    'summary': 'RÉSUMÉ',
    'energy': 'Énergie',
    'cost': 'Coût',
    'discard': 'ABANDONNER',
    'save_partial': 'SAUVEGARDE PARTIELLE',
    'save_total': 'SAUVEGARDE TOTALE',
    'da_caricare': 'À CHARGER',
    'costo_stimato': 'COÛT ESTIMÉ',
    'potenza_wallbox': 'PUISSANCE WALLBOX',
    'capacita_batteria': 'CAPACITÉ BATTERIE',
    'btn_stop': 'ARRÊTER LE SYSTÈME',
    'btn_attiva': 'ACTIVER SMART CHARGE',
    'lingua': 'Langue',
    'costo_kwh': 'COÛT €/kWh',
    'potenza_kw': 'PUISSANCE kW',
    'capacita_kwh': 'CAPACITÉ kWh',
    'analisi_consumi': 'ANALYSE DE CONSOMMATION',
    'inserimento_manuale': 'SAISIE MANUELLE',
    'conferma_titolo': 'CONFIRMATION',
    'elimina_messaggio': 'Voulez-vous vraiment supprimer cette session ?',
    'elimina_bottone': 'SUPPRIMER',
    'annulla': 'ANNULER',
    'domanda_salva': 'Voulez-vous enregistrer cette charge dans le journal?',
    'select_brand': 'SÉLECTIONNER MARQUE',
  },
  'de': {
    'start': 'START', 
    'end': 'ENDE', 
    'target': 'ZIEL', 
    'status_off': 'SYSTEM AUS',
    'status_wait': 'WARTEN', 
    'status_charging': 'LÄDT', 
    'settings': 'EINSTELLUNGEN',
    'priority': 'Batteriepriorität', 
    'priorita_sottotitolo': 'Ladevorgang beenden, auch wenn Zeit abgelaufen ist',
    'save': 'SPEICHERN', 
    'history': 'VERLAUF',
    'summary': 'ZUSAMMENFASSUNG',
    'energy': 'Energie',
    'cost': 'Kosten',
    'discard': 'VERWERFEN',
    'save_partial': 'TEILSAVE',
    'save_total': 'VOLLSAVE',
    'da_caricare': 'ZU LADEN',
    'costo_stimato': 'KOSTENSCHÄTZUNG',
    'potenza_wallbox': 'WALLBOX LEISTUNG',
    'capacita_batteria': 'BATTERIEKAPAZITÄT',
    'btn_stop': 'SYSTEM STOPPEN',
    'btn_attiva': 'SMART CHARGE AKTIVIEREN',
    'lingua': 'Sprache',
    'costo_kwh': 'KOSTEN €/kWh',
    'potenza_kw': 'LEISTUNG kW',
    'capacita_kwh': 'KAPAZITÄT kWh',
    'analisi_consumi': 'VERBRAUCHSANALYSE',
    'inserimento_manuale': 'MANUELLE EINGABE',
    'conferma_titolo': 'BESTÄTIGEN',
    'elimina_messaggio': 'Möchten Sie diese Sitzung wirklich löschen?',
    'elimina_bottone': 'LÖSCHEN',
    'annulla': 'ABBRECHEN',
    'domanda_salva': 'Möchten Sie questa ricarica im Log speichern?',
    'select_brand': 'MARKE WÄHLEN',
  },
};


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT', null);
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAjKI3YdGvyjTcjX9NH5EZBxS5eGN1saf4",
        authDomain: "smartcharge-2406b.firebaseapp.com",
        projectId: "smartcharge-c5b34",
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
      // ... lascia tutto come era ...
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
  String currentLang = 'it'; // Default
  String userId = "";
  String selectedVehicle = "Manuale / Altro";
  String t(String key) => localizedValues[currentLang]?[key] ?? key;

  List<Map<String, dynamic>> remoteEvDatabase = []; 
  
  double batteryCap = 44.0; 
  double wallboxPwr = 3.7; 
  double costPerKwh = 0.25;
  double socStart = 20.0;
  double socTarget = 80.0;
  double currentSoc = 20.0; // Verrà aggiornato in tempo reale da Firestore
  double energySession = 0.0;
  TimeOfDay targetTimeInput = const TimeOfDay(hour: 7, minute: 0);
  
  DateTime? lockedStartDate;
  DateTime now = DateTime.now();
  DateTime? fullStartDate;
  DateTime? fullEndDate;

  bool isActive = false;
  bool isWaiting = false;
  bool isCharging = false;
  bool priorityBattery = true; 
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
<<<<<<< HEAD
<<<<<<< HEAD
=======
=======
    _loadData();
    _fetchRemoteModels();
    // Il timer del SoC è stato rimosso perché ora usiamo lo StreamBuilder
    _clockTimer = Timer.periodic(const Duration(milliseconds: 500), (t) => _updateClock());
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _bgController.dispose();
    super.dispose();
  }

  // Metodo per scaricare i modelli (Firestore)
  void _fetchRemoteModels() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('ev_models').orderBy('brand').get();
      if (snapshot.docs.isNotEmpty) {
        setState(() {
          remoteEvDatabase = snapshot.docs.map((doc) => doc.data()).toList();
        });
      }
    } catch (e) {
      debugPrint("Errore modelli: $e");
    }
  }

  // --- IL METODO BUILD CON LO STREAM DI DATI DAL MAC ---
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('veicoli')
          .doc('VR7CPZYA5ST281107') // Il tuo VIN
          .snapshots(),
      builder: (context, snapshot) {
        // Se arrivano dati dal Mac, aggiorniamo il SoC istantaneamente
        if (snapshot.hasData && snapshot.data!.exists) {
          var cloudData = snapshot.data!.data() as Map<String, dynamic>;
          currentSoc = (cloudData['soc'] as num).toDouble();
        }

        Color statusCol = isCharging ? Colors.greenAccent : (isWaiting ? Colors.orangeAccent : Colors.cyanAccent);

        return Scaffold(
          body: Stack(
            children: [
              _liquidBackground(),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _header(),
                      _compactMainRow(),
                      _statusBadge(statusCol, isCharging ? t('status_charging') : (isWaiting ? t('status_wait') : t('status_off'))),
                      const SizedBox(height: 25),
                      _premiumBatterySection(currentSoc), // <--- Qui vedrai il 64%!
                      _energyEstimates(),
                      _paramSliders(),
                      const Spacer(),
                      _controls(),
                      const SizedBox(height: 15),
                      _actionButtons(),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  

  @override
  void initState() {
    super.initState();
>>>>>>> 45acec0 (Integrazione Firebase per SoC in tempo reale)
    super.initState();
    _loadData();
    // Recupera il SoC appena apri l'app
    // _fetchRealSoc();
    // Poi lo aggiorna ogni 5 minuti (300 secondi)
<<<<<<< HEAD
    Timer.periodic(const Duration(seconds: 300), (timer) {
      _fetchRealSoc();
    });
>>>>>>> c44e1c6 (Sblocco definitivo: rimosso APK e attivato ponte API)
=======
   
>>>>>>> 45acec0 (Integrazione Firebase per SoC in tempo reale)
    _loadData();
    _fetchRemoteModels(); 
    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (t) => _updateClock());
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }
<<<<<<< HEAD

=======
  
  
  
>>>>>>> c44e1c6 (Sblocco definitivo: rimosso APK e attivato ponte API)
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
      // 1. STOP PER TARGET RAGGIUNTO (Priorità 1)
      if (currentSoc >= socTarget) {
        _toggleSystem();
        _vibrateFinish(); // Aggiungi questa funzione sotto
        _save(true);
        return;
      }

      // 2. STOP PER FINE TEMPO (Solo se l'interruttore Priorità Batteria è OFF)
      if (now.isAfter(fullEndDate!) || now.isAtSameMomentAs(fullEndDate!)) {
        if (!priorityBattery) {
          _toggleSystem();
          _vibrateFinish();
          _save(false);
          return;
        }
      }

      // 3. LOGICA DI CARICA
      if (now.isAfter(fullStartDate!)) {
        if (!isCharging) setState(() { isWaiting = false; isCharging = true; });
        _processCharging();
      } else {
        if (!isWaiting) setState(() { isWaiting = true; isCharging = false; });
        _lastTick = now;
      }
    }
  }
  void _vibrateFinish() async {
    for (int i = 0; i < 3; i++) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }
  void _processCharging() async {
    // Se siamo già al target, non fare nulla
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
        double nextSoc = currentSoc + socAdded;
        // Se mancano meno di 0.02% lo consideriamo pieno (evita 79.99%)
        if (nextSoc > (socTarget - 0.02)) {
          currentSoc = socTarget;
        } else {
          currentSoc = nextSoc;
        }
      });
      prefs.setDouble('currentSoc', currentSoc);
      prefs.setDouble('energySession', energySession);
      prefs.setInt('last_timestamp', nowCharge.millisecondsSinceEpoch);
    }
    _lastTick = nowCharge;
  }

  void _recalcSchedule() {
    // Se sta caricando o è attiva, non spostiamo più l'orario di inizio
    // altrimenti il SoC che sale sposta i tempi e l'app va in pausa.
    if (isCharging && isActive) {
      DateTime target = DateTime(now.year, now.month, now.day, targetTimeInput.hour, targetTimeInput.minute);
      if (target.isBefore(now)) target = target.add(const Duration(days: 1));
      setState(() { 
        fullEndDate = target; 
      });
      return; 
    }

    // Calcolo normale quando il sistema è OFF o in ATTESA
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
  currentLang = prefs.getString('lang') ?? 'it';
  setState(() {
    currentLang = prefs.getString('lingua_scelta') ?? 'it';
    batteryCap = (prefs.getDouble('cap') ?? 44.0);
    wallboxPwr = (prefs.getDouble('pwr') ?? 3.7).clamp(1.5, 11.0);
    costPerKwh = prefs.getDouble('cost') ?? 0.25;
    socStart = prefs.getDouble('soc_s') ?? 20.0;
    socTarget = prefs.getDouble('soc_t') ?? 80.0;
    targetTimeInput = TimeOfDay(hour: prefs.getInt('targetHour') ?? 7, minute: prefs.getInt('targetMinute') ?? 0);
    isActive = prefs.getBool('isActive') ?? false;
    currentSoc = prefs.getDouble('currentSoc') ?? socStart;
    energySession = prefs.getDouble('energySession') ?? 0.0;
    // Dentro _loadData
    priorityBattery = prefs.getBool('priorityBattery') ?? true;
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
    // 1. Calcoliamo i dati della ricarica prima di resettare
    double kwh = tot ? (((socTarget - socStart) / 100) * batteryCap) : energySession;
    if (kwh < 0) kwh = 0;
    double cost = kwh * costPerKwh;
    DateTime sessionDate = DateTime.now();

    // 2. Mostriamo il pop-up di riepilogo
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A141D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white10),
          ),
          title: Row(
            children: [
              const Icon(Icons.bolt, color: Colors.cyanAccent),
              const SizedBox(width: 10),
              Text(t('summary'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryRow(t('energy'), "${kwh.toStringAsFixed(2)} kWh"),
              _buildSummaryRow(t('cost'), "€ ${cost.toStringAsFixed(2)}"),
              const SizedBox(height: 20),
              Text(t('domanda_salva'), 
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resetAfterSession(tot); // Resetta l'interfaccia senza salvare
              },
              child: Text(t('annulla'), style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
              onPressed: () {
                Navigator.pop(context);
                _addLogEntry(sessionDate, kwh); // Chiama la tua funzione esistente per salvare
                _resetAfterSession(tot);
              },
              child: Text("SALVA", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Funzione di supporto per resettare l'interfaccia
  void _resetAfterSession(bool tot) async {
    setState(() {
      if (tot) currentSoc = socTarget;
      energySession = 0;
      isActive = false;
      isCharging = false;
      isWaiting = false;
      _lastTick = null;
      lockedStartDate = null;
    });
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('currentSoc', currentSoc);
    prefs.setDouble('energySession', 0.0);
    prefs.setBool('isActive', false);
    prefs.remove('last_timestamp');
    prefs.remove('lockedStartDate');
  }

  // Widget per le righe del pop-up
  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
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

  Future<bool> _showDeleteConfirmation(int index) async {
  bool confirm = false;
  
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) { // Usiamo un nome diverso per il context del dialogo
      return AlertDialog(
        backgroundColor: const Color(0xFF0A141D),
        title: Text("CONFERMA", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(t('elimina_messaggio')),
        actions: [
          TextButton(
            onPressed: () {
              confirm = false; 
              Navigator.of(dialogContext).pop();
            },
            child: Text(t('annulla'), style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              confirm = true; 
              Navigator.of(dialogContext).pop();

              setState(() {
                history.removeAt(index);
              });
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('logs', jsonEncode(history));
              _forceFirebaseSync();
            },
            child: Text(t('elimina_bottone'), style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
  
  return confirm; 
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

  Widget _glassCircle(double s, Color c) => Container(
    width: s, 
    height: s, 
    decoration: BoxDecoration(
      shape: BoxShape.circle, 
      gradient: RadialGradient(
        colors: [c, c.withOpacity(0.1), Colors.transparent], 
        stops: const [0.0, 0.45, 1.0]
      )
    )
  );

  Widget _header() => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white30), onPressed: _showSettings),
    const Text("SMART CHARGE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.cyanAccent, fontSize: 18)),
    IconButton(icon: const Icon(Icons.history, color: Colors.cyanAccent), onPressed: _showHistory),
  ]));

  Widget _compactMainRow() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    // MODIFICA QUI: Se attivo usa l'ora bloccata, se spento usa quella calcolata
    _dateCol(t('start'), isActive ? lockedStartDate : fullStartDate, isWaiting ? Colors.orangeAccent : Colors.white24),
    
    Column(children: [
      Text(DateFormat('HH:mm').format(now), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w100, fontFamily: 'monospace')),
      Text(DateFormat('EEE d MMM').format(now).toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white38)),
    ]),
    _dateCol(t('end'), fullEndDate, Colors.cyanAccent),
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
<<<<<<< HEAD
            Text(soc.toStringAsFixed(2).replaceFirst('.', ','), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w200, color: Colors.white, letterSpacing: -1)),
=======
            // Qui visualizzerà il SoC REALE arrivato dal server
            Text(soc.toStringAsFixed(1).replaceFirst('.', ','), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w200, color: Colors.white, letterSpacing: -1)),
>>>>>>> c44e1c6 (Sblocco definitivo: rimosso APK e attivato ponte API)
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
      _infoLabel(t('da_caricare'), "${kwh.toStringAsFixed(1)} kWh", Colors.orangeAccent),
      _infoLabel(t('costo_stimato'), "€ ${(kwh * costPerKwh).toStringAsFixed(2)}", Colors.greenAccent),
    ]));
  }

  Widget _infoLabel(String l, String v, Color c) => Column(children: [Text(l, style: const TextStyle(fontSize: 9, color: Colors.white38)), Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c))]);
  Widget _statusBadge(Color col, String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: col.withOpacity(0.2))), child: Text(text, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.bold)));

  Widget _paramSliders() => Column(children: [
    _sliderRow(t('potenza_wallbox'), "${wallboxPwr.toStringAsFixed(1)} kW", wallboxPwr, 1.5, 11.0, 0.1, Colors.orangeAccent, (v) => _updateParams(pwr: v)),
    const SizedBox(height: 10),
    _sliderRowWithAction(t('capacita_batteria'), "${batteryCap.toStringAsFixed(1)} kWh", batteryCap, 10, 150, 0.1, Colors.cyanAccent, (v) => _updateParams(cap: v), _showVehicleSelector),
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
    SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _toggleSystem, style: ElevatedButton.styleFrom(backgroundColor: isActive ? Colors.redAccent : Colors.cyanAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(isActive ? t('btn_stop') : t('btn_attiva'), style: const TextStyle(fontWeight: FontWeight.w900)))),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: OutlinedButton(onPressed: () => _save(false), child: Text(t('save_partial')))),
      const SizedBox(width: 10),
      Expanded(child: ElevatedButton(onPressed: () => _save(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black), child: Text(t('save_total')))),
    ]),
  ]);

  void _showSettings() {
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: const Color(0xFF0A141D),
      title: Text(t('settings')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Dentro la Column del Dialog delle impostazioni
SwitchListTile(
  title: Text(t('priority'), style: TextStyle(fontSize: 14)),
  subtitle: Text(t('priorita_sottotitolo'), style: TextStyle(fontSize: 11)),
  value: priorityBattery,
  activeColor: Colors.cyanAccent,
  onChanged: (bool value) async {
    setState(() { priorityBattery = value; });
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('priorityBattery', value);
  },
),
        // Dentro la Column del Dialog impostazioni
ListTile(
  leading: const Icon(Icons.language, color: Colors.cyanAccent),
  title: const Text("Lingua / Language"),
  trailing: DropdownButton<String>(
    value: currentLang,
    items: const [
      DropdownMenuItem(value: 'it', child: Text("🇮🇹 IT")),
      DropdownMenuItem(value: 'en', child: Text("🇺🇸 EN")),
      DropdownMenuItem(value: 'fr', child: Text("🇫🇷 FR")),
      DropdownMenuItem(value: 'de', child: Text("🇩🇪 DE")),
    ],
    onChanged: (String? nuovoValore) async {
  if (nuovoValore != null) {
    // 1. Aggiorna l'interfaccia subito
    setState(() {
      currentLang = nuovoValore;
    });

    // 2. SALVA la scelta permanentemente
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lingua_scelta', nuovoValore);

    // Chiudi e riapri il menu per aggiornare i testi
    Navigator.pop(context);
    _showSettings();
  }
},
  ),
),
        _settingField(t('costo_kwh'), _costCtrl),
        _settingField(t('potenza_kw'), _pwrCtrl),
        _settingField(t('capacita_kwh'), _capCtrl),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _uidCtrl, decoration: const InputDecoration(labelText: "USER ID"), style: const TextStyle(fontSize: 10, fontFamily: 'monospace'))),
          IconButton(icon: const Icon(Icons.copy, size: 18, color: Colors.cyanAccent), onPressed: () { Clipboard.setData(ClipboardData(text: _uidCtrl.text)); _showSnack("ID copiato!"); }),
        ]),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { _updateParams(cost: double.tryParse(_costCtrl.text.replaceAll(',', '.')), pwr: double.tryParse(_pwrCtrl.text.replaceAll(',', '.')), cap: double.tryParse(_capCtrl.text.replaceAll(',', '.'))); _syncUser(_uidCtrl.text); Navigator.pop(c); }, child: Text(t('save')))),
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
        Padding(padding: const EdgeInsets.all(20), child: Row(children: [if (selectedBrand != null) IconButton(icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent), onPressed: () => setModalState(() => selectedBrand = null)), Text(selectedBrand ?? t('select_brand'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent))])),
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
              }, child: Text("CONFERMA")))
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
      title: Text(t('inserimento_manuale'), style: TextStyle(color: Colors.cyanAccent, fontSize: 16)),
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
              Text(t('analisi_consumi'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.cyanAccent)),
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
            Expanded(
  child: ListView.builder(
    itemCount: history.length, 
    itemBuilder: (c, i) {
      final item = history[i];
      return Dismissible(
        key: Key(item['date'] + i.toString()), 
        direction: DismissDirection.endToStart, 
        background: Container(
          alignment: Alignment.centerRight, 
          padding: const EdgeInsets.only(right: 20), 
          color: Colors.redAccent.withOpacity(0.2), 
          child: const Icon(Icons.delete_outline, color: Colors.redAccent)
        ),
        // AGGIUNGI QUESTO BLOCCO: blocca l'animazione finché non confermi nel pop-up
        confirmDismiss: (direction) async {
          return await _showDeleteConfirmation(i); 
        },
        // Riduciamo onDismissed perché il lavoro grosso lo fa confirmDismiss
        onDismissed: (direction) {
          setModal(() {}); 
        },
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
