# 🧪 Testing E-Signature System - Complete Guide

## ✅ **What We're Testing**

1. ✍️ **Delivery Lead Signature** - Must sign before submitting report
2. ✍️ **Client Signature** - Must sign before approving report
3. 🚫 **Signature Enforcement** - Can't bypass signatures
4. 📊 **Signature Display** - View who signed and when
5. 🗄️ **Database Storage** - Signatures saved correctly
6. 🔒 **Security** - Signature validation and hashing

---

## 🚀 **Pre-Test Setup**

### **Step 1: Ensure Backend is Running**
```bash
cd backend
node server.js
```

✅ Should show:
```
✅ PostgreSQL connected!
Flow-Space API server running on port 8000
```

### **Step 2: Start Flutter App**
```bash
# In a new terminal
flutter run
```

Choose your device (Chrome recommended for testing)

---

## 📋 **Test Plan**

### **TEST 1: Delivery Lead Signature on Submission** ✍️

**Goal:** Verify delivery lead must sign before submitting report

**Steps:**
1. ✅ Login as **Delivery Lead**
   - Username: `alice@flowspace.dev` 
   - Password: `Alice2024!`

2. ✅ Navigate to **Reports** section

3. ✅ Click **"Create New Report"**

4. ✅ Fill in report details:
   - Title: "Test Signature Report"
   - Content: "Testing the new e-signature system"
   - Select a deliverable
   - Add next steps (optional)

5. ✅ Click **"Save & Submit"**

6. ✅ **Signature dialog should appear!** 📝
   - Title: "Sign Report Before Submission"
   - Signature box with "Sign here" placeholder

7. ✅ **Try clicking "Sign & Submit" WITHOUT signing**
   - Should show error: "Please provide a signature"

8. ✅ **Draw your signature** in the box (use mouse/touch)

9. ✅ Click **"Sign & Submit"**

10. ✅ **Success message should appear:**
    - "Report submitted successfully!"

**Expected Result:** ✅ Report submitted with signature

**Check Backend Logs:**
```
✅ Signature stored in database
📤 Submitting report: [report-id]
```

---

### **TEST 2: Backend Signature Validation**

**Goal:** Verify backend rejects submission without signature

**Steps:**
1. Check backend logs during submission
2. Should see signature validation

**Expected in logs:**
```
Checking if delivery lead signature exists
✅ Signature verified
Report submitted
```

**If no signature, would see:**
```
❌ Digital signature required
400 Error returned
```

---

### **TEST 3: Client Signature on Approval** ✍️

**Goal:** Verify client must sign before approving report

**Steps:**
1. ✅ **Logout** and login as **Client Reviewer**
   - Username: `charlie@clientcorp.com`
   - Password: `Charlie2024!`

2. ✅ Navigate to **Reports** → **Submitted Reports**

3. ✅ Click on the test report you created

4. ✅ Click **"Review"** button

5. ✅ Select **"Approve"** option

6. ✅ **Signature capture box should appear!** 📝

7. ✅ **Try clicking "Approve Report" WITHOUT signing**
   - Should show error: "⚠️ Digital signature is required to approve this report. Please sign in the signature box above."

8. ✅ **Draw your signature** in the box

9. ✅ Click **"Approve Report"**

10. ✅ **Success message:**
    - "✅ Report approved successfully!"

**Expected Result:** ✅ Report approved with signature

---

### **TEST 4: Signature Display** 📊

**Goal:** View both signatures on approved report

**Steps:**
1. ✅ Open the approved report

2. ✅ Scroll to bottom of report

3. ✅ **Should see "Digital Signatures" section** with:

   **Delivery Lead Signature:**
   - ✅ Signature image displayed
   - ✅ Signer name: Alice Johnson
   - ✅ Role: "Delivery Lead Signature"
   - ✅ Date signed
   - ✅ Green verification badge

   **Client Approval Signature:**
   - ✅ Signature image displayed
   - ✅ Signer name: Charlie Brown
   - ✅ Role: "Client Approval Signature"
   - ✅ Date signed
   - ✅ Green verification badge

4. ✅ Both signatures should be clearly visible and professional

**Expected Result:** ✅ Both signatures displayed with full details

---

### **TEST 5: Database Verification** 🗄️

**Goal:** Verify signatures are stored correctly in database

**Steps:**
1. ✅ Open PowerShell/Terminal

2. ✅ Run:
```bash
cd backend
node -e "const {Pool}=require('pg');const dbConfig=require('./database-config');const pool=new Pool(dbConfig);pool.query('SELECT signer_id, signer_role, signature_type, signed_at, is_valid FROM digital_signatures ORDER BY signed_at DESC LIMIT 5').then(r=>{console.table(r.rows);process.exit()});"
```

**Expected Output:**
```
┌─────────┬─────────────────┬──────────────────┬─────────────────┬──────────────┬──────────┐
│ (index) │   signer_id     │   signer_role    │ signature_type  │  signed_at   │ is_valid │
├─────────┼─────────────────┼──────────────────┼─────────────────┼──────────────┼──────────┤
│    0    │ [uuid]          │ 'clientReviewer' │    'manual'     │  [date]      │   true   │
│    1    │ [uuid]          │ 'deliveryLead'   │    'manual'     │  [date]      │   true   │
└─────────┴─────────────────┴──────────────────┴─────────────────┴──────────────┴──────────┘
```

---

### **TEST 6: Try to Bypass Signature** 🚫

**Goal:** Ensure signatures can't be bypassed

**Test A: Skip delivery lead signature**
1. Create new report
2. Try to submit without signing
3. ✅ Should be blocked with error message

**Test B: Skip client signature**
1. Open submitted report
2. Try to approve without signing
3. ✅ Should be blocked with error message

**Test C: Backend validation**
- Backend should reject requests without signatures
- Returns 400 error: "Digital signature required"

**Expected Result:** ✅ All bypass attempts blocked

---

### **TEST 7: Signature Security** 🔒

**Goal:** Verify signature integrity

**Check in database:**
```sql
-- Connect to PostgreSQL
psql -U postgres -d flow_space

-- Check signature hashes exist
SELECT 
  signer_role,
  LENGTH(signature_hash) as hash_length,
  ip_address,
  signed_at,
  is_valid
FROM digital_signatures
ORDER BY signed_at DESC
LIMIT 5;
```

**Expected:**
- ✅ signature_hash is 64 characters (SHA-256)
- ✅ ip_address is recorded
- ✅ signed_at timestamp present
- ✅ is_valid = true

---

## 🎯 **Quick Test Checklist**

Use this for rapid testing:

- [ ] Backend server running
- [ ] Flutter app running
- [ ] Login as delivery lead
- [ ] Create report
- [ ] Signature dialog appears
- [ ] Can't submit without signing
- [ ] Draw signature and submit
- [ ] Report submitted successfully
- [ ] Login as client reviewer
- [ ] Open submitted report
- [ ] Click approve
- [ ] Signature box appears
- [ ] Can't approve without signing
- [ ] Draw signature and approve
- [ ] Report approved successfully
- [ ] View approved report
- [ ] See both signatures displayed
- [ ] Verification badges shown
- [ ] Check database has signatures

---

## 📊 **Expected Results Summary**

### **✅ Working:**
1. Signature dialog appears at right time
2. Validation prevents bypass
3. Signatures are captured and stored
4. Backend validates before state changes
5. Signatures display beautifully
6. Database stores with hash and metadata
7. Audit trail complete

### **❌ Should NOT Work:**
1. Submitting without delivery lead signature
2. Approving without client signature
3. Bypassing signature dialogs
4. Missing signature data in database

---

## 🐛 **Common Issues & Solutions**

### **Issue: Signature dialog doesn't appear**
**Solution:** 
- Check browser console for errors
- Verify `SignatureCaptureWidget` is imported
- Check report status is correct (draft for submission, submitted for approval)

### **Issue: Can submit/approve without signing**
**Solution:**
- Check backend logs for validation errors
- Verify backend endpoints have signature checks
- Ensure frontend validation is working

### **Issue: Signatures don't display**
**Solution:**
- Check if `SignatureDisplayWidget` is imported
- Verify `_loadSignatures()` method is called
- Check API endpoint returns signature data

### **Issue: Database errors**
**Solution:**
- Verify `digital_signatures` table exists
- Check unique constraint on report_id, signer_id, signer_role
- Run `node create-signature-tables.js` if table missing

---

## 📸 **What to Look For**

### **Signature Dialog:**
- Clean modal with dark background
- White signature canvas
- "Sign here" placeholder text
- Clear and Cancel buttons
- Can't close without signing or canceling

### **Signature Display:**
- Professional card-style layout
- Signature image clear and visible
- Green verification badge
- Signer name and role
- Date and time formatted nicely

### **Success Messages:**
- Green snackbar notifications
- Clear confirmation text
- No errors in console

---

## 🎉 **Test Complete!**

If all tests pass, you have:
- ✅ Fully functional signature system
- ✅ Enforced signature requirements
- ✅ Beautiful signature display
- ✅ Secure signature storage
- ✅ Complete audit trail
- ✅ Production-ready code

---

## 📞 **Need Help?**

Check these files:
- `SIGNATURE_QUICK_START.md` - Quick reference
- `SIGNATURE_SYSTEM_GUIDE.md` - Complete guide
- `SIGNATURE_FIXES_APPLIED.md` - What was implemented

Check backend logs: Look for signature-related messages
Check database: Run queries to verify signature storage

---

**Happy Testing! 🚀**

*Test each feature thoroughly. The signature system is a critical security feature!*

