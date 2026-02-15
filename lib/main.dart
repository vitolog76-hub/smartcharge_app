import 'settings_page.dart';
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
import 'package:fl_chart/fl_chart.dart'; // <--- QUESTA È FONDAMENTALE
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    // Inizializza con i tuoi dati reali che abbiamo trovato prima
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBdZ7j1pMuabOd47xeBzCPq0g9wBi4jg3A",
        authDomain: "smartcharge-c5b34.firebaseapp.com",
        projectId: "smartcharge-c5b34",
        storageBucket: "smartcharge-c5b34.firebasestorage.app",
        messagingSenderId: "25947690562",
        appId: "1:25947690562:web:613953180d63919a677fdb",
      ),
    );

    // LOGIN ANONIMO: Se non c'è un utente, lo crea o lo recupera silenziosemente
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint("✅ Login Anonimo effettuato con successo!");
    } else {
      debugPrint("✅ Utente già loggato: ${FirebaseAuth.instance.currentUser?.uid}");
    }

  } catch (e) {
    debugPrint("❌ Errore inizializzazione: $e");
  }

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
  bool _isSyncing = false;
  int _selectedYear = DateTime.now().year;
  String userName = ""; // Aggiungi questa riga insieme alle altre variabili
  String currentLang = 'it'; // Default
  String userId = "";
  String selectedVehicle = "Manuale / Altro";
  String t(String key) {
  return localizedValues[currentLang]?[key] ?? key;
}
  List<Map<String, dynamic>> remoteEvDatabase = []; 
  
  double batteryCap = 44.0; 
  double wallboxPwr = 3.7; 
  String energyProvider = "Generico"; // Nome del fornitore
  double costPerKwh = 0.25;
  double socStart = 20.0;
  double socTarget = 80.0;
  double currentSoc = 20.0;
  double energySession = 0.0;
  TimeOfDay targetTimeInput = const TimeOfDay(hour: 7, minute: 0);
  String providerName = "Generico";
  bool isMultirate = false; // Se l'utente vuole la mono-oraria
  double monoPrice = 0.20;  // Prezzo base
  List<Map<String, dynamic>> rates = []; // Qui finiranno le fasce create
  
  DateTime? lockedStartDate; // Aggiungi questa qui
  DateTime now = DateTime.now();
  DateTime? fullStartDate;
  DateTime? fullEndDate;

  bool isActive = false;
  bool isWaiting = false;
  bool isCharging = false;
  bool priorityBattery = true; // Di default diamo priorità alla carica completa
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
  // Carica i dati locali e poi sincronizza con Firebase
  initializeDateFormatting('it', null).then((_) {
    _loadData(); 
  });

  // Database auto e modelli
  _syncCarsDatabase().then((_) {
    _fetchRemoteModels(); 
  });

  // Timer per l'orologio e animazione sfondo
  _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (t) => _updateClock());
  _bgController = AnimationController(
    vsync: this, 
    duration: const Duration(seconds: 4)
  )..repeat();
}

  void _fetchRemoteModels() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('ev_models').orderBy('brand').get();
      if (snapshot.docs.isNotEmpty) {
        setState(() { remoteEvDatabase = snapshot.docs.map((doc) => doc.data()).toList(); });
      }
    } catch (e) { debugPrint("Firestore: $e"); }
  }

// Salva i dati della simulazione
Future<void> _saveSimSettings() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('last_soc_start', socStart);
  await prefs.setDouble('last_soc_target', socTarget);
  await prefs.setDouble('last_wallbox_pwr', wallboxPwr);
  await prefs.setBool('last_is_active', isActive);
  await prefs.setString('last_vehicle', selectedVehicle);
}

// Carica i dati all'avvio
Future<void> _loadSimSettings() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    // 1. Identità e UI
    userId = prefs.getString('last_user_id') ?? ""; 
    _uidCtrl.text = userId;

    // 2. Veicolo e Batteria
    selectedVehicle = prefs.getString('last_vehicle') ?? "Manuale / Altro";
    batteryCap = prefs.getDouble('cap') ?? 44.0;
    _capCtrl.text = batteryCap.toStringAsFixed(1);

    // 3. Cronologia
    String? historyJson = prefs.getString('local_history');
    if (historyJson != null) {
      history = List<Map<String, dynamic>>.from(jsonDecode(historyJson));
    }

    // 4. Costi e Fornitore (Aggiunti per coerenza)
    energyProvider = prefs.getString('energyProvider') ?? "Generico";
    monoPrice = prefs.getDouble('monoPrice') ?? 0.20;
    isMultirate = prefs.getBool('isMultirate') ?? false;
    String? ratesJson = prefs.getString('rates');
    if (ratesJson != null) {
      rates = List<Map<String, dynamic>>.from(jsonDecode(ratesJson));
    }

    // 5. Parametri simulazione
    socStart = prefs.getDouble('last_soc_start') ?? 20.0;
    socTarget = prefs.getDouble('last_soc_target') ?? 80.0;
    wallboxPwr = prefs.getDouble('last_wallbox_pwr') ?? 3.7;
    _pwrCtrl.text = wallboxPwr.toStringAsFixed(1);
    currentSoc = socStart; 
  });
}

  
  
  Future<void> _syncCarsDatabase() async {
  try {
    final String response = await rootBundle.loadString('assets/cars.json');
    final List<dynamic> data = json.decode(response);
    final collection = FirebaseFirestore.instance.collection('ev_models');
    
    final existing = await collection.get();
    final existingModels = existing.docs.map((doc) => "${doc['brand']}_${doc['model']}").toSet();

    WriteBatch batch = FirebaseFirestore.instance.batch();
    int addedCount = 0;
    for (var car in data) {
      String key = "${car['brand']}_${car['model']}";
      if (!existingModels.contains(key)) {
        var docRef = collection.doc();
        batch.set(docRef, {
          'brand': car['brand'],
          'model': car['model'],
          'cap': (car['cap'] as num).toDouble(),
        });
        addedCount++;
      }
    }
    if (addedCount > 0) {
      await batch.commit();
      debugPrint("Sincronizzazione completata: aggiunte $addedCount nuove auto.");
    }
  } catch (e) {
    debugPrint("Errore sincro database: $e");
  }
}
  Future<void> _forceFirebaseSync() async {
  // Rimosso history.isEmpty per permettere il salvataggio dei parametri anche senza ricariche effettuate
  if (_isSyncing || userId.isEmpty) return;

  try {
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'history': history,
      'provider': energyProvider,
      'isMultirate': isMultirate,
      'monoPrice': monoPrice,
      'rates': rates,
      // --- AGGIUNGI QUESTI CAMPI FONDAMENTALI ---
      'vehicleName': selectedVehicle,
      'cap': batteryCap,
      'pwr': wallboxPwr,
      'cost': costPerKwh,
      // ------------------------------------------
      'lastUpdate': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint("Errore upload: $e");
  }
}

  void _syncUser(String newId) async {
  if (newId.isEmpty) return;
  setState(() => _isSyncing = true);

  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(newId).get();
    
    if (doc.exists) {
      var data = doc.data()!;
      
      List<Map<String, dynamic>> fetchedHistory = [];
      if (data['history'] != null) {
        fetchedHistory = List<Map<String, dynamic>>.from(data['history']);
        fetchedHistory.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
      }

      setState(() {
        userId = newId;
        history = fetchedHistory; // ASSEGNAZIONE LOG
        selectedVehicle = data['vehicleName'] ?? 'Manuale / Altro';
        batteryCap = (data['cap'] ?? 44.0).toDouble();
        
        // AGGIORNA I BOX DI TESTO
        _uidCtrl.text = newId;
        _capCtrl.text = batteryCap.toStringAsFixed(1);

        energyProvider = data['provider'] ?? 'Generico';
        isMultirate = data['isMultirate'] ?? false;
        monoPrice = (data['monoPrice'] ?? 0.20).toDouble();
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_user_id', newId);
      
      // CHIAVE FONDAMENTALE PER LA CRONOLOGIA
      await prefs.setString('local_history', jsonEncode(history)); 
      
      await prefs.setString('last_vehicle', selectedVehicle);
      await prefs.setDouble('cap', batteryCap);
    }
  } finally {
    setState(() => _isSyncing = false);
  }
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
  Future<void> _processCharging() async {
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

      // --- AGGIUNTO AWAIT PER GARANTIRE LA SCRITTURA SU DISCO ---
      await prefs.setDouble('currentSoc', currentSoc);
      await prefs.setDouble('energySession', energySession);
      await prefs.setInt('last_timestamp', nowCharge.millisecondsSinceEpoch);
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

  Future<void> _loadData() async {
  final prefs = await SharedPreferences.getInstance();
  
  // 1. GESTIONE ID
  String? savedManualId = prefs.getString('last_user_id');
  if (savedManualId != null && savedManualId.isNotEmpty) {
    userId = savedManualId;
  } else {
    userId = FirebaseAuth.instance.currentUser?.uid ?? "";
  }

  if (userId.isEmpty) {
    debugPrint("⚠️ Nessun userId trovato.");
    return;
  }

  // 2. CARICAMENTO LOCALE VELOCE
  setState(() {
    _uidCtrl.text = userId;
    batteryCap = prefs.getDouble('batteryCap') ?? 44.0; 
    wallboxPwr = prefs.getDouble('wallboxPwr') ?? 3.7;
    energyProvider = prefs.getString('provider') ?? 'Generico';
    selectedVehicle = prefs.getString('vehicleName') ?? "Manuale / Altro";
    userName = prefs.getString('userName') ?? ""; 
    costPerKwh = prefs.getDouble('monoPrice') ?? 0.20; 
    
    _capCtrl.text = batteryCap.toStringAsFixed(1);
    _pwrCtrl.text = wallboxPwr.toStringAsFixed(1);
    _costCtrl.text = costPerKwh.toStringAsFixed(2);
    
    final localLogs = prefs.getString('logs');
    if (localLogs != null) {
      history = List<Map<String, dynamic>>.from(jsonDecode(localLogs));
    }
  });

  // 3. SINCRONIZZAZIONE CON FIREBASE
  try {
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    
    if (doc.exists) {
      Map<String, dynamic> cloud = doc.data() as Map<String, dynamic>;

      setState(() {
        batteryCap = (cloud['batteryCap'] ?? batteryCap).toDouble();
        selectedVehicle = cloud['vehicleName'] ?? selectedVehicle;
        wallboxPwr = (cloud['wallboxPwr'] ?? wallboxPwr).toDouble();
        userName = cloud['userName'] ?? userName; 
        energyProvider = cloud['provider'] ?? energyProvider;
        costPerKwh = (cloud['monoPrice'] ?? costPerKwh).toDouble();
        monoPrice = costPerKwh; 

        _capCtrl.text = batteryCap.toStringAsFixed(1);
        _pwrCtrl.text = wallboxPwr.toStringAsFixed(1);
        _costCtrl.text = costPerKwh.toStringAsFixed(2);

        if (cloud['history'] != null) {
          List<dynamic> rawHistory = cloud['history'];
          history = rawHistory.map((e) => Map<String, dynamic>.from(e)).toList();
          history.sort((a, b) => (b['date'] ?? "").compareTo(a['date'] ?? ""));
        }
      });

      await prefs.setString('last_user_id', userId);
      await prefs.setString('logs', jsonEncode(history));
      await prefs.setString('provider', energyProvider);
      await prefs.setString('userName', userName); 
      await prefs.setDouble('batteryCap', batteryCap); 
      await prefs.setDouble('wallboxPwr', wallboxPwr);
      await prefs.setDouble('monoPrice', costPerKwh); 
      await prefs.setString('vehicleName', selectedVehicle); 
      
      debugPrint("✅ Profilo completo recuperato per: $userId");
    }
  } catch (e) {
    debugPrint("❌ Errore Sync Cloud: $e");
  }

  // --- 4. RECUPERO STATO SIMULAZIONE (IL NUOVO BLOCCO) ---
  bool savedIsActive = prefs.getBool('isActive') ?? false;
  if (savedIsActive) {
    setState(() {
      isActive = true;
      // Recuperiamo dove eravamo rimasti
      currentSoc = prefs.getDouble('currentSoc') ?? currentSoc;
      energySession = prefs.getDouble('energySession') ?? 0.0;
      
      String? lockedDateStr = prefs.getString('lockedStartDate');
      if (lockedDateStr != null) {
        lockedStartDate = DateTime.parse(lockedDateStr);
      }
    });

    // Calcoliamo subito il tempo passato mentre l'app era chiusa
    await _processCharging();

    // Verifichiamo se nel frattempo ha finito di caricare
    if (currentSoc >= socTarget) {
      setState(() {
        isActive = false;
        isCharging = false;
        isWaiting = false;
      });
      await prefs.setBool('isActive', false);
    }
  }
  
  // Ricalcola i tempi con i nuovi dati
  _updateParams();
}

  void _updateParams({double? pwr, double? cap, double? cost, String? vName}) async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    if (pwr != null) { 
      wallboxPwr = pwr.clamp(1.5, 11.0); 
      _pwrCtrl.text = wallboxPwr.toStringAsFixed(1); 
    }
    if (cap != null) { 
      batteryCap = cap; 
      _capCtrl.text = batteryCap.toStringAsFixed(1);
    }
    if (cost != null) { 
      costPerKwh = cost; 
      _costCtrl.text = cost.toStringAsFixed(2); 
    }
    if (vName != null) {
      selectedVehicle = vName;
    }
  });

  // --- SALVATAGGIO CON CHIAVI UNIFICATE PER SETTINGS ---
  if (pwr != null) await prefs.setDouble('pwr', wallboxPwr);
  
  // CAMBIATO DA 'cap' A 'batteryCap' PER ALLINEARSI AI SETTINGS
  if (cap != null) await prefs.setDouble('batteryCap', batteryCap); 
  
  if (cost != null) await prefs.setDouble('cost', costPerKwh);
  
  // Salvataggio veicolo (Assicurati che sia 'vehicleName')
  await prefs.setString('vehicleName', selectedVehicle);
  
  // Parametri simulazione
  await prefs.setDouble('last_soc_start', socStart);
  await prefs.setDouble('last_soc_target', socTarget);
  await prefs.setBool('isActive', isActive); 

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
      
      // PULIZIA PERSISTENZA
      prefs.remove('last_timestamp');
      prefs.remove('lockedStartDate');
      prefs.remove('simulation_start_soc'); // Rimuoviamo il punto zero
      prefs.setBool('isActive', false);
    } else { 
      _lastTick = DateTime.now(); 
      prefs.setInt('last_timestamp', _lastTick!.millisecondsSinceEpoch);
      
      // --- NUOVO: SALVIAMO IL SOC DI PARTENZA PER IL RECUPERO ---
      prefs.setDouble('simulation_start_soc', currentSoc);
      prefs.setBool('isActive', true);

      // CONGELA L'ORA DI INIZIO ADESSO (Tua logica originale)
      double kwhNeeded = ((socTarget - currentSoc) / 100) * batteryCap;
      int mins = ((kwhNeeded.clamp(0.0, 500) / wallboxPwr) * 60).round();
      DateTime target = DateTime(now.year, now.month, now.day, targetTimeInput.hour, targetTimeInput.minute);
      if (target.isBefore(now)) target = target.add(const Duration(days: 1));
      
      lockedStartDate = target.subtract(Duration(minutes: mins));
      prefs.setString('lockedStartDate', lockedStartDate!.toIso8601String());
      
      prefs.setDouble('soc_s', socStart);
      prefs.setDouble('currentSoc', currentSoc);
      _saveSimSettings();
    }
  });
  // Nota: prefs.setBool('isActive', isActive) è già gestito sopra per sicurezza
}

  void _showPublicChargeDialog() {
  print("Click ricevuto!");
  final TextEditingController providerCtrl = TextEditingController(text: "Enel X"); // Valore di default
  final TextEditingController kwhCtrl = TextEditingController();
  final TextEditingController costCtrl = TextEditingController();

  showDialog(
    context: context,
    barrierDismissible: false, // L'utente deve scegliere se salvare o annullare
    builder: (context) => AlertDialog(
      title: const Text("NUOVA CARICA PUBBLICA", style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: providerCtrl,
              decoration: const InputDecoration(
                labelText: "Fornitore",
                hintText: "es. Tesla, BeCharge, Ionity",
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: kwhCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "kWh caricati",
                prefixIcon: Icon(Icons.bolt),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: costCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Costo Totale (€)",
                prefixIcon: Icon(Icons.euro),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("ANNULLA", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
          onPressed: () {
            // Conversione dei dati inseriti
            final double kwh = double.tryParse(kwhCtrl.text.replaceAll(',', '.')) ?? 0.0;
            final double cost = double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0.0;
            final String provider = providerCtrl.text.trim().isEmpty ? "Generico" : providerCtrl.text.trim();

            if (kwh > 0) {
              _savePublicLog(kwh, cost, provider);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Ricarica $provider salvata!")),
              );
            }
          },
          child: const Text("SALVA"),
        ),
      ],
    ),
  );
}

// Funzione di supporto per salvare il log pubblico
void _savePublicLog(double kwh, double cost, String provider) async {
  final now = DateTime.now();
  
  // Creiamo l'entry per il log includendo il modello auto selezionato
  final Map<String, dynamic> newLog = {
    'date': now.toIso8601String(),
    'kwh': kwh,
    'cost': cost,
    'provider': provider.isEmpty ? 'Generico' : provider, 
    'type': 'public',     
    'car': selectedVehicle, // <--- Salviamo il modello dell'auto!
    'dettaglio': {'Esterna': kwh.toStringAsFixed(2)}, 
  };

  setState(() {
    history.insert(0, newLog);
  });

  // Aggiorna SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('logs', jsonEncode(history));
  
  // Se hai una funzione di sync con Firebase/Vercel, chiamala qui
  // _forceFirebaseSync(); 
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

  // Aggiungiamo 'double? cost' come parametro opzionale
void _addLogEntry(DateTime date, double kwh) async {
  final prefs = await SharedPreferences.getInstance();
  double finalCost = 0.0;
  
  // 1. Creiamo una mappa per contare i kWh in ogni fascia
  Map<String, double> ripartizioneKwh = {};

  if (isMultirate && rates.isNotEmpty) {
    double kwhPerMinuto = wallboxPwr / 60.0;
    double kwhRimanenti = kwh;
    DateTime tempoCorrente = date;

    while (kwhRimanenti > 0) {
      int minutiOggi = tempoCorrente.hour * 60 + tempoCorrente.minute;
      
      // Recuperiamo label e prezzo della fascia attuale
      String labelAttuale = _getNomeFascia(minutiOggi);
      double prezzoMinuto = _getPrezzoFascia(minutiOggi);
      
      double quotaMinuto = (kwhRimanenti < kwhPerMinuto) ? kwhRimanenti : kwhPerMinuto;
      
      finalCost += quotaMinuto * prezzoMinuto;
      
      // 2. AGGIUNGIAMO I KWH ALLA FASCIA CORRISPONDENTE
      ripartizioneKwh[labelAttuale] = (ripartizioneKwh[labelAttuale] ?? 0) + quotaMinuto;
      
      kwhRimanenti -= quotaMinuto;
      tempoCorrente = tempoCorrente.add(const Duration(minutes: 1));
      
      if (wallboxPwr <= 0) {
         finalCost = kwh * monoPrice;
         break;
      }
    }
  } else {
    finalCost = kwh * monoPrice;
    ripartizioneKwh["Monoraria"] = kwh;
  }

  // 3. SALVIAMO IL LOG CON IL DETTAGLIO KWH
  final log = {
    'date': date.toIso8601String(),
    'kwh': double.parse(kwh.toStringAsFixed(2)),
    'cost': double.parse(finalCost.toStringAsFixed(2)),
    'provider': energyProvider,
    'isMultirate': isMultirate,
    // Qui salviamo la mappa dei kWh formattata a 2 decimali
    'dettaglio': ripartizioneKwh.map((key, value) => MapEntry(key, value.toStringAsFixed(2))),
  };

  setState(() {
    history.insert(0, log);
    history.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
  });

  await prefs.setString('logs', jsonEncode(history));
  _forceFirebaseSync();
}

  double _getPrezzoFascia(int minuti) {
  for (var rate in rates) {
    // Convertiamo gli orari stringa "HH:mm" in minuti totali
    List<String> sP = rate['start'].split(':');
    List<String> eP = rate['end'].split(':');
    int start = int.parse(sP[0]) * 60 + int.parse(sP[1]);
    int end = int.parse(eP[0]) * 60 + int.parse(eP[1]);

    if (start < end) {
      // Fascia standard (es. 08:00 - 20:00)
      if (minuti >= start && minuti < end) return double.tryParse(rate['price'].toString()) ?? monoPrice;
    } else {
      // Fascia che scavalca la mezzanotte (es. 22:00 - 06:00)
      if (minuti >= start || minuti < end) return double.tryParse(rate['price'].toString()) ?? monoPrice;
    }
  }
  return monoPrice; // Default se non trova corrispondenze
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

  Widget _glassCircle(double s, Color c) => Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, c.withOpacity(0.1), Colors.transparent], stops: const [0.0, 0.45, 1.0])));

  @override
Widget build(BuildContext context) {
  Color statusCol = isCharging ? Colors.greenAccent : (isWaiting ? Colors.orangeAccent : Colors.cyanAccent);
  
  return Scaffold(
    body: Stack(
      children: [
        _liquidBackground(),
        SafeArea(
          // AVVOLGI TUTTO IL PADDING IN UNO SCROLL
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _header(),
                  _compactMainRow(),
                  _statusBadge(statusCol, isCharging ? t('status_charging') : (isWaiting ? t('status_wait') : t('status_off'))),
                  const SizedBox(height: 25),
                  _premiumBatterySection(currentSoc), 
                  _energyEstimates(),
                  _paramSliders(), 
                  
                  // SOSTITUISCI IL 'Spacer()' CON UN SIZEDBOX FISSO
                  // Questo evita che la colonna provi a "esplodere" verso il basso
                  const SizedBox(height: 20), 
                  
                  _controls(),
                  const SizedBox(height: 15),
                  _actionButtons(),
                  const SizedBox(height: 20), // Un po' di respiro alla fine
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

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
    // Usa monoPrice se isMultirate è false, altrimenti usa costPerKwh
    double prezzoEffettivo = isMultirate ? costPerKwh : monoPrice;
    
    return Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _infoLabel(t('da_caricare'), "${kwh.toStringAsFixed(1)} kWh", Colors.orangeAccent),
      _infoLabel(t('costo_stimato'), "€ ${(kwh * prezzoEffettivo).toStringAsFixed(2)}", Colors.greenAccent),
    ]));
}

  Widget _infoLabel(String l, String v, Color c) => Column(children: [Text(l, style: const TextStyle(fontSize: 9, color: Colors.white38)), Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c))]);
  Widget _statusBadge(Color col, String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: col.withOpacity(0.2))), child: Text(text, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.bold)));

  Widget _paramSliders() => Column(
    mainAxisSize: MainAxisSize.min, // Occupa solo lo spazio necessario
    children: [
      _sliderRow(t('potenza_wallbox'), "${wallboxPwr.toStringAsFixed(1)} kW", wallboxPwr, 1.5, 11.0, 0.1, Colors.orangeAccent, (v) => _updateParams(pwr: v)),
      const SizedBox(height: 5), // Ridotto da 10 a 5
      _sliderRow(t('capacita_batteria'), "${batteryCap.toStringAsFixed(1)} kWh", batteryCap, 10, 150, 0.1, Colors.cyanAccent, (v) => _updateParams(cap: v)),
      
      const SizedBox(height: 12), // Ridotto da 20 a 12

      GestureDetector(
        onTap: _showVehicleSelector,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6), // Padding più sottile
            decoration: BoxDecoration(
              color: Colors.amberAccent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.15), width: 1),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_rounded, color: Colors.amberAccent, size: 16), // Icona più piccola
                    const SizedBox(width: 6),
                    Text(
                      "CAMBIA AUTO",
                      style: TextStyle(color: Colors.amberAccent.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ],
                ),
                Text(
                  selectedVehicle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16, // Ridotto da 18 a 16
                    fontWeight: FontWeight.w900, 
                    letterSpacing: 2, 
                    fontFamily: 'monospace', 
                    color: Colors.amberAccent,
                    shadows: [Shadow(color: Colors.orangeAccent.withOpacity(0.6), blurRadius: 8)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _sliderRow(String lab, String val, double v, double min, double max, double step, Color c, Function(double) onC) {
  return Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(lab, style: const TextStyle(fontSize: 10, color: Colors.white38)), 
      Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))
    ]),
    Row(children: [
      IconButton(
        icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.white24), 
        onPressed: () {
          onC((v - step).clamp(min, max));
          _saveSimSettings(); // <--- SALVA AL CLICK SUL MENO
        }
      ),
      Expanded(
        child: Slider(
          value: v.clamp(min, max), 
          min: min, 
          max: max, 
          activeColor: c, 
          onChanged: (newValue) {
            onC(newValue);
            _saveSimSettings(); // <--- SALVA QUANDO TRASCINI
          }
        )
      ),
      IconButton(
        icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.white24), 
        onPressed: () {
          onC((v + step).clamp(min, max));
          _saveSimSettings(); // <--- SALVA AL CLICK SUL PIÙ
        }
      ),
    ]),
  ]);
}

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

  Widget _actionButtons() => Column(
    children: [
      // 1. BLOCCO SIMULAZIONE (Sempre in alto)
      SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton.icon(
          icon: Icon(isActive ? Icons.stop_circle : Icons.play_circle_filled, size: 28),
          label: Text(
            isActive ? t('btn_stop').toUpperCase() : "AVVIA SIMULAZIONE CASA",
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? Colors.redAccent : Colors.cyanAccent,
            foregroundColor: Colors.black,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          onPressed: _toggleSystem,
        ),
      ),

      const SizedBox(height: 12),

      // 2. BLOCCO GESTIONE DATI (I tuoi 3 pulsanti originali)
      Row(
        children: [
          _buildMiniButton(
            icon: Icons.ev_station,
            label: "CARICA\nPUBBLICA",
            color: Colors.blueAccent,
            onTap: () => _showPublicChargeDialog(),
          ),
          const SizedBox(width: 8),
          _buildMiniButton(
            icon: Icons.save_outlined,
            label: "SALVA\nPARZIALE",
            color: Colors.white70,
            onTap: () => _save(false),
          ),
          const SizedBox(width: 8),
          _buildMiniButton(
            icon: Icons.check_circle,
            label: "SALVA\nTOTALE",
            color: Colors.greenAccent,
            onTap: () => _save(true),
          ),
        ],
      ),

      const SizedBox(height: 12),

      // 3. NUOVA RIGA: SOLO CARICA MANUALE (Così non hai errori di 'userId')
      Row(
        children: [
          _buildMiniButton(
            icon: Icons.edit_calendar,
            label: "CARICA\nMANUALE",
            color: Colors.orangeAccent,
            onTap: () => _showManualEntryDialog(),
          ),
          // Questi due servono a mantenere il pulsante arancione della stessa misura degli altri
          const SizedBox(width: 8),
          const Expanded(child: SizedBox()),
          const SizedBox(width: 8),
          const Expanded(child: SizedBox()),
        ],
      ),
    ],
  );

// Helper per i bottoni piccoli della riga inferiore
  
  Widget _buildMiniButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
  return Expanded( // Lo mettiamo qui per sicurezza, così occupa lo spazio corretto nella Row
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // <--- Questo dice a iOS: "Tutta l'area è cliccabile"
      child: Container(
        height: 75,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color), // Icona più grande per un target migliore
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.9),
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showSettings() async {
  // Riceviamo l'eventuale nuovo ID dal Navigator
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SettingsPage(userId: userId),
    ),
  );

  // Se result non è nullo, significa che l'ID è cambiato
  if (result != null && result is String) {
    setState(() {
      userId = result;
    });
  }

  // Ricarichiamo i dati (che ora useranno il nuovo userId)
  _loadData(); 
}

  void _showVehicleSelector() {
    String? selectedBrand;
    List<String> brands = remoteEvDatabase.map((e) => e['brand'] as String).toSet().toList()..sort();
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF0A141D), isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))), builder: (c) => StatefulBuilder(builder: (context, setModalState) {
      List<Map<String, dynamic>> models = selectedBrand == null ? [] : remoteEvDatabase.where((e) => e['brand'] == selectedBrand).toList()..sort((a,b) => a['model'].compareTo(b['model']));
      return SizedBox(height: MediaQuery.of(context).size.height * 0.8, child: Column(children: [
        const SizedBox(height: 15),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.all(20), child: Row(children: [if (selectedBrand != null) IconButton(icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent), onPressed: () => setModalState(() => selectedBrand = null)), Text(selectedBrand ?? t('select_brand'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent))])),
        Expanded(child: selectedBrand == null ? ListView.builder(itemCount: brands.length, itemBuilder: (context, i) => ListTile(title: Text(brands[i]), onTap: () => setModalState(() => selectedBrand = brands[i]))) : ListView.builder(itemCount: models.length, itemBuilder: (context, i) => ListTile(title: Text(models[i]['model']), subtitle: Text("${models[i]['cap']} kWh"), onTap: () { 
          
          setState(() { 
            selectedVehicle = "${models[i]['brand']} ${models[i]['model']}"; 
            batteryCap = (models[i]['cap'] as num).toDouble(); 
            // AGGIUNTA: Aggiorna il controller della Dashboard così vedi subito il nuovo valore
            _capCtrl.text = batteryCap.toStringAsFixed(1);
          }); 

          // MODIFICA QUI: Passiamo SIA la capacità (cap) SIA il nome (vName)
          _updateParams(cap: batteryCap, vName: selectedVehicle); 
          
          Navigator.pop(context); 
        })))
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
  print("DEBUG: Funzione _showManualEntry chiamata!");
  DateTime manualDate = DateTime.now();
  TimeOfDay manualTime = TimeOfDay.now();
  final TextEditingController kwhCtrl = TextEditingController();

  // Usiamo il rootNavigator per essere sicuri che iOS lo mostri sopra a tutto
  showDialog(
    context: context,
    useRootNavigator: true, // Fondamentale per iOS
    builder: (c) => StatefulBuilder(
      builder: (ctx, st) => AlertDialog(
        backgroundColor: const Color(0xFF0A141D),
        title: Text(
          t('inserimento_manuale'),
          style: const TextStyle(color: Colors.cyanAccent, fontSize: 16),
        ),
        content: SingleChildScrollView( // Aggiunto per evitare errori di pixel con la tastiera su iPhone
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(DateFormat('dd/MM/yyyy').format(manualDate)),
                leading: const Icon(Icons.calendar_today, color: Colors.white),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: manualDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) st(() => manualDate = d);
                },
              ),
              ListTile(
                title: Text(manualTime.format(ctx)),
                leading: const Icon(Icons.access_time, color: Colors.white),
                onTap: () async {
                  final t = await showTimePicker(context: ctx, initialTime: manualTime);
                  if (t != null) st(() => manualTime = t);
                },
              ),
              TextField(
                controller: kwhCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "kWh caricati",
                  labelStyle: TextStyle(color: Colors.cyanAccent),
                  suffixText: "kWh",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("ANNULLA"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () {
              // Chiude la tastiera su iOS
              FocusScope.of(ctx).unfocus();
              
              double? k = double.tryParse(kwhCtrl.text.replaceAll(',', '.'));
              if (k != null) {
                DateTime finalDt = DateTime(
                  manualDate.year, manualDate.month, manualDate.day,
                  manualTime.hour, manualTime.minute
                );
                _addLogEntry(finalDt, k);
                Navigator.pop(c);
                setModal(() {});
              }
            },
            child: const Text("SALVA", style: TextStyle(color: Colors.black)),
          )
        ],
      ),
    ),
  );
}

void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Map<int, double> monthlyData = {for (var i = 1; i <= 12; i++) i: 0.0};
            double totalKwh = 0;
            double totalCost = 0;

            for (var log in history) {
              try {
                DateTime dt = DateTime.parse(log['date']);
                double kwh = double.tryParse(log['kwh'].toString()) ?? 0.0;
                double cost = double.tryParse(log['cost'].toString()) ?? 0.0;
                if (dt.year == _selectedYear) {
                  totalKwh += kwh;
                  totalCost += cost;
                  monthlyData[dt.month] = (monthlyData[dt.month] ?? 0) + kwh;
                }
              } catch (e) {
                debugPrint("Errore dati: $e");
              }
            }

            List<FlSpot> spots = monthlyData.entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                children: [
                  // HEADER CON NAVIGAZIONE ANNO
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      localizedValues[currentLang]?['history'] ?? 'Cronologia',
      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
    ),
    Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.cyanAccent),
          onPressed: () => setModalState(() => _selectedYear--),
        ),
        Text("$_selectedYear", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.cyanAccent),
          onPressed: () => setModalState(() => _selectedYear++),
        ),
        // AGGIUNGIAMO IL TASTO PDF QUI
        const SizedBox(width: 8), // Un po' di spazio tra le frecce e il PDF
        IconButton(
          icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
          tooltip: "Esporta PDF",
          onPressed: () async {
            // 1. Feedback visivo per l'utente
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Generazione PDF in corso..."), 
                duration: Duration(seconds: 2)
              ),
            );

            // 2. Delay tecnico per Safari (iPhone)
            await Future.delayed(const Duration(milliseconds: 500));

            // 3. Chiamata alla funzione
            await _generatePDF();
          },
        ),
      ],
    ),
                        



                      ],
                    ),
                  ),
                  // STATISTICHE ANNO
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text("kWh Anno", style: TextStyle(color: Colors.white38, fontSize: 11)),
                            Text(totalKwh.toStringAsFixed(1), style: const TextStyle(color: Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text("Costo Anno", style: TextStyle(color: Colors.white38, fontSize: 11)),
                            Text("${totalCost.toStringAsFixed(2)}€", style: const TextStyle(color: Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // GRAFICO TECNICO PRECISO
                  Padding(
                    padding: const EdgeInsets.only(right: 25, left: 10),
                    child: SizedBox(
                      height: 180,
                      child: LineChart(
                        LineChartData(
                          minY: 0,
                          gridData: FlGridData(
                            show: true, 
                            drawVerticalLine: true, 
                            getDrawingHorizontalLine: (v) => FlLine(color: Colors.white10, strokeWidth: 1),
                            getDrawingVerticalLine: (v) => FlLine(color: Colors.white10, strokeWidth: 1)
                          ),
                          titlesData: FlTitlesData(
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                const months = ['G', 'F', 'M', 'A', 'M', 'G', 'L', 'A', 'S', 'O', 'N', 'D'];
                                int i = value.toInt() - 1;
                                return (i >= 0 && i < 12) ? Text(months[i], style: const TextStyle(color: Colors.white38, fontSize: 10)) : const Text('');
                              },
                            )),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
  LineChartBarData(
    spots: spots, 
    isCurved: false, 
    color: Colors.cyanAccent, 
    barWidth: 3, 
    isStrokeCapRound: true,
    
    
    dotData: FlDotData(
      show: true,
      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
        radius: 3,
        color: Colors.cyanAccent,
        strokeWidth: 1,
        strokeColor: const Color(0xFF010A0F),
      ),
    ),

    
    belowBarData: BarAreaData(
      show: true,
      color: Colors.cyanAccent.withOpacity(0.1),
    ),
  ),
],
                        ),
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 30),
                  // LISTA LOG CON ELIMINAZIONE SWIPE
                  // --- INIZIO BLOCCO DA INCOLLARE ---
                  Expanded(
                    child: StatefulBuilder(
                      builder: (context, setModalState) {
                        final ora = DateTime.now();
                        
                        // Filtro: Solo ricariche di questo mese e anno
                        final ricaricheMeseCorrente = history.where((log) {
                          final d = DateTime.parse(log['date']);
                          return d.month == ora.month && d.year == ora.year;
                        }).toList();

                        // Filtro: Ricariche dell'anno selezionato (escluso il mese corrente)
                        final ricaricheAnnoSelezionato = history.where((log) {
                          final d = DateTime.parse(log['date']);
                          return d.year == _selectedYear && !(d.month == ora.month && d.year == ora.year);
                        }).toList();

                        if (history.isEmpty) {
                          return const Center(child: Text("Nessun dato", style: TextStyle(color: Colors.white38)));
                        }

                        // Funzione veloce per sommare i kWh di un mese specifico
double sommaKwhMese(int sottraiMesi) {
  final target = DateTime(ora.year, ora.month - sottraiMesi);
  return history.where((log) {
    final d = DateTime.parse(log['date']);
    return d.month == target.month && d.year == target.year;
  }).fold(0.0, (sum, log) => sum + (double.tryParse(log['kwh'].toString()) ?? 0.0));
}

final kwhAttuale = sommaKwhMese(0);
final kwhScorso = sommaKwhMese(1);
final kwhDueFa = sommaKwhMese(2);
                        
                        return ListView(
                          children: [
                            Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStat("2 MESI FA", kwhDueFa),
            _buildStat("MESE SCORSO", kwhScorso),
            _buildStat("ATTUALE", kwhAttuale, active: true),
          ],
        ),
      ),
    ),
                            // --- SEZIONE QUESTO MESE ---
                            if (ricaricheMeseCorrente.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text("IN EVIDENZA (QUESTO MESE)", 
                                  style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              ...ricaricheMeseCorrente.map((log) {
                                final date = DateTime.parse(log['date']);
                                return Dismissible(
                                  key: Key(log['date'] + "evidenza"),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight, 
                                    padding: const EdgeInsets.only(right: 20), 
                                    color: Colors.redAccent, 
                                    child: const Icon(Icons.delete, color: Colors.white)
                                  ),
                                  onDismissed: (dir) async {
                                    setState(() => history.removeWhere((e) => e['date'] == log['date']));
                                    setModalState(() {});
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setString('logs', jsonEncode(history));
                                  },
                                  child: ListTile(
                                    leading: const Icon(Icons.bolt, color: Colors.cyanAccent),
                                    title: Text("${log['provider']} - ${log['cost']}€", 
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    subtitle: Text(DateFormat('dd/MM HH:mm').format(date), 
                                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                    trailing: Text("${log['kwh']} kWh", style: const TextStyle(color: Colors.white70)),
                                  ),
                                );
                              }).toList(),
                            ],

                            const SizedBox(height: 20),

                            // --- SEZIONE ARCHIVIO ANNO ---
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text("ARCHIVIO $_selectedYear", 
                                style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            if (ricaricheAnnoSelezionato.isEmpty)
                              const Center(child: Text("Nessuna ricarica per questo anno", 
                                style: TextStyle(color: Colors.white38, fontSize: 12)))
                            else
                              ...ricaricheAnnoSelezionato.map((log) {
  final date = DateTime.parse(log['date']);
  return Dismissible(
    key: Key(log['date'] + "archivio"),
    direction: DismissDirection.endToStart,
    background: Container(
      alignment: Alignment.centerRight, 
      padding: const EdgeInsets.only(right: 20), 
      color: Colors.redAccent, 
      child: const Icon(Icons.delete, color: Colors.white)
    ),
    onDismissed: (dir) async {
      setState(() => history.removeWhere((e) => e['date'] == log['date']));
      setModalState(() {});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logs', jsonEncode(history));
    },
    child: ListTile(
      leading: Icon(
        log['type'] == 'public' ? Icons.ev_station : Icons.home, 
        color: log['type'] == 'public' ? Colors.blueAccent : Colors.cyanAccent,
        size: 20,
      ),
      title: Text(
        "${log['type'] == 'public' ? (log['provider'] ?? 'Colonnina') : 'Casa'} - ${log['cost']}€", 
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('dd/MM HH:mm').format(date), 
            style: const TextStyle(color: Colors.white38, fontSize: 11)
          ),
          // --- RIGA AUTO ---
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              "🚗 ${log['car'] ?? 'Modello non salvato'}", 
              style: TextStyle(
                color: log['car'] != null ? Colors.amberAccent : Colors.white24, 
                fontSize: 10, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        ],
      ),
      trailing: Text(
        "${log['kwh']} kWh", 
        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)
      ),
    ),
  );
}).toList(),
                          ],
                        );
                      },
                    ),
                  ),
                ], // Chiusura Children Column principale
              ), // Chiusura Column principale
            ); // Chiusura Container/Padding (Corpo Modal)
          }, // Chiusura setModalState
        ); // Chiusura StatefulBuilder
      }, // Chiusura Builder del BottomSheet
    ); // Chiusura showModalBottomSheet
  } // Chiusura funzione _showHistory
void _showManualEntryDialog() async {
  DateTime manualDate = DateTime.now();
  TimeOfDay startTime = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 06, minute: 0);
  final TextEditingController kwhCtrl = TextEditingController();

  showDialog(
    context: context,
    useRootNavigator: true,
    builder: (c) => StatefulBuilder(
      builder: (context, setModal) => AlertDialog(
        backgroundColor: const Color(0xFF0A141D),
        title: const Text("CARICA MANUALE", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. SELEZIONE GIORNO
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, color: Colors.cyanAccent),
                title: Text("${manualDate.day}/${manualDate.month}/${manualDate.year}"),
                onTap: () async {
                  DateTime? d = await showDatePicker(
                    context: context,
                    initialDate: manualDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setModal(() => manualDate = d);
                },
              ),
              // 2. SELEZIONE ORA INIZIO E FINE
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Inizio", style: TextStyle(fontSize: 12, color: Colors.white54)),
                      subtitle: Text(startTime.format(context)),
                      onTap: () async {
                        TimeOfDay? t = await showTimePicker(context: context, initialTime: startTime);
                        if (t != null) setModal(() => startTime = t);
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Fine", style: TextStyle(fontSize: 12, color: Colors.white54)),
                      subtitle: Text(endTime.format(context)),
                      onTap: () async {
                        TimeOfDay? t = await showTimePicker(context: context, initialTime: endTime);
                        if (t != null) setModal(() => endTime = t);
                      },
                    ),
                  ),
                ],
              ),
              // 3. KWH CARICATI
              TextField(
                controller: kwhCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "kWh caricati",
                  suffixText: "kWh",
                  labelStyle: TextStyle(color: Colors.cyanAccent),
                ),
              ),
            ],
          ),
        ),
        // ... (parte finale dell'AlertDialog)
actions: [
  TextButton(onPressed: () => Navigator.pop(c), child: const Text("ANNULLA")),
  ElevatedButton(
    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
    onPressed: () {
      // 1. Pulizia e parsing dei kWh
      double? k = double.tryParse(kwhCtrl.text.replaceAll(',', '.'));
      
      if (k != null && k > 0) {
        // 2. Costruiamo il DateTime di inizio
        DateTime dtInizio = DateTime(
          manualDate.year, 
          manualDate.month, 
          manualDate.day, 
          startTime.hour, 
          startTime.minute
        );

        // 3. Chiamiamo la funzione principale.
        // NON serve calcolare il costo qui, lo farà _addLogEntry 
        // usando la logica minuto per minuto e la potenza Wallbox.
        _addLogEntry(dtInizio, k);

        // 4. Chiudiamo il dialog
        Navigator.pop(c);
        
        // Opzionale: un feedback visivo
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ricarica salvata correttamente"))
        );
      } else {
        // Se il valore kWh non è valido
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Inserisci un valore kWh valido"))
        );
      }
    },
    child: const Text("SALVA", style: TextStyle(color: Colors.black)),
  ),
],
      ),
    ),
  );
}
// FUNZIONE 1: Ripartisce i kWh sulle fasce usando la potenza della Wallbox
Map<String, double> _ripartisciConsumi(DateTime inizio, double kwhRichiesti) {
  double kwhRimanenti = kwhRichiesti;
  DateTime simulazione = inizio;
  Map<String, double> ripartizione = {}; 

  // Usiamo la variabile wallboxPwr che hai già in Dashboard
  double kwhPerMinuto = wallboxPwr / 60.0;

  while (kwhRimanenti > 0) {
    int minutiDalGiorno = simulazione.hour * 60 + simulazione.minute;
    String fasciaAttuale = _getNomeFascia(minutiDalGiorno);

    double energiaEstratta = (kwhRimanenti < kwhPerMinuto) ? kwhRimanenti : kwhPerMinuto;
    ripartizione[fasciaAttuale] = (ripartizione[fasciaAttuale] ?? 0) + energiaEstratta;

    kwhRimanenti -= energiaEstratta;
    simulazione = simulazione.add(const Duration(minutes: 1));
    
    if (wallboxPwr <= 0) break; // Sicurezza
  }
  return ripartizione;
}

// FUNZIONE 2: Identifica il nome della fascia in base ai minuti (0-1440)
String _getNomeFascia(int minuti) {
  if (rates.isEmpty) return "Monoraria";

  for (var rate in rates) {
    try {
      int start;
      int end;

      // Se i dati sono già in minuti (Int)
      if (rate['start'] is int) {
        start = rate['start'];
        end = rate['end'];
      } else {
        // Se i dati sono stringhe "HH:mm"
        List<String> sP = rate['start'].toString().split(':');
        List<String> eP = rate['end'].toString().split(':');
        start = int.parse(sP[0]) * 60 + int.parse(sP[1]);
        end = int.parse(eP[0]) * 60 + int.parse(eP[1]);
      }

      if (start < end) {
        if (minuti >= start && minuti < end) return rate['label'].toString();
      } else {
        if (minuti >= start || minuti < end) return rate['label'].toString();
      }
    } catch (e) {
      debugPrint("Errore parsing fascia: $e");
      continue;
    }
  }
  
  // Ritorna la prima fascia se non trova match, per non restituire mai null
  return rates.first['label'].toString();
}


Future<void> _generatePDF() async {
  // 1. CARICAMENTO LOGO DAGLI ASSETS
  // Assicurati che il file sia in assets/logo.png e registrato in pubspec.yaml
  pw.MemoryImage? logo;
  try {
    final bytes = await rootBundle.load('assets/logo.png');
    logo = pw.MemoryImage(bytes.buffer.asUint8List());
  } catch (e) {
    debugPrint("Logo non trovato o errore: $e");
    // Se non trova il logo, il PDF verrà generato comunque senza immagine
  }

  // 2. RECUPERO DATI UTENTE E VEICOLO
  final prefs = await SharedPreferences.getInstance();
  final String userName = prefs.getString('user_name') ?? "Non specificato";
  final String carPlate = prefs.getString('car_plate') ?? "N/A";
  final String currentVehicle = selectedVehicle; 

  final pdf = pw.Document();
  final DateTime ora = DateTime.now();
  double granTotaleKwh = 0;
  double granTotaleEuro = 0;

  // 3. Raggruppamento dati per Mese
  Map<String, List<Map<String, dynamic>>> raggruppato = {};
  history.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

  for (var log in history) {
    DateTime d = DateTime.parse(log['date']);
    if (d.year == _selectedYear) {
      String mese = DateFormat('MMMM', 'it').format(d).toUpperCase();
      if (!raggruppato.containsKey(mese)) raggruppato[mese] = [];
      raggruppato[mese]!.add(log);
      
      granTotaleKwh += double.tryParse(log['kwh'].toString()) ?? 0;
      granTotaleEuro += double.tryParse(log['cost'].toString()) ?? 0;
    }
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) => [
        // INTESTAZIONE CON LOGO
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                if (logo != null) ...[
                  pw.Image(logo, width: 50, height: 50),
                  pw.SizedBox(width: 15),
                ],
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("REPORT RICARICHE SMARTCHARGE", 
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Text("Utente: $userName", style: pw.TextStyle(fontSize: 11)),
                    pw.Text("Veicolo: $currentVehicle", style: pw.TextStyle(fontSize: 11)),
                    pw.Text("Targa: $carPlate", style: pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text("Anno: $_selectedYear", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text("Data: ${DateFormat('dd/MM/yyyy').format(ora)}", style: pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 15),

        // TABELLE MENSILI
        ...raggruppato.entries.map((entry) {
          double meseKwh = 0;
          double meseEuro = 0;
          for (var item in entry.value) {
            meseKwh += double.tryParse(item['kwh'].toString()) ?? 0;
            meseEuro += double.tryParse(item['cost'].toString()) ?? 0;
          }

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Text(entry.key, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              ),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: ['Data', 'Gestore', 'kWh', 'Costo (EUR)'],
                data: entry.value.map((log) {
                  return [
                    DateFormat('dd/MM/yy').format(DateTime.parse(log['date'])),
                    log['provider'] ?? '-',
                    log['kwh'].toString(),
                    "EUR ${double.tryParse(log['cost'].toString())?.toStringAsFixed(2)}"
                  ];
                }).toList(),
              ),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                padding: const pw.EdgeInsets.only(top: 5, bottom: 15),
                child: pw.Text(
                  "Subtotale ${entry.key}: ${meseKwh.toStringAsFixed(2)} kWh",
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          );
        }).toList(),

        pw.Divider(thickness: 1),
        // TOTALE GENERALE
        pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text("RIEPILOGO ANNUALE", style: pw.TextStyle(fontSize: 10)),
              pw.Text("Energia Totale: ${granTotaleKwh.toStringAsFixed(2)} kWh", style: pw.TextStyle(fontSize: 12)),
              pw.Text("SPESA TOTALE: EUR ${granTotaleEuro.toStringAsFixed(2)}", 
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      ],
    ),
  );

  // Generazione del PDF
  final pdfBytes = await pdf.save();
  final String fileName = "Report_SmartCharge_${_selectedYear}_${carPlate.replaceAll(' ', '_')}.pdf";

  try {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: fileName,
    );
  } catch (e) {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: fileName,
    );
  }
}
Widget _buildStat(String label, double valore, {bool active = false}) {
  return Column(
    children: [
      Text(label, 
        style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      Text(
        valore.toStringAsFixed(1),
        style: TextStyle(
          color: active ? Colors.cyanAccent : Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const Text("kWh", style: TextStyle(color: Colors.white38, fontSize: 9)),
    ],
  );
}
} // CHIUDE LA CLASSE _DashboardState

class TechFlowPainter extends CustomPainter {
  final double pct; final Color color; final double anim; final bool isPulsing;
  TechFlowPainter(this.pct, this.color, this.anim, this.isPulsing);

  @override
  void paint(Canvas canvas, Size size) {
    final double currentWidth = size.width * pct;
    if (currentWidth <= 0) return;
    canvas.clipRect(Rect.fromLTWH(0, 0, currentWidth, size.height));
    Paint fillPaint = Paint()..shader = LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [color.withOpacity(0.3), color, color.withOpacity(0.8)]).createShader(Rect.fromLTWH(0, 0, currentWidth, size.height));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, currentWidth, size.height), Radius.zero), fillPaint);
    if (isPulsing) {
      final double scanPos = (anim * currentWidth * 2) - currentWidth;
      Paint scanPaint = Paint()..shader = LinearGradient(colors: [Colors.transparent, Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.6), Colors.white.withOpacity(0.3), Colors.transparent], stops: const [0.0, 0.4, 0.5, 0.6, 1.0]).createShader(Rect.fromLTWH(scanPos, 0, currentWidth * 0.4, size.height));
      canvas.drawRect(Rect.fromLTWH(scanPos, 0, currentWidth * 0.4, size.height), scanPaint);
      final random = math.Random(42);
      Paint pPaint = Paint()..color = Colors.white.withOpacity(0.4);
      for(int i=0; i<5; i++) {
        canvas.drawCircle(Offset(random.nextDouble() * currentWidth, random.nextDouble() * size.height), 1.5, pPaint);
      }
    }
  }
  @override bool shouldRepaint(covariant TechFlowPainter oldDelegate) => true;
}