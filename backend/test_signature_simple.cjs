const http = require('http');

async function testSignatureStorageSimple() {
  const reportId = '6b092421-a0d4-47df-aeb6-d672cc82875f';
  
  // Test with very simple data
  const postData = JSON.stringify({
    signatureData: 'simple_test_signature',
    signatureType: 'manual',
    ipAddress: '127.0.0.1',
    userAgent: 'test'
  });
  
  console.log('🧪 Testing with simple signature data...');
  console.log('📦 Request body:', postData);
  
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
      console.log('📦 Response Body:', data);
      
      if (res.statusCode === 200) {
        console.log('✅ Success! Signature stored');
      } else {
        console.log('❌ Failed to store signature');
      }
    });
  });

  req.on('error', (error) => {
    console.error('❌ Request error:', error.message);
  });

  req.write(postData);
  req.end();
}

testSignatureStorageSimple();
