import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class SettingsPage extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> initialRates;
  final bool initialIsMultirate;
  final double initialMonoPrice;
  final String initialProvider;

  const SettingsPage({
    super.key,
    required this.userId,
    required this.initialRates,
    required this.initialIsMultirate,
    required this.initialMonoPrice,
    this.initialProvider = "Generico",
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _uidController;
  late TextEditingController _providerController;
  late TextEditingController _userNameController;
  late TextEditingController _carPlateController;
  late TextEditingController _monoPriceController;
  late List<Map<String, dynamic>> localRates;
  late bool localIsMultirate;
  late double localMonoPrice;

  @override
  void initState() {
    super.initState();
    _uidController = TextEditingController(text: widget.userId);
    _providerController = TextEditingController(text: widget.initialProvider);
    _userNameController = TextEditingController();
    _carPlateController = TextEditingController();
    
    localRates = List<Map<String, dynamic>>.from(
      widget.initialRates.map((e) => Map<String, dynamic>.from(e))
    );
    localIsMultirate = widget.initialIsMultirate;
    _monoPriceController = TextEditingController(
      text: widget.initialMonoPrice.toString().replaceAll('.', ',')
    );
   
    _loadUserData();
  }

  
  
  
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userNameController.text = prefs.getString('user_name') ?? "";
      _carPlateController.text = prefs.getString('car_plate') ?? "";
      _providerController.text = prefs.getString('energyProvider') ?? widget.initialProvider;
      localIsMultirate = prefs.getBool('isMultirate') ?? widget.initialIsMultirate;
      
      double savedPrice = prefs.getDouble('monoPrice') ?? widget.initialMonoPrice;
      _monoPriceController.text = savedPrice.toString().replaceAll('.', ',');

      // CARICAMENTO DELLE FASCE SALVATE LOCALMENTE
      String? savedRatesJson = prefs.getString('rates');
      if (savedRatesJson != null) {
        localRates = List<Map<String, dynamic>>.from(jsonDecode(savedRatesJson));
      }
    });
  }

  @override
  void dispose() {
    _uidController.dispose();
    _providerController.dispose();
    _userNameController.dispose();
    _carPlateController.dispose();
    _monoPriceController.dispose();
    super.dispose();
  }
  
  Future<void> _selectTime(int index, String field) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(localRates[index][field].split(':')[0]),
        minute: int.parse(localRates[index][field].split(':')[1]),
      ),
    );
    if (picked != null) {
      setState(() {
        localRates[index][field] = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _fetchUserFromFirebase(String uid) async {
    if (uid.isEmpty) return;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _providerController.text = data['energyProvider'] ?? "Generico";
          _userNameController.text = data['userName'] ?? "";
          _carPlateController.text = data['carPlate'] ?? "";
          localIsMultirate = data['isMultirate'] ?? false;
          
          double cloudPrice = (data['monoPrice'] ?? 0.20).toDouble();
          _monoPriceController.text = cloudPrice.toString().replaceAll('.', ',');
          
          if (data['rates'] != null) {
            localRates = List<Map<String, dynamic>>.from(data['rates']);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dati recuperati con successo!")));
      }
    } catch (e) {
      debugPrint("Errore: $e");
    }
  }

  Future<void> _saveAndSync() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    String newUid = _uidController.text.trim();
    String provider = _providerController.text.trim();
    String userName = _userNameController.text.trim();
    String carPlate = _carPlateController.text.trim();
    double priceToSave = double.tryParse(_monoPriceController.text.replaceAll(',', '.')) ?? 0.0;

    // SALVATAGGIO LOCALE (Chiavi sincronizzate con _loadSimSettings)
    await prefs.setString('last_user_id', newUid);
    await prefs.setString('energyProvider', provider);
    await prefs.setString('user_name', userName);
    await prefs.setString('car_plate', carPlate);
    await prefs.setDouble('monoPrice', priceToSave);
    await prefs.setBool('isMultirate', localIsMultirate);
    await prefs.setString('rates', jsonEncode(localRates));

    // SALVATAGGIO CLOUD
    if (newUid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(newUid).set({
        'provider': provider, // Usiamo 'provider' come chiave Cloud
        'userName': userName,
        'carPlate': carPlate,
        'rates': localRates,
        'isMultirate': localIsMultirate,
        'monoPrice': priceToSave,
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (!mounted) return;

    // Risultato per la funzione _showSettings nel main.dart
    final Map<String, dynamic> resultData = {
      'newUserId': newUid,
      'rates': localRates,
      'isMultirate': localIsMultirate,
      'monoPrice': priceToSave,
      'provider': provider,
    };

    Navigator.pop(context, resultData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Impostazioni salvate!"), backgroundColor: Colors.green),
    );
  } catch (e) {
    debugPrint("Errore: $e");
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text("IMPOSTAZIONI CONTRATTO", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("DATI INTESTAZIONE PDF"),
            TextField(
              controller: _userNameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Nome / Azienda", prefixIcon: Icon(Icons.person, color: Colors.cyanAccent)),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _carPlateController,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: "Targa Veicolo", prefixIcon: Icon(Icons.directions_car, color: Colors.cyanAccent)),
            ),
            const SizedBox(height: 20),
            const Text("ID UTENTE CLOUD", style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
  child: TextField(
    controller: _uidController,
    style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
    decoration: InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), 
        borderSide: BorderSide.none
      ),
      // --- AGGIUNGIAMO LA LENTE DI INGRANDIMENTO ---
      suffixIcon: IconButton(
        icon: const Icon(Icons.search, color: Colors.cyanAccent),
        onPressed: () {
          _fetchUserFromFirebase(_uidController.text);
        },
      ),
      hintText: "Inserisci UID",
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
    ),
    // --- AGGIUNGIAMO L'INVIO DA TASTIERA ---
    onSubmitted: (value) => _fetchUserFromFirebase(value),
  ),
),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.cyanAccent),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _uidController.text));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cloud_download, color: Colors.cyanAccent),
                  onPressed: () => _fetchUserFromFirebase(_uidController.text),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text("GESTORE ENERGIA", style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _providerController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("MONORARIA")),
                    selected: !localIsMultirate,
                    onSelected: (v) => setState(() => localIsMultirate = false),
                    selectedColor: Colors.cyanAccent,
                    labelStyle: TextStyle(color: !localIsMultirate ? Colors.black : Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("FASCE")),
                    selected: localIsMultirate,
                    onSelected: (v) => setState(() => localIsMultirate = true),
                    selectedColor: Colors.cyanAccent,
                    labelStyle: TextStyle(color: localIsMultirate ? Colors.black : Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            if (!localIsMultirate) ...[
              const Text("PREZZO MONORARIO (€/kWh)", style: TextStyle(color: Colors.cyanAccent, fontSize: 10)),
              const SizedBox(height: 8),
              TextField(
                controller: _monoPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(prefixText: "€ ", prefixStyle: TextStyle(color: Colors.cyanAccent)),
              ),
            ] else ...[
              const Text("CONFIGURAZIONE FASCE", style: TextStyle(color: Colors.cyanAccent, fontSize: 10)),
              const SizedBox(height: 10),
              ...localRates.asMap().entries.map((entry) {
                int i = entry.key;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Text("F${i + 1}", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("INIZIO", style: TextStyle(color: Colors.white38, fontSize: 8)),
                          TextButton(
                            onPressed: () => _selectTime(i, 'start'),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                            child: Text(localRates[i]['start'], style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                      const Text("-", style: TextStyle(color: Colors.white24)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("FINE", style: TextStyle(color: Colors.white38, fontSize: 8)),
                          TextButton(
                            onPressed: () => _selectTime(i, 'end'),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                            child: Text(localRates[i]['end'], style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("COSTO €/kWh", style: TextStyle(color: Colors.cyanAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                            TextFormField(
                              key: ValueKey("price_${i}_${localRates[i]['price']}"), 
                              initialValue: localRates[i]['price'].toString().replaceAll('.', ','),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: const InputDecoration(hintText: "0,00", border: InputBorder.none, isDense: true),
                              onChanged: (v) {
                                localRates[i]['price'] = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
                              },
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                        onPressed: () => setState(() => localRates.removeAt(i)),
                      )
                    ],
                  ),
                );
              }).toList(),
              TextButton.icon(
                onPressed: () => setState(() => localRates.add({"label": "F", "start": "00:00", "end": "00:00", "price": 0.0})),
                icon: const Icon(Icons.add, color: Colors.cyanAccent),
                label: const Text("AGGIUNGI FASCIA", style: TextStyle(color: Colors.cyanAccent)),
              ),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveAndSync,
                child: const Text("SALVA E SINCRONIZZA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Text(title, style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
    );
  }
}