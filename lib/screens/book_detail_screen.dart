// ignore_for_file: deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../models/book.dart';
import '../providers/book_provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import 'edit_book_screen.dart';
import 'chat_screen.dart' show ChatDetailScreen;

class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  bool _isRequestingSwap = false;
  bool _isOpeningChat = false;
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final bookProv = Provider.of<BookProvider>(context, listen: false);
    final firestore = FirestoreService();
    final theme = Theme.of(context);

    final isMine = widget.book.ownerId == auth.user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Details'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Book Image
              Container(
                height: 300,
                width: double.infinity,
                color: theme.colorScheme.surfaceVariant,
                child: widget.book.imageUrl.isNotEmpty
                    ? widget.book.imageUrl.startsWith('data:image')
                        ? Image.memory(
                            base64Decode(widget.book.imageUrl.split(',')[1]),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholder(theme);
                            },
                          )
                        : Image.network(
                            widget.book.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholder(theme);
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: theme.colorScheme.primary,
                                ),
                              );
                            },
                          )
                    : _buildPlaceholder(theme),
              ),
              // Book Details
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      widget.book.title,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Author
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.book.author,
                            style: TextStyle(
                              fontSize: 18,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Condition Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getConditionColor(widget.book.condition, theme)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              _getConditionColor(widget.book.condition, theme)
                                  .withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getConditionIcon(widget.book.condition),
                            size: 16,
                            color: _getConditionColor(
                                widget.book.condition, theme),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.book.condition,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getConditionColor(
                                  widget.book.condition, theme),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(widget.book.status, theme)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getStatusColor(widget.book.status, theme)
                              .withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(widget.book.status),
                            size: 14,
                            color: _getStatusColor(widget.book.status, theme),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.book.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(widget.book.status, theme),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Action Buttons
                    if (isMine)
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EditBookScreen(book: widget.book),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text(
                                'Edit Book',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _isDeleting
                                  ? null
                                  : () => _handleDelete(context, bookProv),
                              icon: _isDeleting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.delete_outline),
                              label: Text(
                                  _isDeleting ? 'Deleting...' : 'Delete Book'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                                side:
                                    BorderSide(color: theme.colorScheme.error),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          if (widget.book.status == 'available')
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _isRequestingSwap
                                    ? null
                                    : () => _handleRequestSwap(
                                        context, bookProv, auth),
                                icon: _isRequestingSwap
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.swap_horiz_rounded),
                                label: Text(_isRequestingSwap
                                    ? 'Requesting...'
                                    : 'Request Swap'),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _isOpeningChat
                                  ? null
                                  : () => _handleChat(context, firestore, auth),
                              icon: _isOpeningChat
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(
                                      Icons.chat_bubble_outline_rounded),
                              label:
                                  Text(_isOpeningChat ? 'Opening...' : 'Chat'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
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
              size: 80,
              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
            ),
            const SizedBox(height: 8),
            Text(
              'No Image',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDelete(
      BuildContext context, BookProvider bookProv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: const Text(
            'Are you sure you want to delete this book? This action cannot be undone.'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);
      try {
        await bookProv.deleteBook(widget.book.id);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Book deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting book: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isDeleting = false);
        }
      }
    }
  }

  Future<void> _handleRequestSwap(
      BuildContext context, BookProvider bookProv, AuthProvider auth) async {
    if (auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to request a swap'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // Check requester has at least one available book
    setState(() => _isRequestingSwap = true);
    try {
      final myBooks = await bookProv.getAvailableBooks(auth.user!.uid);
      if (myBooks.isEmpty) {
        if (context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('No books to offer'),
              content: const Text(
                  'You must have at least one available book in your listings to request a swap. Please post a book first.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK')),
              ],
            ),
          );
        }
        return;
      }

      final offered = await showDialog<Book?>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Choose a book to offer'),
          children: myBooks
              .map((b) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, b),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(b.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text(b.condition, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      );

      if (offered == null) return;

      if (FirestoreService.swapFunctionUrl.isNotEmpty) {
        final token =
            await fb_auth.FirebaseAuth.instance.currentUser?.getIdToken();
        if (token == null) throw Exception('Not authenticated');
        await bookProv.createSwapOfferViaFunction(
          functionUrl: FirestoreService.swapFunctionUrl,
          bookId: widget.book.id,
          fromUid: auth.user!.uid,
          toUid: widget.book.ownerId,
          offeredBookId: offered.id,
          idToken: token,
        );
      } else {
        await bookProv.createSwapOffer(
          bookId: widget.book.id,
          fromUid: auth.user!.uid,
          toUid: widget.book.ownerId,
          offeredBookId: offered.id,
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Swap requested!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingSwap = false);
      }
    }
  }

  Future<void> _handleChat(BuildContext context, FirestoreService firestore,
      AuthProvider auth) async {
    if (auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to chat'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isOpeningChat = true);
    try {
      // Get or create chat ID
      final chatId = _getChatId(auth.user!.uid, widget.book.ownerId);

      // Ensure chat exists
      try {
        await firestore.ensureChatExists(
          chatId: chatId,
          userId1: auth.user!.uid,
          userId2: widget.book.ownerId,
          bookId: widget.book.id,
        );
      } catch (e) {
        // Chat might already exist, continue anyway
      }

      // Get other user's name
      final otherUserName =
          await firestore.getUserName(widget.book.ownerId) ?? 'User';

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              chatId: chatId,
              otherUserId: widget.book.ownerId,
              otherUserName: otherUserName,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningChat = false);
      }
    }
  }

  String _getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
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

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'swapped':
        return Colors.blue;
      default:
        return theme.colorScheme.primary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.pending;
      case 'swapped':
        return Icons.swap_horiz;
      default:
        return Icons.info_outline;
    }
  }
}
