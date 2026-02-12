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
  late List<Map<String, dynamic>> localRates;
  late bool localIsMultirate;
  late double localMonoPrice;

  @override
  void initState() {
    super.initState();
    _uidController = TextEditingController(text: widget.userId);
    _providerController = TextEditingController(text: widget.initialProvider);
    // Creiamo una copia profonda della lista per non modificare l'originale prima del salvataggio
    localRates = List<Map<String, dynamic>>.from(
      widget.initialRates.map((e) => Map<String, dynamic>.from(e))
    );
    localIsMultirate = widget.initialIsMultirate;
    localMonoPrice = widget.initialMonoPrice;
  }

  @override
  void dispose() {
    _uidController.dispose();
    _providerController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserFromFirebase(String uid) async {
    if (uid.isEmpty) return;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _providerController.text = data['provider'] ?? "Generico";
          localIsMultirate = data['isMultirate'] ?? false;
          localMonoPrice = (data['monoPrice'] ?? 0.20).toDouble();
          if (data['rates'] != null) {
            localRates = List<Map<String, dynamic>>.from(data['rates']);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dati recuperati con successo!")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nessun dato trovato per questo ID")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Errore: $e")));
    }
  }

  Future<void> _saveAndSync() async {
    try {
      List<Map<String, dynamic>> ratesToSave = [];
      for (int i = 0; i < localRates.length; i++) {
        ratesToSave.add({
          'label': 'F${i + 1}',
          'start': localRates[i]['start'] ?? '00:00',
          'end': localRates[i]['end'] ?? '00:00',
          'price': double.tryParse(localRates[i]['price'].toString().replaceAll(',', '.')) ?? 0.0,
        });
      }

      // 1. SALVATAGGIO LOCALE (SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', _uidController.text.trim());
      await prefs.setString('energyProvider', _providerController.text);
      await prefs.setString('rates', jsonEncode(ratesToSave));
      await prefs.setBool('isMultirate', localIsMultirate);
      await prefs.setDouble('monoPrice', localMonoPrice);

      // 2. RITORNO ALLA HOME
      // Passiamo tutti i nuovi dati al main.dart, che si occuperà del sync protetto
      if (!mounted) return;
      Navigator.pop(context, {
        'newUserId': _uidController.text.trim(),
        'rates': ratesToSave,
        'isMultirate': localIsMultirate,
        'monoPrice': localMonoPrice,
        'provider': _providerController.text,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Errore salvataggio: $e")));
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
                      hintText: "Inserisci ID Utente",
                      hintStyle: const TextStyle(color: Colors.white24),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // --- NUOVO TASTO COPIA ---
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.cyanAccent),
                  onPressed: () {
                    if (_uidController.text.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: _uidController.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("ID copiato negli appunti!"),
                          backgroundColor: Colors.cyan,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  tooltip: "Copia ID",
                ),
                // --- TASTO DOWNLOAD ESISTENTE ---
                IconButton(
                  icon: const Icon(Icons.cloud_download, color: Colors.cyanAccent),
                  onPressed: () => _fetchUserFromFirebase(_uidController.text),
                  tooltip: "Recupera dati da questo ID",
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                onChanged: (v) => localMonoPrice = double.tryParse(v.replaceAll(',', '.')) ?? 0.0,
                controller: TextEditingController(text: localMonoPrice.toString().replaceAll('.', ',')),
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
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text("F${i + 1}", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 20),
                          Expanded(
                            child: TextField(
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(hintText: "Costo €/kWh", border: InputBorder.none),
                              onChanged: (v) => localRates[i]['price'] = double.tryParse(v.replaceAll(',', '.')) ?? 0.0,
                              controller: TextEditingController(text: localRates[i]['price'].toString()),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                            onPressed: () => setState(() => localRates.removeAt(i)),
                          )
                        ],
                      ),
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
}