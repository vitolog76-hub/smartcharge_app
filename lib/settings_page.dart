import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

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
    // Cloniamo la lista per non sporcare quella della Home prima del Salva
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

  Future<void> _saveAndSync() async {
    try {
      // 1. Prepariamo le fasce con etichette F1, F2...
      List<Map<String, dynamic>> ratesToSave = [];
      for (int i = 0; i < localRates.length; i++) {
        ratesToSave.add({
          'label': 'F${i + 1}', // Così non avrai più solo "F"
          'start': localRates[i]['start'] ?? '00:00',
          'end': localRates[i]['end'] ?? '00:00',
          'price': double.tryParse(localRates[i]['price'].toString().replaceAll(',', '.')) ?? 0.0,
        });
      }

      // 2. Upload su Firestore - USO I NOMI CHE HAI NEL TUO DATABASE
      await FirebaseFirestore.instance.collection('users').doc(_uidController.text).set({
        'provider': _providerController.text, // <--- QUI! Nel DB è 'provider'
        'rates': ratesToSave,
        'isMultirate': localIsMultirate,
        'monoPrice': localMonoPrice,
        'lastUpdate': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      // 3. Ritorno alla Home (Passiamo 'provider' indietro così la Home si aggiorna)
      Navigator.pop(context, {
        'rates': ratesToSave,
        'isMultirate': localIsMultirate,
        'monoPrice': localMonoPrice,
        'userId': _uidController.text,
        'provider': _providerController.text, // Torniamo il valore del box
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Errore: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(title: const Text("Impostazioni Contratto"), backgroundColor: Colors.transparent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ID UTENTE ---
            const Text("ID UTENTE", style: TextStyle(color: Colors.white70, fontSize: 10)),
            TextField(
              controller: _uidController,
              style: const TextStyle(color: Colors.cyanAccent, fontFamily: 'monospace'),
              decoration: const InputDecoration(hintText: "ID Utente"),
            ),
            const SizedBox(height: 20),

            // --- NOME GESTORE CON EFFETTO GLOW ---
            const Text("NOME GESTORE ENERGIA", 
              style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.15), // L'effetto bagliore
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: TextField(
                controller: _providerController,
                style: const TextStyle(
                  color: Colors.cyanAccent, 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1A1F3D), // Sfondo scuro per far risaltare il neon
                  hintText: "Es: Enel, Tesla, Sorgenia...",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  prefixIcon: const Icon(Icons.flash_on, color: Colors.cyanAccent),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.cyanAccent.withOpacity(0.4), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // --- TIPO CONTRATTO ---
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text("MONORARIA"),
                    selected: !localIsMultirate,
                    onSelected: (v) => setState(() => localIsMultirate = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text("FASCE"),
                    selected: localIsMultirate,
                    onSelected: (v) => setState(() => localIsMultirate = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // --- SEZIONE FASCE O MONO ---
            if (localIsMultirate) ...[
              const Text("DEFINIZIONE FASCE", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...localRates.asMap().entries.map((entry) {
                int i = entry.key;
                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("FASCIA ${i + 1}", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => setState(() => localRates.removeAt(i))),
                        ],
                      ),
                      TextField(
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "Costo kWh (€)", prefixText: "€ "),
                        // Controller creato al volo per gestire il testo
                        controller: TextEditingController(text: localRates[i]['price'].toString())..selection = TextSelection.collapsed(offset: localRates[i]['price'].toString().length),
                        onChanged: (v) => localRates[i]['price'] = double.tryParse(v.replaceAll(',', '.')) ?? 0.0,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              icon: const Icon(Icons.access_time, size: 16, color: Colors.cyanAccent),
                              onPressed: () async {
                                TimeOfDay? t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                if (t != null) setState(() => localRates[i]['start'] = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}");
                              },
                              label: Text("Inizio: ${localRates[i]['start']}", style: const TextStyle(color: Colors.white)),
                            ),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              icon: const Icon(Icons.access_time, size: 16, color: Colors.cyanAccent),
                              onPressed: () async {
                                TimeOfDay? t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                if (t != null) setState(() => localRates[i]['end'] = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}");
                              },
                              label: Text("Fine: ${localRates[i]['end']}", style: const TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => localRates.add({"label": "F", "start": "00:00", "end": "00:00", "price": 0.0})),
                  icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent),
                  label: const Text("AGGIUNGI FASCIA", style: TextStyle(color: Colors.cyanAccent)),
                ),
              ),
            ] else ...[
              TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Costo kWh Unico (€)", prefixText: "€ "),
                controller: TextEditingController(text: localMonoPrice.toString())..selection = TextSelection.collapsed(offset: localMonoPrice.toString().length),
                onChanged: (v) => localMonoPrice = double.tryParse(v.replaceAll(',', '.')) ?? 0.20,
              ),
            ],

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
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