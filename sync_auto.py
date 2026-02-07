import firebase_admin
from firebase_admin import credentials, firestore
import requests
import time

# Configurazione con i tuoi dati reali
PROJECT_ID = "smartcharge-c5b34"
VIN = "VR7CPZYA5ST281107"

# Inizializzazione
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred, {'projectId': PROJECT_ID})
db = firestore.client()

print(f"--- Avvio Sincronizzazione per {PROJECT_ID} ---")

while True:
    try:
        # 1. Legge dal server PSA locale
        response = requests.get(f'http://localhost:5000/get_vehicleinfo/{VIN}', timeout=10)
        data = response.json()
        soc = data['energy'][0]['level']
        
        # 2. Scrive su Firestore
        # Creiamo una collezione chiamata 'veicoli' e un documento con il tuo VIN
        db.collection('veicoli').document(VIN).set({
            'soc': soc,
            'last_update': firestore.SERVER_TIMESTAMP,
            'project_id': PROJECT_ID
        })
        
        print(f"✅ Inviato a Firebase: {soc}% (VIN: {VIN})")
    except Exception as e:
        print(f"❌ Errore: {e}. Controlla che il server PSA sulla porta 5000 sia attivo.")
    
    time.sleep(60) # Aggiorna ogni minuto