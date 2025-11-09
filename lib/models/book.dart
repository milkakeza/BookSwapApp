import 'package:cloud_firestore/cloud_firestore.dart';

class Book {
  final String id;
  final String ownerId;
  final String title;
  final String author;
  final String condition; // New, Like New, Good, Used
  final String imageUrl;
  final String status; // available, pending, swapped

  Book({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.author,
    required this.condition,
    required this.imageUrl,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'title': title,
        'author': author,
        'condition': condition,
        'imageUrl': imageUrl,
        'status': status,
      };

  factory Book.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Book(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      title: data['title'] ?? '',
      author: data['author'] ?? '',
      condition: data['condition'] ?? 'Used',
      imageUrl: data['imageUrl'] ?? '',
      status: data['status'] ?? 'available',
    );
  }
}
