import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class SettingsPage extends StatefulWidget {
  final String userId;
  const SettingsPage({super.key, required this.userId});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Controller per i campi di testo
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _batteryCapController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _providerController = TextEditingController();
  final TextEditingController _monoPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _uidController.text = widget.userId;
    _loadInitialData();
  }
  
  Future<void> _downloadFromCloud() async {
  String uid = _uidController.text.trim();
  if (uid.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Inserisci un ID Utente prima!")));
    return;
  }

  try {
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        // 1. Aggiorniamo i controller a video
        _userNameController.text = data['userName'] ?? "";
        _providerController.text = data['provider'] ?? "Generico";
        _batteryCapController.text = (data['batteryCap'] ?? 44.0).toString();
        _monoPriceController.text = (data['monoPrice'] ?? 0.20).toString();
        _vehicleController.text = data['vehicleName'] ?? "Manuale / Altro";

        // 2. Salviamo subito nelle SharedPreferences (Dati Gold)
        prefs.setString('last_user_id', uid);
        prefs.setString('userName', _userNameController.text);
        prefs.setString('provider', _providerController.text);
        prefs.setDouble('batteryCap', double.tryParse(_batteryCapController.text) ?? 44.0);
        prefs.setDouble('monoPrice', double.tryParse(_monoPriceController.text) ?? 0.20);
        prefs.setString('vehicleName', _vehicleController.text);
        
        if (data['history'] != null) {
          prefs.setString('logs', jsonEncode(data['history']));
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Dati scaricati con successo!")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Nessun dato trovato per questo ID")));
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Errore download: $e")));
  }
}

  // 1. CARICAMENTO DATI (Legge quello che ha salvato la Dashboard o l'utente)
  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Usiamo 'batteryCap' come chiave unica per la capacità
      double savedCap = prefs.getDouble('batteryCap') ?? 44.0;
      _batteryCapController.text = savedCap.toStringAsFixed(1);
      
      // Usiamo 'vehicleName' come chiave unica per il modello
      _vehicleController.text = prefs.getString('vehicleName') ?? "Manuale / Altro";
      
      _userNameController.text = prefs.getString('userName') ?? "";
      _providerController.text = prefs.getString('provider') ?? "Generico";
      
      double savedPrice = prefs.getDouble('monoPrice') ?? 0.20;
      _monoPriceController.text = savedPrice.toStringAsFixed(2);
    });
  }

  // 2. SALVATAGGIO (Il metodo che vince su tutto)
  Future<void> _saveAll() async {
  String uid = _uidController.text.trim();
  if (uid.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  
  // 1. Verifichiamo se l'ID è cambiato rispetto a quello attuale
  String? oldUid = prefs.getString('last_user_id');
  bool isNewUser = oldUid != uid;

  try {
    // 2. Se l'ID è nuovo, proviamo a vedere se ha già dati sul Cloud
    if (isNewUser) {
      debugPrint("🔍 Cambio ID rilevato. Controllo dati per: $uid");
      DocumentSnapshot newDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      
      if (newDoc.exists) {
        // Se l'utente esiste, carichiamo i SUOI dati nelle memorie locali
        Map<String, dynamic> cloudData = newDoc.data() as Map<String, dynamic>;
        
        await prefs.setDouble('batteryCap', (cloudData['batteryCap'] ?? 44.0).toDouble());
        await prefs.setString('vehicleName', cloudData['vehicleName'] ?? "Manuale / Altro");
        await prefs.setDouble('monoPrice', (cloudData['monoPrice'] ?? 0.20).toDouble());
        await prefs.setString('userName', cloudData['userName'] ?? "");
        await prefs.setString('provider', cloudData['provider'] ?? "Generico");
        
        // Sincronizziamo anche i log se presenti
        if (cloudData['history'] != null) {
          await prefs.setString('logs', jsonEncode(cloudData['history']));
        }
        
        debugPrint("✅ Dati recuperati dal Cloud per il nuovo ID.");
      }
    }

    // 3. Preparazione dati per il salvataggio (quello che vedi a schermo)
    double finalCap = double.tryParse(_batteryCapController.text.replaceAll(',', '.')) ?? 44.0;
    double finalPrice = double.tryParse(_monoPriceController.text.replaceAll(',', '.')) ?? 0.20;

    // Recuperiamo la cronologia (quella appena scaricata o quella attuale)
    String historyRaw = prefs.getString('logs') ?? '[]';
    List<dynamic> currentHistory = jsonDecode(historyRaw);

    Map<String, dynamic> userData = {
      'userName': _userNameController.text,
      'provider': _providerController.text,
      'batteryCap': finalCap,
      'monoPrice': finalPrice,
      'vehicleName': _vehicleController.text,
      'history': currentHistory,
      'lastUpdate': DateTime.now().toIso8601String(),
    };

    // 4. Salvataggio su Firestore (Collection 'users')
    await FirebaseFirestore.instance.collection('users').doc(uid).set(userData, SetOptions(merge: true));

    // 5. Salvataggio Locale definitivo
    await prefs.setString('last_user_id', uid);
    await prefs.setDouble('batteryCap', finalCap);
    await prefs.setString('vehicleName', _vehicleController.text);
    await prefs.setDouble('monoPrice', finalPrice);
    await prefs.setString('userName', _userNameController.text);
    await prefs.setString('provider', _providerController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Profilo aggiornato e sincronizzato!"))
      );
      // Passiamo il nuovo UID indietro alla dashboard per sicurezza
      Navigator.pop(context, uid); 
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Errore durante il cambio ID: $e"))
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A141D),
      appBar: AppBar(
        title: const Text("Impostazioni Profilo"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.cyanAccent), 
            onPressed: _saveAll
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // CAMPO ID UTENTE
            _buildTextField("ID Utente (Sincronizzazione)", _uidController, icon: Icons.fingerprint, enabled: true),
            
            const SizedBox(height: 10),

            // --- NUOVO PULSANTE PER SCARICARE I DATI ---
            ElevatedButton.icon(
              onPressed: _downloadFromCloud, // La funzione che abbiamo scritto prima
              icon: const Icon(Icons.cloud_download),
              label: const Text("SCARICA DATI ESISTENTI"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),

            const SizedBox(height: 25),
            const Divider(color: Colors.white24),
            const SizedBox(height: 15),

            _buildTextField("Nome Utente", _userNameController, icon: Icons.person),
            const SizedBox(height: 15),
            _buildTextField("Modello Auto", _vehicleController, icon: Icons.directions_car),
            const SizedBox(height: 15),
            _buildTextField("Capacità Batteria (kWh)", _batteryCapController, icon: Icons.battery_charging_full, isNumber: true),
            const SizedBox(height: 15),
            _buildTextField("Fornitore Energia", _providerController, icon: Icons.electric_bolt),
            const SizedBox(height: 15),
            _buildTextField("Prezzo Mono-orario (€/kWh)", _monoPriceController, icon: Icons.euro, isNumber: true),
            
            const SizedBox(height: 30),
            
            ElevatedButton(
              onPressed: _saveAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("SALVA E SINCRONIZZA", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {IconData? icon, bool isNumber = false, bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.cyanAccent),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.cyanAccent), borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}