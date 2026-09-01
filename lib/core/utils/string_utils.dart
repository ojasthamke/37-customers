String sanitizeCustomerName(String? name, {String? customerCode}) {
  if (name == null || name.trim().isEmpty) return 'Guest';
  
  final trimmed = name.trim();
  
  // Prevent customer code from leaking as display name
  if (customerCode != null && trimmed.toLowerCase() == customerCode.trim().toLowerCase()) {
    return 'Customer';
  }
  
  final codePattern = RegExp(r'^[A-Z]{2,4}\d{2,6}$', caseSensitive: false);
  if (codePattern.hasMatch(trimmed)) {
    return 'Customer';
  }
  
  final parts = trimmed.split(RegExp(r'\s+'));
  
  if (parts.length > 1) {
    final lastWord = parts.last;
    
    // List of common customer suffix codes to hide (R, L, M, U, D, LD, LR, etc.)
    // We check if the last word is 1 or 2 characters (case insensitive check)
    if (lastWord.length <= 2) {
      return parts.sublist(0, parts.length - 1).join(' ');
    }
  }
  
  return trimmed;
}

String getProductImage(String productName, String? imagePath) {
  if (imagePath != null && imagePath.trim().isNotEmpty) {
    final trimmed = imagePath.trim();
    if (trimmed.startsWith('http')) {
      // Sanitize: replace any internal whitespace with %20
      return trimmed.replaceAll(' ', '%20');
    }
  }
  final n = productName.toLowerCase();
  if (n.contains('potato') || n.contains('aloo')) {
    return 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('tomato') || n.contains('tamatar')) {
    return 'https://images.unsplash.com/photo-1595855759920-86582396756a?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('onion') || n.contains('pyaz') || n.contains('kanda')) {
    return 'https://images.unsplash.com/photo-1508747703725-719777637510?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('apple') || n.contains('seb')) {
    return 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('banana') || n.contains('kela')) {
    return 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('milk') || n.contains('doodh')) {
    return 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('paneer')) {
    return 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('ginger') || n.contains('adrak')) {
    return 'https://images.unsplash.com/photo-1599940824399-b87987ceb72a?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('coriander') || n.contains('dhania') || n.contains('kothimbir')) {
    return 'https://images.unsplash.com/photo-1588879460618-9249e7d947d1?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('garlic') || n.contains('lahsun')) {
    return 'https://images.unsplash.com/photo-1589618474797-59f61b0c0347?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('carrot') || n.contains('gajar')) {
    return 'https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('chilli') || n.contains('mirchi')) {
    return 'https://images.unsplash.com/photo-1564687679808-16ec221b6d19?auto=format&fit=crop&w=600&q=80';
  }
  return 'https://images.unsplash.com/photo-1610397613050-59f7f1554d67?auto=format&fit=crop&w=600&q=80';
}
