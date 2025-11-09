import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/book.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // If you deploy the Cloud Function, set this to the function base URL, e.g.
  // https://us-central1-<project>.cloudfunctions.net/api/createSwap
  // Leave empty to use client-side creation (which does NOT update book status).
  static const String swapFunctionUrl = '';

  /// Save or update user profile fields in `users/{uid}`.
  ///
  /// Any non-null named parameter will be merged into the document. `lastLogin`
  /// will be stored as an ISO-8601 UTC string (e.g. 2025-11-09T09:30:00Z) which
  /// makes it easy to display and compare without requiring client-side
  /// Timestamp conversion in the demo video.
  Future<void> saveUserName(
    String uid, {
    String? name,
    String? email,
    bool? verified,
    DateTime? lastLogin,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;
    if (verified != null) data['verified'] = verified;
    if (lastLogin != null){
      data['lastLogin'] = lastLogin.toUtc().toIso8601String();
    }

    final docRef = _db.collection('users').doc(uid);
    final existing = await docRef.get();
    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(data, SetOptions(merge: true));
  }

  Future<String?> getUserName(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['name'] as String?;
  }

  Stream<List<Book>> streamAllBooks() {
    // Get all books and filter client-side to avoid index issues
    return _db.collection('books').snapshots().map((snap) {
      try {
        final books = snap.docs
            .map((d) {
              try {
                final book = Book.fromDoc(d);
                // Only return books with status 'available'
                return book.status == 'available' ? book : null;
              } catch (e) {
                // Skip invalid documents
                return null;
              }
            })
            .whereType<Book>()
            .toList();
        return books;
      } catch (e) {
        // Return empty list on error
        return <Book>[];
      }
    });
  }

  Stream<List<Book>> streamUserBooks(String uid) {
    if (uid.isEmpty) {
      return Stream.value(<Book>[]);
    }
    return _db
        .collection('books')
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      try {
        return snap.docs
            .map((d) {
              try {
                return Book.fromDoc(d);
              } catch (e) {
                return null;
              }
            })
            .whereType<Book>()
            .toList();
      } catch (e) {
        return <Book>[];
      }
    });
  }

  Future<void> createBook(Book book) async {
    await _db.collection('books').add(book.toMap());
  }

  Future<void> updateBook(String id, Map<String, dynamic> data) async {
    await _db.collection('books').doc(id).update(data);
  }

  Future<void> deleteBook(String id) async {
    try {
      // Find active or pending swaps involving this book
      final pendingStates = ['pending', 'accepted'];

      // Query swaps where book is the target
      final targetSnap = await _db
          .collection('swaps')
          .where('bookId', isEqualTo: id)
          .where('state', whereIn: pendingStates)
          .get();

      // Query swaps where book is the offered book
      final offeredSnap = await _db
          .collection('swaps')
          .where('offeredBookId', isEqualTo: id)
          .where('state', whereIn: pendingStates)
          .get();

      final batch = _db.batch();

      for (var doc in [...targetSnap.docs, ...offeredSnap.docs]) {
        final ref = doc.reference;
        batch.update(ref, {
          'state': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelReason': 'book_deleted',
        });
      }

      // Delete the book doc
      final bookRef = _db.collection('books').doc(id);
      batch.delete(bookRef);

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete book: $e');
    }
  }

  // Swap offer
  Future<void> createSwapOffer(
      {required String bookId,
      required String fromUid,
      required String toUid,
      String? offeredBookId}) async {
    try {
      // Prevent requesting a swap on your own book
      if (fromUid == toUid) {
        throw Exception('Cannot request a swap on your own book');
      }

      // Prevent duplicate pending swaps from same requester for same book
      final existing = await _db
          .collection('swaps')
          .where('bookId', isEqualTo: bookId)
          .where('from', isEqualTo: fromUid)
          .where('state', isEqualTo: 'pending')
          .get();
      if (existing.docs.isNotEmpty) {
        throw Exception('You have already requested a swap for this book');
      }
      // Create swap offer
      final swapRef = _db.collection('swaps').doc();
      await swapRef.set({
        'bookId': bookId,
        if (offeredBookId != null) 'offeredBookId': offeredBookId,
        'from': fromUid,
        'to': toUid,
        'visibleTo': [fromUid, toUid],
        'state': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Note: do NOT update the target book status here. The book owner
      // should update status when accepting the offer. Updating here can
      // cause permission-denied errors if the requester is not the owner.

      // Create or update chat room
      final chatId = _getChatId(fromUid, toUid);
      await _db.collection('chats').doc(chatId).set({
        'participants': [fromUid, toUid],
        'lastMessage': 'Swap request sent',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'bookId': bookId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to create swap offer: $e');
    }
  }

  /// Create a swap offer by calling a deployed Cloud Function HTTP endpoint.
  ///
  /// The function should accept a JSON payload with: bookId, fromUid, toUid,
  /// offeredBookId (optional) and verify the caller's ID token. Replace
  /// [functionUrl] with your deployed function URL.
  Future<void> createSwapOfferViaHttp({
    required String functionUrl,
    required String bookId,
    required String fromUid,
    required String toUid,
    String? offeredBookId,
    required String idToken,
  }) async {
    try {
      final uri = Uri.parse(functionUrl);
      final body = {
        'bookId': bookId,
        'fromUid': fromUid,
        'toUid': toUid,
        if (offeredBookId != null) 'offeredBookId': offeredBookId,
      };

      // Use dart:io HttpClient to avoid adding a new http dependency in this patch.
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $idToken');
      request.add(const Utf8Encoder().convert(jsonEncode(body)));
      final response = await request.close();
      final respBody = await response.transform(utf8.decoder).join();
      client.close(force: true);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Function error: ${response.statusCode} - $respBody');
      }
    } catch (e) {
      throw Exception('Failed to call swap function: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> streamChats(String uid) {
    // Get all chats where user is a participant, then sort client-side
    return _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
      final chats = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          ...data,
        };
      }).toList();

      // Sort by lastMessageTime descending (most recent first)
      chats.sort((a, b) {
        final timeA = a['lastMessageTime'] as Timestamp?;
        final timeB = b['lastMessageTime'] as Timestamp?;
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeB.compareTo(timeA);
      });

      return chats;
    });
  }

  Stream<List<Map<String, dynamic>>> streamMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) {
      try {
        return snap.docs.map((d) {
          final data = d.data();
          return {
            'id': d.id,
            ...data,
          };
        }).toList();
      } catch (e) {
        return <Map<String, dynamic>>[];
      }
    });
  }

  Future<void> sendMessage(String chatId, String senderId, String text) async {
    try {
      // Add message to subcollection
      await _db.collection('chats').doc(chatId).collection('messages').add({
        'senderId': senderId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update chat last message. If the chat doc doesn't exist, create it
      // (derive participants from chatId which is of the form 'uid1_uid2').
      try {
        await _db.collection('chats').doc(chatId).update({
          'lastMessage': text,
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (e) {
        // If the document is not found, create it with minimal fields so
        // the message and chat listing become available.
        if (e.code == 'not-found') {
          final parts = chatId.split('_');
          final participants =
              parts.length == 2 ? [parts[0], parts[1]] : [senderId];
          await _db.collection('chats').doc(chatId).set({
            'participants': participants,
            'lastMessage': text,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          rethrow;
        }
      }
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  String _getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // Swap offers
  Stream<List<Map<String, dynamic>>> streamReceivedSwapOffers(String uid) {
    return _db
        .collection('swaps')
        .where('to', isEqualTo: uid)
        .where('visibleTo', arrayContains: uid)
        .snapshots()
        .map((snap) {
      try {
        return snap.docs.map((d) {
          final data = d.data();
          return {
            'id': d.id,
            ...data,
          };
        }).toList();
      } catch (e) {
        return <Map<String, dynamic>>[];
      }
    });
  }

  Stream<List<Map<String, dynamic>>> streamSentSwapOffers(String uid) {
    return _db
        .collection('swaps')
        .where('from', isEqualTo: uid)
        .where('visibleTo', arrayContains: uid)
        .snapshots()
        .map((snap) {
      try {
        return snap.docs.map((d) {
          final data = d.data();
          return {
            'id': d.id,
            ...data,
          };
        }).toList();
      } catch (e) {
        return <Map<String, dynamic>>[];
      }
    });
  }

  Future<Book?> getBook(String bookId) async {
    try {
      final doc = await _db.collection('books').doc(bookId).get();
      if (!doc.exists) return null;
      return Book.fromDoc(doc);
    } catch (e) {
      return null;
    }
  }

  /// Remove [uid] from visibleTo on all swaps where it's present.
  Future<void> clearSwapHistoryForUser(String uid) async {
    try {
      final snaps = await _db
          .collection('swaps')
          .where('visibleTo', arrayContains: uid)
          .get();

      final batch = _db.batch();
      for (var doc in snaps.docs) {
        batch.update(doc.reference, {
          'visibleTo': FieldValue.arrayRemove([uid]),
        });
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to clear swap history: $e');
    }
  }

  /// Return a list of books owned by [uid] that are currently 'available'.
  Future<List<Book>> getUserAvailableBooks(String uid) async {
    try {
      final snap = await _db
          .collection('books')
          .where('ownerId', isEqualTo: uid)
          .where('status', isEqualTo: 'available')
          .get();
      return snap.docs
          .map((d) {
            try {
              return Book.fromDoc(d);
            } catch (_) {
              return null;
            }
          })
          .whereType<Book>()
          .toList();
    } catch (e) {
      return <Book>[];
    }
  }

  Future<void> acceptSwapOffer(String swapId, String bookId) async {
    try {
      final swapRef = _db.collection('swaps').doc(swapId);
      await _db.runTransaction((tx) async {
        final swapSnap = await tx.get(swapRef);
        if (!swapSnap.exists) throw Exception('Swap not found');
        final data = swapSnap.data()!;
        final offeredId = data['offeredBookId'] as String?;

        tx.update(swapRef, {
          'state': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        // Update both books to 'swapped'
        final bookRef = _db.collection('books').doc(bookId);
        tx.update(bookRef, {'status': 'swapped'});
        if (offeredId != null && offeredId.isNotEmpty) {
          final offeredRef = _db.collection('books').doc(offeredId);
          tx.update(offeredRef, {'status': 'swapped'});
        }
      });
    } catch (e) {
      throw Exception('Failed to accept swap offer: $e');
    }
  }

  Future<void> declineSwapOffer(String swapId, String bookId) async {
    try {
      final swapRef = _db.collection('swaps').doc(swapId);
      await _db.runTransaction((tx) async {
        final swapSnap = await tx.get(swapRef);
        if (!swapSnap.exists) throw Exception('Swap not found');
        final data = swapSnap.data()!;
        final offeredId = data['offeredBookId'] as String?;

        tx.update(swapRef, {
          'state': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });

        // Reset both books to 'available'
        final bookRef = _db.collection('books').doc(bookId);
        tx.update(bookRef, {'status': 'available'});
        if (offeredId != null && offeredId.isNotEmpty) {
          final offeredRef = _db.collection('books').doc(offeredId);
          tx.update(offeredRef, {'status': 'available'});
        }
      });
    } catch (e) {
      throw Exception('Failed to decline swap offer: $e');
    }
  }

  Future<void> ensureChatExists({
    required String chatId,
    required String userId1,
    required String userId2,
    required String bookId,
  }) async {
    final chatRef = _db.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      await chatRef.set({
        'participants': [userId1, userId2],
        'lastMessage': 'Chat started',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'bookId': bookId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      // Delete all messages in the chat
      final messagesRef =
          _db.collection('chats').doc(chatId).collection('messages');

      final messagesSnapshot = await messagesRef.get();
      for (var doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the chat document
      await _db.collection('chats').doc(chatId).delete();
    } catch (e) {
      throw Exception('Failed to delete chat: $e');
    }
  }
}
