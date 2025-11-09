import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Maximum size for base64 image (900KB to stay under Firestore's 1MB limit)
  static const int maxBase64Size = 900 * 1024; // 900KB

  Future<String> uploadBookImage(File file, String bookId) async {
    // Check if file exists
    if (!await file.exists()) {
      throw Exception('Image file does not exist');
    }

    // Try Firebase Storage first
    try {
      // Create reference with proper path structure
      final ref = _storage.ref().child('book_images').child('$bookId.jpg');
      
      // Upload file with metadata
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        ),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (e) {
      // If Firebase Storage fails, fall back to compressed base64
      try {
        final compressedBytes = await _compressImage(file);
        if (compressedBytes.length > maxBase64Size) {
          // Image still too large even after compression - skip it
          throw Exception('Image too large even after compression. Skipping image.');
        }
        final base64String = base64Encode(compressedBytes);
        // Return base64 data URL
        return 'data:image/jpeg;base64,$base64String';
      } catch (base64Error) {
        // If base64 also fails, throw the original Firebase error
        throw Exception('Firebase Storage failed: ${e.message}. Image compression also failed: $base64Error');
      }
    } catch (e) {
      // Any other error - try compressed base64 fallback
      try {
        final compressedBytes = await _compressImage(file);
        if (compressedBytes.length > maxBase64Size) {
          throw Exception('Image too large even after compression. Skipping image.');
        }
        final base64String = base64Encode(compressedBytes);
        return 'data:image/jpeg;base64,$base64String';
      } catch (base64Error) {
        throw Exception('Failed to upload image: $e. Image compression also failed: $base64Error');
      }
    }
  }

  Future<Uint8List> _compressImage(File file) async {
    // Read the image file
    final bytes = await file.readAsBytes();
    
    // If already small enough, return as is
    if (bytes.length <= maxBase64Size) {
      return bytes;
    }

    // Decode the image
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 800,
      targetHeight: 1200,
    );
    final frame = await codec.getNextFrame();
    
    // Convert to PNG bytes (smaller than JPEG for this use case)
    final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData == null) {
      throw Exception('Failed to compress image');
    }
    
    var compressedBytes = byteData.buffer.asUint8List();
    
    // If still too large, try more aggressive compression
    if (compressedBytes.length > maxBase64Size) {
      final moreCompressedCodec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 600,
        targetHeight: 900,
      );
      final moreCompressedFrame = await moreCompressedCodec.getNextFrame();
      final moreCompressedByteData = await moreCompressedFrame.image.toByteData(format: ui.ImageByteFormat.png);
      
      if (moreCompressedByteData == null) {
        throw Exception('Failed to compress image');
      }
      
      compressedBytes = moreCompressedByteData.buffer.asUint8List();
      
      // If still too large, try even smaller
      if (compressedBytes.length > maxBase64Size) {
        final smallestCodec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: 400,
          targetHeight: 600,
        );
        final smallestFrame = await smallestCodec.getNextFrame();
        final smallestByteData = await smallestFrame.image.toByteData(format: ui.ImageByteFormat.png);
        
        if (smallestByteData == null) {
          throw Exception('Failed to compress image');
        }
        
        compressedBytes = smallestByteData.buffer.asUint8List();
      }
    }
    
    return compressedBytes;
  }
}
