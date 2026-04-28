/// Testable version of ProjectSetupScreen for unit testing
class TestableProjectSetupScreen {
  // Validation logic extracted for testing
  String? validateField(String fieldName, String? value) {
    switch (fieldName) {
      case 'name':
        if (value == null || value.trim().isEmpty) {
          return 'Project name is required';
        }
        if (value.trim().length < 3) {
          return 'Project name must be at least 3 characters';
        }
        if (value.trim().length > 100) {
          return 'Project name must not exceed 100 characters';
        }
        if (!RegExp(r'^[a-zA-Z0-9\s\-_]+$').hasMatch(value.trim())) {
          return 'Project name can only contain letters, numbers, spaces, hyphens, and underscores';
        }
        break;
      case 'key':
        if (value == null || value.trim().isEmpty) {
          return 'Project key is required';
        }
        if (value.trim().length < 2) {
          return 'Project key must be at least 2 characters';
        }
        if (value.trim().length > 20) {
          return 'Project key must not exceed 20 characters';
        }
        if (!RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(value.trim())) {
          return 'Project key must start with letter and contain only uppercase letters, numbers, and underscores';
        }
        break;
      case 'description':
        if (value == null || value.trim().isEmpty) {
          return 'Description is required';
        }
        if (value.trim().length < 10) {
          return 'Description must be at least 10 characters';
        }
        if (value.trim().length > 1000) {
          return 'Description must not exceed 1000 characters';
        }
        break;
      case 'clientName':
        if (value == null || value.trim().isEmpty) {
          return 'Client name is required';
        }
        if (value.trim().length < 2) {
          return 'Client name must be at least 2 characters';
        }
        if (value.trim().length > 100) {
          return 'Client name must not exceed 100 characters';
        }
        break;
      case 'startDate':
        // For testing purposes, we'll just check if it's null
        if (value == null || value.trim().isEmpty) {
          return 'Start date is required';
        }
        break;
      case 'endDate':
        if (value == null || value.trim().isEmpty) {
          return 'End date is required';
        }
        break;
    }
    return null;
  }
}
