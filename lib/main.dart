import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() => runApp(MaterialApp(home: SmartCharge()));

class SmartCharge extends StatefulWidget {
  @override
  _SmartChargeState createState() => _SmartChargeState();
}

class _SmartChargeState extends State<SmartCharge> {
  final TextEditingController _kwhController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Carica i dati salvati
  _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = jsonDecode(prefs.getString('history') ?? '[]');
    });
  }

  // Salva una nuova ricarica
  _saveData() async {
    if (_kwhController.text.isEmpty || _priceController.text.isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final newEntry = {
      'date': DateTime.now().toString().substring(0, 16),
      'kwh': _kwhController.text,
      'price': _priceController.text,
    };

    setState(() {
      _history.insert(0, newEntry);
      _kwhController.clear();
      _priceController.clear();
    });
    
    await prefs.setString('history', jsonEncode(_history));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Le Mie Ricariche ⚡️"), backgroundColor: Colors.green),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _kwhController, decoration: InputDecoration(labelText: "kWh inseriti"), keyboardType: TextInputType.number),
            TextField(controller: _priceController, decoration: InputDecoration(labelText: "Costo Totale (€)"), keyboardType: TextInputType.number),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _saveData, child: Text("Salva Ricarica"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green)),
            Divider(height: 40),
            Expanded(
              child: ListView.builder(
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final item = _history[index];
                  return ListTile(
                    leading: Icon(Icons.ev_station, color: Colors.green),
                    title: Text("${item['kwh']} kWh - ${item['price']} €"),
                    subtitle: Text(item['date']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

