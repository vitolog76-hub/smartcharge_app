export default async function handler(req, res) {
  // L'indirizzo del tuo Mac via Ngrok
  const targetUrl = 'https://sternmost-dispersedly-markita.ngrok-free.dev/get_vehicleinfo/VR7CPZYA5ST281107';
  
  try {
    const response = await fetch(targetUrl, {
      method: 'GET',
      headers: {
        'ngrok-skip-browser-warning': 'true',
        'Accept': 'application/json',
      },
    });

    if (!response.ok) {
      throw new Error(`Errore server: ${response.status}`);
    }

    const data = await response.json();
    // Mandiamo all'app solo il dato pulito
    res.status(200).json(data);
  } catch (error) {
    console.error('Errore ponte API:', error);
    res.status(500).json({ error: 'Il Mac non risponde o Ngrok è spento' });
  }
}