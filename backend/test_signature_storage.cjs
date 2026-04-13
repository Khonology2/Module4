const http = require('http');

async function testSignatureStorage() {
  const reportId = '6b092421-a0d4-47df-aeb6-d672cc82875f';
  const userId = '00356a1b-6e08-44b8-8499-a4491d14e988';
  const userRole = 'deliveryLead';
  
  const signatureData = 'iVBORw0KGgoAAAANSUhEUgAAA4AAAAEkCAYAAAB+Jl+GAAAAAXNSR0IArs4c6QAAAARzQklUCAgICHwIZIgAAAQNSURBVHic7cExAQAAAMKg9U9tCy+gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA...'; // Truncated signature data
  
  const postData = JSON.stringify({
    signatureData: signatureData,
    signatureType: 'manual',
    ipAddress: '127.0.0.1',
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
  });
  
  const options = {
    hostname: 'localhost',
    port: 3001,
    path: `/api/v1/sign-off-reports/${reportId}/signature`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData),
      'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjAwMzU2YTFiLTZlMDgtNDRiOC04NDk5LWE0NDkxZDE0ZTk4OCIsImVtYWlsIjoiZGhsYW1pbmluYW9taTFAZ21haWwuY29tIiwicm9sZSI6ImRlbGl2ZXJ5TGVhZCIsImlhdCI6MTc3NDI0OTQxMSwiZXhwIjoxNzc0MzM1ODExfQ.T_AjRYWdLAnQ9qZS72HwVSfZrtd91fKCo8-xCpfxO4Q'
    }
  };

  const req = http.request(options, (res) => {
    let data = '';

    res.on('data', (chunk) => {
      data += chunk;
    });

    res.on('end', () => {
      console.log('🌐 Signature Storage Response Status:', res.statusCode);
      console.log('📦 Response Body:', data);
      
      try {
        const parsed = JSON.parse(data);
        if (parsed.success) {
          console.log('✅ Signature stored successfully!');
          console.log('📊 Signature data:', JSON.stringify(parsed.data, null, 2));
        } else {
          console.log('❌ Failed to store signature:', parsed.error);
        }
      } catch (e) {
        console.log('❌ Failed to parse response:', e.message);
      }
    });
  });

  req.on('error', (error) => {
    console.error('❌ Request error:', error.message);
  });

  req.write(postData);
  req.end();
}

testSignatureStorage();
