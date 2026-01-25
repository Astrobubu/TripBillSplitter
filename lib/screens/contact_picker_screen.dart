import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/database_service.dart';
import '../models/person.dart';

class ContactPickerScreen extends StatefulWidget {
  final List<String> excludedPhoneNumbers;
  final List<String> excludedNames;

  const ContactPickerScreen({
    super.key, 
    this.excludedPhoneNumbers = const [],
    this.excludedNames = const [],
  });

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Tab 1: Device Contacts
  List<Contact>? _deviceContacts;
  bool _isLoadingContacts = true;
  
  // Tab 2: Recent / History
  List<Person>? _historyPeople;
  bool _isLoadingHistory = true;

  // Selection
  final Set<String> _selectedIds = {}; // ID could be contactID or PersonID
  final Map<String, Map<String, String?>> _selectedData = {}; // ID -> {name, phone}

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDeviceContacts();
    _loadHistoryPeople();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceContacts() async {
    if (await Permission.contacts.request().isGranted) {
      try {
        final contacts = await FlutterContacts.getContacts(withProperties: true);
        if (mounted) {
          setState(() {
            _deviceContacts = contacts;
            _isLoadingContacts = false;
          });
        }
      } catch (e) {
        if (mounted) {
           setState(() => _isLoadingContacts = false);
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingContacts = false);
      }
    }
  }

  Future<void> _loadHistoryPeople() async {
    try {
      final people = await DatabaseService.instance.getFrequentPeople();
      if (mounted) {
        setState(() {
          _historyPeople = people;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  bool _isExcluded(String? name, String? phone) {
    if (name != null && widget.excludedNames.any((n) => n.toLowerCase() == name.toLowerCase())) {
      return true;
    }
    if (phone != null && widget.excludedPhoneNumbers.contains(phone)) {
      return true;
    }
    return false;
  }

  void _toggleSelection(String id, String name, String? phone) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _selectedData.remove(id);
      } else {
        _selectedIds.add(id);
        _selectedData[id] = {'name': name, 'phone': phone};
      }
    });
  }

  void _finish() {
    Navigator.pop(context, _selectedData.values.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add People'),
        bottom: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent, // Remove white line
          tabs: const [
            Tab(text: 'Frequent'),
            Tab(text: 'Contacts'),
          ],
        ),
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton(
              onPressed: _finish,
              child: Text('Add (${_selectedIds.length})'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search people...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHistoryList(),
                _buildContactsList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _finish,
              label: Text('Add ${_selectedIds.length}'),
              icon: const Icon(Icons.check),
            )
          : null,
    );
  }

  Widget _buildHistoryList() {
    if (_isLoadingHistory) return const Center(child: CircularProgressIndicator());
    if (_historyPeople == null || _historyPeople!.isEmpty) {
      return const Center(child: Text('No recent people found.'));
    }

    final filtered = _historyPeople!.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final person = filtered[index];
        final isExcluded = _isExcluded(person.name, person.phoneNumber);
        final isSelected = _selectedIds.contains(person.id);

        return CheckboxListTile(
          value: isSelected || isExcluded,
          enabled: !isExcluded,
          onChanged: isExcluded ? null : (_) => _toggleSelection(person.id, person.name, person.phoneNumber),
          title: Text(
            person.name,
            style: TextStyle(
              color: isExcluded ? Colors.grey : null,
              decoration: isExcluded ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: isExcluded ? const Text('Already added', style: TextStyle(fontSize: 12)) : null,
          secondary: CircleAvatar(
            backgroundColor: isExcluded ? Colors.grey[200] : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(Icons.person, color: isExcluded ? Colors.grey : Theme.of(context).colorScheme.primary),
          ),
        );
      },
    );
  }

  Widget _buildContactsList() {
    if (_isLoadingContacts) return const Center(child: CircularProgressIndicator());
    if (_deviceContacts == null || _deviceContacts!.isEmpty) {
      return const Center(child: Text('No contacts found or permission denied.'));
    }

    final filtered = _deviceContacts!.where((c) {
      return c.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final contact = filtered[index];
        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : null;
        final isExcluded = _isExcluded(contact.displayName, phone);
        final isSelected = _selectedIds.contains(contact.id);

        return CheckboxListTile(
          value: isSelected || isExcluded,
          enabled: !isExcluded,
          onChanged: isExcluded ? null : (_) => _toggleSelection(contact.id, contact.displayName, phone),
          title: Text(
            contact.displayName,
             style: TextStyle(
              color: isExcluded ? Colors.grey : null,
              decoration: isExcluded ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: isExcluded ? const Text('Already added') : null,
          secondary: CircleAvatar(
            backgroundColor: isExcluded ? Colors.grey[200] : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            backgroundImage: (contact.photo != null && contact.photo!.isNotEmpty) 
                ? MemoryImage(contact.photo!) 
                : null,
            child: (contact.photo != null && contact.photo!.isNotEmpty)
                ? null
                : Text(
                    contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                    style: TextStyle(color: isExcluded ? Colors.grey : Theme.of(context).colorScheme.primary),
                  ),
          ),
        );
      },
    );
  }
}
