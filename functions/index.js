const functions = require('firebase-functions');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');

admin.initializeApp();
const db = admin.firestore();

const app = express();
app.use(cors({ origin: true }));

// HTTP endpoint to create a swap and set the target book status to 'pending'
app.post('/createSwap', async (req, res) => {
  try {
    // Verify Authorization header contains Bearer token
    const authHeader = req.get('Authorization') || '';
    if (!authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized: missing token' });
    }

    const idToken = authHeader.split('Bearer ')[1];
    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const { bookId, fromUid, toUid, offeredBookId } = req.body;

    // Basic validation
    if (!bookId || !fromUid || !toUid) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    if (fromUid !== uid) {
      return res.status(403).json({ error: 'Caller UID mismatch' });
    }

    // If offeredBookId is provided, ensure the caller owns it
    if (offeredBookId) {
      const offeredDoc = await db.collection('books').doc(offeredBookId).get();
      if (!offeredDoc.exists || offeredDoc.data().ownerId !== uid) {
        return res.status(403).json({ error: 'You do not own the offered book' });
      }
    }

    // Transaction: create swap doc and update book status
    const swapRef = db.collection('swaps').doc();
    await db.runTransaction(async (tx) => {
      tx.set(swapRef, {
        bookId,
        from: fromUid,
        to: toUid,
        state: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(offeredBookId ? { offeredBookId } : {}),
      });

      const bookRef = db.collection('books').doc(bookId);
      const bookSnap = await tx.get(bookRef);
      if (!bookSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Target book not found');
      }

      // Only set pending if the book is currently available
      const current = bookSnap.data() || {};
      if (current.status !== 'available') {
        throw new functions.https.HttpsError('failed-precondition', 'Book not available');
      }

      tx.update(bookRef, { status: 'pending' });
    });

    return res.status(200).json({ ok: true });
  } catch (err) {
    console.error('createSwap error', err);
    if (err instanceof functions.https.HttpsError) {
      return res.status(400).json({ error: err.message });
    }
    return res.status(500).json({ error: String(err) });
  }
});

exports.api = functions.https.onRequest(app);
