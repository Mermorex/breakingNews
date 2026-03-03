import 'package:intl/intl.dart';

extension DateTimeExtension on DateTime {
  String toTimeAgo({bool numericDates = false}) {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inSeconds < 15) {
      return 'just now';
    } else if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes >= 1 && difference.inMinutes < 2) {
      return numericDates ? '1 minute ago' : 'a minute ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours >= 1 && difference.inHours < 2) {
      return numericDates ? '1 hour ago' : 'an hour ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays >= 1 && difference.inDays < 2) {
      return numericDates ? '1 day ago' : 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      // Fallback to actual date for older posts
      return DateFormat.yMMMd().format(this);
    }
  }
}
