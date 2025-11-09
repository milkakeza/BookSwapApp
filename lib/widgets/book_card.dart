import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/book.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../services/firestore_service.dart';
import '../providers/book_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/book_detail_screen.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final String meId;
  const BookCard({super.key, required this.book, required this.meId});

  @override
  Widget build(BuildContext context) {
    final bookProv = Provider.of<BookProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isMine = book.ownerId == meId;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookDetailScreen(book: book),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section with Delete Button
            Stack(
              children: [
                Hero(
                  tag: 'book_image_${book.id}',
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                      ),
                      child: book.imageUrl.isNotEmpty
                          ? book.imageUrl.startsWith('data:image')
                              ? Image.memory(
                                  // Base64 image
                                  base64Decode(book.imageUrl.split(',')[1]),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildPlaceholder(theme);
                                  },
                                )
                              : Image.network(
                                  // Network image (Firebase Storage URL)
                                  book.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildPlaceholder(theme);
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                        strokeWidth: 2,
                                        color: theme.colorScheme.primary,
                                      ),
                                    );
                                  },
                                )
                          : _buildPlaceholder(theme),
                    ),
                  ),
                ),
                // Delete Button (Top Right)
                if (isMine)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {}, // Stop event propagation
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Book'),
                                content: const Text(
                                    'Are you sure you want to delete this book?'),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: theme.colorScheme.error,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && context.mounted) {
                              await bookProv.deleteBook(book.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Book deleted'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Details Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    book.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Author
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          book.author,
                          style: TextStyle(
                            fontSize: 15,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Condition Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getConditionColor(book.condition, theme)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getConditionColor(book.condition, theme)
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getConditionIcon(book.condition),
                          size: 14,
                          color: _getConditionColor(book.condition, theme),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          book.condition,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _getConditionColor(book.condition, theme),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Action Button
                  if (!isMine)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: book.status == 'available'
                            ? () async {
                                final auth = Provider.of<AuthProvider>(context,
                                    listen: false);
                                if (auth.user == null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Please sign in to request a swap'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return;
                                }

                                // Ensure requester has at least one available book
                                final myBooks = await bookProv
                                    .getAvailableBooks(auth.user!.uid);
                                if (myBooks.isEmpty) {
                                  if (context.mounted) {
                                    showDialog<void>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('No books to offer'),
                                        content: const Text(
                                            'You must have at least one available book in your listings to request a swap. Please post a book first.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return;
                                }

                                // Let user choose which of their books to offer
                                final offered = await showDialog<Book?>(
                                  context: context,
                                  builder: (context) => SimpleDialog(
                                    title: const Text('Choose a book to offer'),
                                    children: myBooks
                                        .map((b) => SimpleDialogOption(
                                              onPressed: () =>
                                                  Navigator.pop(context, b),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                      child: Text(b.title,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis)),
                                                  const SizedBox(width: 8),
                                                  Text(b.condition,
                                                      style: const TextStyle(
                                                          fontSize: 12)),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                );

                                if (offered == null) return; // user cancelled

                                try {
                                  // If a Cloud Function URL is configured, call it to
                                  // create the swap and mark the target book as pending.
                                  if (FirestoreService
                                      .swapFunctionUrl.isNotEmpty) {
                                    final token = await fb_auth
                                        .FirebaseAuth.instance.currentUser
                                        ?.getIdToken();
                                    if (token == null)
                                      throw Exception('Not authenticated');
                                    await bookProv.createSwapOfferViaFunction(
                                      functionUrl:
                                          FirestoreService.swapFunctionUrl,
                                      bookId: book.id,
                                      fromUid: auth.user!.uid,
                                      toUid: book.ownerId,
                                      offeredBookId: offered.id,
                                      idToken: token,
                                    );
                                  } else {
                                    await bookProv.createSwapOffer(
                                      bookId: book.id,
                                      fromUid: auth.user!.uid,
                                      toUid: book.ownerId,
                                      offeredBookId: offered.id,
                                    );
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(Icons.check_circle,
                                                color: Colors.white),
                                            SizedBox(width: 8),
                                            Text('Swap requested!'),
                                          ],
                                        ),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                        ),
                        icon: Icon(
                          book.status == 'available'
                              ? Icons.swap_horiz_rounded
                              : Icons.info_outline,
                          size: 20,
                        ),
                        label: Text(
                          book.status == 'available'
                              ? 'Request Swap'
                              : book.status.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.5),
            theme.colorScheme.secondaryContainer.withOpacity(0.3),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 50,
              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
            ),
            const SizedBox(height: 4),
            Text(
              'No Image',
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getConditionColor(String condition, ThemeData theme) {
    switch (condition.toLowerCase()) {
      case 'new':
        return Colors.green;
      case 'like new':
        return Colors.blue;
      case 'good':
        return Colors.orange;
      case 'used':
        return Colors.grey;
      default:
        return theme.colorScheme.primary;
    }
  }

  IconData _getConditionIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'new':
        return Icons.star_rounded;
      case 'like new':
        return Icons.star_half_rounded;
      case 'good':
        return Icons.check_circle_outline_rounded;
      case 'used':
        return Icons.book_outlined;
      default:
        return Icons.info_outline;
    }
  }
}
