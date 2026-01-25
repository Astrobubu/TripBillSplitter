import 'package:flutter/material.dart';
import '../models/person.dart';

class ParticipantListTile extends StatefulWidget {
  final Person person;
  final Function(String, String?) onUpdate;
  final VoidCallback onRemove;
  final bool isEditable;

  const ParticipantListTile({
    super.key,
    required this.person,
    required this.onUpdate,
    required this.onRemove,
    this.isEditable = true,
  });

  @override
  State<ParticipantListTile> createState() => _ParticipantListTileState();
}

class _ParticipantListTileState extends State<ParticipantListTile> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isEditing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.person.name);
    _phoneController = TextEditingController(text: widget.person.phoneNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    final newName = _nameController.text.trim();
    final newPhone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
    
    if (newName.isNotEmpty) {
      widget.onUpdate(newName, newPhone);
    } else {
      _nameController.text = widget.person.name; // Revert if empty
    }
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEditing) {
        // Sync if not editing
        if (widget.person.name != _nameController.text) {
             _nameController.text = widget.person.name;
        }
        if (widget.person.phoneNumber != _phoneController.text) {
             _phoneController.text = widget.person.phoneNumber ?? '';
        }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8), 
        child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Text(
            widget.person.name.isNotEmpty ? widget.person.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: _isEditing
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    focusNode: _focusNode,
                    autofocus: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Name',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _save(), 
                  ),
                ],
              )
            : GestureDetector(
                onTap: widget.isEditable ? () {
                  setState(() {
                    _isEditing = true;
                  });
                } : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.person.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isEditing && widget.isEditable)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                onPressed: () {
                   setState(() {
                    _isEditing = true;
                  });
                },
              ),
            if (_isEditing)
               IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: _save,
              ),
              
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: widget.onRemove,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
