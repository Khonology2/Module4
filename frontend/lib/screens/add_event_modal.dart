import 'package:flutter/material.dart';
import '../models/timeline_event.dart';
import '../theme/flownet_theme.dart';

class AddEventModal extends StatefulWidget {
  final String? projectId;
  final Function(TimelineEvent)? onEventAdded;
  final DateTime? initialDate;
  final DateTime? initialStartTime;
  final DateTime? initialEndTime;

  const AddEventModal({
    super.key,
    this.projectId,
    this.onEventAdded,
    this.initialDate,
    this.initialStartTime,
    this.initialEndTime,
  }) : super();

  @override
  AddEventModalState createState() => AddEventModalState();
}

class AddEventModalState extends State<AddEventModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  TimelineEventType _selectedType = TimelineEventType.task;
  DateTime? _selectedDate;
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isAllDay = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();

    // If a specific start time was provided (from week/day slot), pre-fill time fields.
    if (widget.initialStartTime != null) {
      _isAllDay = false;
      _startTime = widget.initialStartTime;
      _endTime = widget.initialEndTime ??
          widget.initialStartTime!.add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Event',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: FlownetColors.crimsonRed,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleField(),
                      const SizedBox(height: 16),
                      _buildDescriptionField(),
                      const SizedBox(height: 16),
                      _buildTypeSelector(),
                      const SizedBox(height: 16),
                      _buildDateField(),
                      const SizedBox(height: 16),
                      _buildTimeFields(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Event Title',
        hintText: 'Enter event title',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Event title is required';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description',
        hintText: 'Enter event description',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Description is required';
        }
        return null;
      },
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Event Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TimelineEventType.values.map((type) {
            final isSelected = _selectedType == type;
            return FilterChip(
              label: Text(type.displayName),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedType = type;
                });
              },
              backgroundColor: Colors.grey[200],
              selectedColor: type.color.withValues(alpha: 0.2),
              checkmarkColor: type.color,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return ListTile(
      leading: const Icon(Icons.calendar_today),
      title: Text(
        _selectedDate != null
            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
            : 'Select Date',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _selectDate,
    );
  }

  Widget _buildTimeFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _isAllDay,
              onChanged: (value) {
                setState(() {
                  _isAllDay = value ?? true;
                  if (_isAllDay) {
                    _startTime = null;
                    _endTime = null;
                  }
                });
              },
            ),
            const Text('All Day Event'),
          ],
        ),
        if (!_isAllDay) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(
                    _startTime != null
                        ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                        : 'Start Time',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _selectStartTime,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(
                    _endTime != null
                        ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                        : 'End Time',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _selectEndTime,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _saveEvent,
          style: ElevatedButton.styleFrom(
            backgroundColor: FlownetColors.crimsonRed,
            foregroundColor: Colors.white,
          ),
          child: const Text('Add Event'),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime != null
          ? TimeOfDay(hour: _startTime!.hour, minute: _startTime!.minute)
          : const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _startTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime != null
          ? TimeOfDay(hour: _endTime!.hour, minute: _endTime!.minute)
          : const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _endTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _saveEvent() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    if (!_isAllDay && (_startTime == null || _endTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end times')),
      );
      return;
    }

    final event = TimelineEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _selectedType,
      date: _selectedDate,
      startTime: _startTime,
      endTime: _endTime,
      projectId: widget.projectId,
      createdAt: DateTime.now(),
    );

    widget.onEventAdded?.call(event);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event added successfully')),
    );
  }
}
