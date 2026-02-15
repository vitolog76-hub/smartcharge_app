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
  
  // --- AGGIUNGI QUESTO METODO IN FONDO ALLA CLASSE _SettingsPageState ---
  Widget _buildSectionCard({
    required String title, 
    required IconData icon, 
    required Color color, 
    required Widget child
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05), // Effetto vetro scuro
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(), 
                style: TextStyle(
                  color: color, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 12,
                  letterSpacing: 1.1,
                )
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 25, thickness: 1),
          child,
        ],
      ),
    );
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
    backgroundColor: const Color(0xFF0D1B2A), // Blu notte profondo
    appBar: AppBar(
      title: const Text("Impostazioni Profilo", style: TextStyle(fontWeight: FontWeight.w300)),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          // SEZIONE 1: SINCRONIZZAZIONE
          _buildSectionCard(
            title: "Sincronizzazione Cloud",
            icon: Icons.cloud_sync,
            color: Colors.orangeAccent,
            child: Column(
              children: [
                _buildTextField("ID Utente", _uidController, icon: Icons.fingerprint),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _downloadFromCloud,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text("SCARICA DATI ESISTENTI"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent.withOpacity(0.2),
                    foregroundColor: Colors.orangeAccent,
                    side: const BorderSide(color: Colors.orangeAccent),
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // SEZIONE 2: PROFILO E VEICOLO
          _buildSectionCard(
            title: "Dati Utente e Auto",
            icon: Icons.person_outline,
            color: Colors.cyanAccent,
            child: Column(
              children: [
                _buildTextField("Nome Utente", _userNameController, icon: Icons.badge_outlined),
                const SizedBox(height: 15),
                _buildTextField("Modello Auto", _vehicleController, icon: Icons.directions_car_filled_outlined),
                const SizedBox(height: 15),
                _buildTextField("Capacità Batteria (kWh)", _batteryCapController, icon: Icons.ev_station, isNumber: true),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // SEZIONE 3: COSTI ENERGIA
          _buildSectionCard(
            title: "Parametri Economici",
            icon: Icons.euro_symbol,
            color: Colors.lightGreenAccent,
            child: Column(
              children: [
                _buildTextField("Fornitore Energia", _providerController, icon: Icons.factory_outlined),
                const SizedBox(height: 15),
                _buildTextField("Prezzo (€/kWh)", _monoPriceController, icon: Icons.payments_outlined, isNumber: true),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // TASTO SALVA FINALE
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 5))
              ],
            ),
            child: ElevatedButton(
              onPressed: _saveAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("SALVA E SINCRONIZZA TUTTO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 50),
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
    style: const TextStyle(color: Colors.white, fontSize: 15),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, color: Colors.cyanAccent.withOpacity(0.7), size: 20) : null,
      filled: true,
      fillColor: Colors.black26,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.cyanAccent, width: 1)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}
}