import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

class WalletTransaction {
  final String id;
  final String type; // credit or debit
  final double amount;
  final String description;
  final String timestamp;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? 'credit',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      description: json['description'] ?? '',
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'amount': amount,
    'description': description,
    'timestamp': timestamp,
  };
}

class WalletProvider extends ChangeNotifier {
  double _balance = 0.0;
  List<WalletTransaction> _transactions = [];
  String _currentEmail = '';

  double get balance => _balance;
  List<WalletTransaction> get transactions => _transactions;

  void loadWallet(String email) {
    _currentEmail = email;
    _balance = StorageService.getWalletBalance(email);
    final rawTxs = StorageService.getWalletTransactions(email);
    _transactions = rawTxs.map((t) => WalletTransaction.fromJson(t)).toList();
    notifyListeners();
  }

  Future<void> addMoney(double amount, String appName) async {
    _balance += amount;
    final tx = WalletTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'credit',
      amount: amount,
      description: 'Added via $appName',
      timestamp: DateTime.now().toIso8601String(),
    );
    _transactions.insert(0, tx);
    await StorageService.setWalletBalance(_currentEmail, _balance);
    await StorageService.saveWalletTransactions(
      _currentEmail,
      _transactions.map((t) => t.toJson()).toList(),
    );
    notifyListeners();
  }

  Future<void> deduct(double amount, String description) async {
    if (_balance >= amount) {
      _balance -= amount;
    }
    final tx = WalletTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'debit',
      amount: amount,
      description: description,
      timestamp: DateTime.now().toIso8601String(),
    );
    _transactions.insert(0, tx);
    await StorageService.setWalletBalance(_currentEmail, _balance);
    await StorageService.saveWalletTransactions(
      _currentEmail,
      _transactions.map((t) => t.toJson()).toList(),
    );
    notifyListeners();
  }
}
