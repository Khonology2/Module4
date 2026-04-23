import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';
import '../widgets/app_modal.dart';

class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  // Handle API errors and return user-friendly messages
  String handleApiError(ApiResponse response) {
    if (response.error == null) return 'An unexpected error occurred';

    // Handle specific HTTP status codes
    switch (response.statusCode) {
      case 400:
        return 'Invalid request. Please check your input and try again.';
      case 401:
        return 'Authentication failed. Please login again.';
      case 403:
        return 'You don\'t have permission to perform this action.';
      case 404:
        return 'The requested resource was not found.';
      case 409:
        return 'A conflict occurred. The resource may have been modified by another user.';
      case 422:
        return 'Validation failed. Please check your input.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      case 500:
        return 'Server error. Please try again later.';
      case 503:
        return 'Service temporarily unavailable. Please try again later.';
      default:
        return response.error!;
    }
  }

  // Handle network errors
  String handleNetworkError(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    } else if (error is HttpException) {
      return 'Network error: ${error.message}';
    } else if (error is FormatException) {
      return 'Invalid response format from server.';
    } else if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    } else {
      return 'An unexpected error occurred: $error';
    }
  }

  // Show error dialog
  void showErrorDialog(BuildContext context, String message, {String? title}) {
    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              title ?? 'Error',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Show error snackbar
  void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            // More robust than hideCurrentSnackBar: clears the active and any queued snackbars
            ScaffoldMessenger.of(context).clearSnackBars();
          },
        ),
      ),
    );
  }

  // Show success snackbar
  void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Show loading dialog
  void showLoadingDialog(BuildContext context, {String? message}) {
    showAppDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Hide loading dialog
  void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  // Handle authentication errors
  void handleAuthError(BuildContext context, ApiResponse response) {
    if (response.statusCode == 401) {
      // Token expired or invalid
      showErrorDialog(
        context,
        'Your session has expired. Please login again.',
        title: 'Session Expired',
      );
      // Navigate to login screen
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } else if (response.statusCode == 403) {
      // Insufficient permissions
      showErrorDialog(
        context,
        'You don\'t have permission to perform this action.',
        title: 'Access Denied',
      );
    } else {
      showErrorDialog(context, handleApiError(response));
    }
  }

  // Handle network connectivity issues
  void handleNetworkErrorDialog(BuildContext context, dynamic error) {
    showErrorDialog(
      context,
      handleNetworkError(error),
      title: 'Network Error',
    );
  }

  // Log errors for debugging
  void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    debugPrint('Error in $context: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // Handle specific business logic errors
  String handleBusinessError(String errorCode) {
    switch (errorCode) {
      case 'DELIVERABLE_NOT_FOUND':
        return 'The deliverable was not found.';
      case 'DELIVERABLE_ALREADY_SUBMITTED':
        return 'This deliverable has already been submitted.';
      case 'DELIVERABLE_NOT_READY':
        return 'The deliverable is not ready for submission.';
      case 'SPRINT_NOT_FOUND':
        return 'The sprint was not found.';
      case 'SPRINT_ALREADY_CLOSED':
        return 'This sprint has already been closed.';
      case 'REPORT_NOT_FOUND':
        return 'The sign-off report was not found.';
      case 'REPORT_ALREADY_APPROVED':
        return 'This report has already been approved.';
      case 'USER_NOT_FOUND':
        return 'The user was not found.';
      case 'INVALID_ROLE':
        return 'Invalid user role specified.';
      case 'PERMISSION_DENIED':
        return 'You don\'t have permission to perform this action.';
      case 'VALIDATION_ERROR':
        return 'Please check your input and try again.';
      default:
        return 'An unexpected error occurred.';
    }
  }

  // Retry mechanism for failed requests
  Future<T?> retryRequest<T>(
    Future<T> Function() request, {
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await request();
      } catch (e) {
        if (attempt == maxAttempts) {
          rethrow;
        }
        debugPrint('Request failed (attempt $attempt/$maxAttempts): $e');
        await Future.delayed(delay * attempt);
      }
    }
    return null;
  }
}

