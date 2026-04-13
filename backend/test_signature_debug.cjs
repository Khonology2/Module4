const http = require('http');

async function testSignatureStorageWithDebug() {
  const reportId = '6b092421-a0d4-47df-aeb6-d672cc82875f';
  const userId = '00356a1b-6e08-44b8-8499-a4491d14e988';
  const userRole = 'deliveryLead';
  
  // Test with minimal data first
  const postData = JSON.stringify({
    signatureData: 'test_signature_data',
    signatureType: 'manual'
  });
  
  console.log('🧪 Testing signature storage with minimal data...');
  
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
      console.log('🌐 Response Status:', res.statusCode);
      console.log('📦 Response Headers:', res.headers);
      console.log('📦 Response Body:', data);
      
      if (res.statusCode === 500) {
        console.log('❌ Server error - checking logs...');
        // The error details should be in the backend console
      }
    });
  });

  req.on('error', (error) => {
    console.error('❌ Request error:', error.message);
  });

  req.write(postData);
  req.end();
}

testSignatureStorageWithDebug();
