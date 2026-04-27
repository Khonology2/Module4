import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../widgets/glass_container.dart';
import '../widgets/glass_card.dart';
import '../theme/flownet_theme.dart';
import '../widgets/app_modal.dart';
import '../models/timeline_event.dart';
import '../services/timeline_event_service.dart';
import '../services/timeline_sync_service.dart';
import 'add_event_modal.dart';
import '../utils/date_utils.dart' as app_date;

/// Timeline/Calendar Screen
/// Accessible by all users
/// Displays events, deadlines, and schedule in a calendar/timeline view
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  // View state
  String _activeView = 'Month'; // 'Month' | 'Week' | 'Day' | 'Timeline'
  String? _hoveredView; // For subtle hover effects on view buttons
  DateTime? _hoveredSlotStart; // For hover highlighting on week/day slots

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Events
  final List<TimelineEvent> _events = [];
  final TimelineEventService _timelineEventService = TimelineEventService();
  final TimelineSyncService _timelineSyncService = TimelineSyncService();
  bool _isSyncing = false;

  // Calendar view constants - Professional scheduling standards
  static const int _startHour = 6; // 6 AM
  static const int _endHour = 22; // 10 PM
  static const double _hourHeight = 90.0; // Professional hour height
  static const double _minuteHeight =
      _hourHeight / 60.0; // 1.5 pixels per minute
  static const Duration _defaultEventDuration =
      Duration(hours: 1); // Default 1 hour for events
  static const double _minEventHeight = 40.0; // Minimum readable height

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    // First load local events
    final localEvents = await _timelineEventService.loadEvents();
    
    // Then try to sync with backend
    await _syncWithBackend(localEvents);
  }

  Future<void> _syncWithBackend(List<TimelineEvent> localEvents) async {
    setState(() => _isSyncing = true);
    
    try {
      // Get events from backend
      final backendEvents = await _timelineSyncService.syncTimelineEvents();
      
      // Merge local and backend events (backend takes precedence)
      final allEvents = <TimelineEvent>[];
      final seenIds = <String>{};
      
      // Add backend events first
      for (final event in backendEvents) {
        allEvents.add(event);
        seenIds.add(event.id);
      }
      
      // Add local events that don't exist in backend
      for (final event in localEvents) {
        if (!seenIds.contains(event.id)) {
          allEvents.add(event);
        }
      }
      
      // Sort by start time
      allEvents.sort((a, b) => _getEventStartDateTime(a).compareTo(_getEventStartDateTime(b)));
      
      // Save merged events to local storage
      await _timelineEventService.saveEvents(allEvents);
      
      if (!mounted) return;
      debugPrint('TimelineScreen: Total events loaded: ${allEvents.length}');
      setState(() {
        _events
          ..clear()
          ..addAll(allEvents);
        _isSyncing = false;
      });
      
    } catch (e) {
      debugPrint('Error syncing with backend: $e');
      // Fallback to local events only
      if (!mounted) return;
      setState(() {
        _events
          ..clear()
          ..addAll(localEvents);
        _isSyncing = false;
      });
    }
  }

  Future<void> _refreshTimeline() async {
    await _loadEvents();
  }

  List<TimelineEvent> _getEventsForDay(DateTime day) {
    final dayEvents = _events.where((event) {
      DateTime? eventStartDate;
      DateTime? eventEndDate;

      // For new events, use startTime and endTime
      if (event.startTime != null) {
        eventStartDate = event.startTime;
        eventEndDate = event.endTime ?? event.startTime; // Use start time if no end time
      }
      // For legacy events, use date field
      else if (event.date != null) {
        eventStartDate = event.date;
        eventEndDate = event.date; // Single day event
      }
      // Fallback to dateTime
      else {
        eventStartDate = event.dateTime;
        eventEndDate = event.dateTime;
      }

      if (eventStartDate == null) return false;
      
      // Check if the day falls within the event's date range (inclusive)
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
      
      return dayStart.isBefore(eventEndDate!) && dayEnd.isAfter(eventStartDate);
    }).toList();
    
    return dayEvents;
  }

  List<TimelineEvent> _getEventsForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return _events.where((event) {
      DateTime? eventDate;

      // For new events, use startTime date
      if (event.startTime != null) {
        eventDate = event.startTime;
      }
      // For legacy events, use date field
      else if (event.date != null) {
        eventDate = event.date;
      }
      // Fallback to dateTime
      else {
        eventDate = event.dateTime;
      }

      if (eventDate == null) return false;
      return eventDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
          eventDate.isBefore(weekEnd.add(const Duration(days: 1)));
    }).toList();
  }

  DateTime _getWeekStart(DateTime date) {
    // Get Monday of the week
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    // If user clicks a future (or today) date in Month view, open event creation modal
    if (_activeView == 'Month') {
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);
      final normalizedSelected =
          DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

      final isFutureOrToday = !normalizedSelected.isBefore(normalizedToday);
      if (isFutureOrToday) {
        showAppDialog(
          context: context,
          builder: (context) => AddEventModal(
            initialDate: normalizedSelected,
            onEventAdded: _addEvent,
          ),
        );
      }
    }
  }

  void _onFormatChanged(CalendarFormat format) {
    setState(() {
      _calendarFormat = format;
    });
  }

  void _onPageChanged(DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
    });
  }

  void _addEvent(TimelineEvent event) {
    setState(() {
      _events.add(event);
    });
    _timelineEventService.saveEvents(_events);
  }

  void _toggleTaskCompleted(TimelineEvent event, bool isCompleted) {
    final idx = _events.indexWhere((e) => e.id == event.id);
    if (idx < 0) return;
    setState(() {
      _events[idx] = _events[idx].copyWith(
        isCompleted: isCompleted,
        updatedAt: DateTime.now(),
      );
    });
    _timelineEventService.saveEvents(_events);
  }

  List<TimelineEvent> _getUpcomingTasksForToday() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final tasks = _events.where((e) {
      if (e.type != TimelineEventType.task) return false;
      if (e.isCompleted) return false;
      final start = _getEventStartDateTime(e);
      if (start.isBefore(startOfDay) || !start.isBefore(endOfDay)) return false;
      return !start.isBefore(now) || _isAllDayEvent(e);
    }).toList();
    tasks.sort((a, b) => _getEventStartDateTime(a).compareTo(_getEventStartDateTime(b)));
    return tasks;
  }

  bool _isAllDayEvent(TimelineEvent event) {
    return event.startTime == null || event.endTime == null;
  }

  void _handleTimeSlotTap(DateTime day, int hour) {
    // Normalize to the exact hour for this slot
    final slotStart = DateTime(day.year, day.month, day.day, hour);
    final now = DateTime.now();

    // Prevent creating events in the past
    if (slotStart.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only create events in future time slots.'),
          backgroundColor: FlownetColors.amberOrange,
        ),
      );
      return;
    }

    final slotDate = DateTime(day.year, day.month, day.day);

    showAppDialog(
      context: context,
      builder: (context) => AddEventModal(
        initialDate: slotDate,
        initialStartTime: slotStart,
        onEventAdded: _addEvent,
      ),
    );
  }

  DateTime _getEventStartDateTime(TimelineEvent event) {
    // First check if event has startTime field (from new events)
    if (event.startTime != null) {
      return event.startTime!;
    }

    // Fallback to time field parsing (for old sample events)
    if (event.time != null && event.time!.isNotEmpty) {
      final timeParts = event.time!.split(':');
      if (timeParts.length >= 2) {
        final hour = int.tryParse(timeParts[0]) ?? 12;
        final minute = int.tryParse(timeParts[1]) ?? 0;
        return DateTime(
          event.date?.year ?? DateTime.now().year,
          event.date?.month ?? DateTime.now().month,
          event.date?.day ?? DateTime.now().day,
          hour,
          minute,
        );
      }
    }

    // Fallback to date time or current time
    return event.dateTime;
  }

  DateTime _getEventEndDateTime(TimelineEvent event) {
    // First check if event has endTime field (from new events)
    if (event.endTime != null) {
      return event.endTime!;
    }

    // Fallback: Use the start time and add default duration
    final startTime = _getEventStartDateTime(event);
    return startTime.add(_defaultEventDuration);
  }

  String _formatEventTime(TimelineEvent event) {
    // For new events with startTime and endTime, show both in professional format
    if (event.startTime != null) {
      final startTime = event.startTime!;
      final endTime = event.endTime ?? startTime.add(const Duration(hours: 1));

      // Format: "11:00 AM - 12:00 PM" or "2:30 PM - 4:00 PM"
      final startFormatted = _formatTimeOfDay(startTime);
      final endFormatted = _formatTimeOfDay(endTime);

      return '$startFormatted - $endFormatted';
    }

    // For old events with time string field, convert to professional format
    if (event.time != null && event.time!.isNotEmpty) {
      final timeParts = event.time!.split(':');
      if (timeParts.length >= 2) {
        final hour = int.tryParse(timeParts[0]) ?? 12;
        final minute = int.tryParse(timeParts[1]) ?? 0;
        final dateTime = DateTime(2024, 1, 1, hour, minute);
        return _formatTimeOfDay(dateTime);
      }
    }

    return '';
  }

  String _formatTimeOfDay(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;

    // Convert to 12-hour format
    int displayHour = hour % 12;
    if (displayHour == 0) displayHour = 12;

    final period = hour < 12 ? 'AM' : 'PM';
    final minuteStr = minute > 0 ? ':${minute.toString().padLeft(2, '0')}' : '';

    return '$displayHour$minuteStr $period';
  }

  double _getEventTopPosition(DateTime eventTime, {double headerOffset = 0.0}) {
    // Professional minute-based positioning for exact time slot alignment
    const timelineStartMinutes = _startHour * 60; // 6:00 AM = 360 minutes
    final eventMinutes = eventTime.hour * 60 +
        eventTime.minute; // 8:30 = 8*60 + 30 = 510 minutes

    // Calculate minutes from start of timeline
    final minutesFromStart =
        eventMinutes - timelineStartMinutes; // 510 - 360 = 150 minutes

    // Clamp to valid timeline range
    const validRange =
        (_endHour - _startHour) * 60; // 22-6 = 16 hours = 960 minutes
    final clampedMinutes = minutesFromStart.clamp(0.0, validRange.toDouble());

    // Convert to pixels using professional minute-based positioning
    final position =
        clampedMinutes * _minuteHeight - headerOffset; // 150 * 1.5 = 225px

    // Debug output to verify correct positioning
    debugPrint('=== EVENT POSITIONING DEBUG ===');
    debugPrint(
        'Event Time: $eventTime.hour:${eventTime.minute.toString().padLeft(2, '0')}');
    debugPrint(
        'Timeline Start: $_startHour:00 ($timelineStartMinutes minutes)');
    debugPrint('Event Minutes: $eventMinutes minutes');
    debugPrint('Minutes from Start: $minutesFromStart minutes');
    debugPrint('Pixel per Minute: $_minuteHeight px');
    debugPrint('Calculated Position: $position px');
    debugPrint(
        'Expected: 8:30 should be at 225px (halfway between 8:00=180px and 9:00=270px)');
    debugPrint('=============================');

    return position;
  }

  double _getEventHeight(DateTime startTime, DateTime endTime) {
    // Height based on actual duration for professional calendar
    final durationMinutes = endTime.difference(startTime).inMinutes;
    final height = durationMinutes * _minuteHeight;

    // Ensure minimum height for readability
    return height.clamp(_minEventHeight, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlownetColors.charcoalBlack,
            FlownetColors.charcoalBlack.withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                  maxWidth: 1400, // Desktop-first max width
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // View Switcher
                    _buildViewSwitcher(),
                    const SizedBox(height: 24),

                    _buildTaskReminders(),
                    const SizedBox(height: 24),

                    // Calendar/Timeline Content with subtle view transition
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: KeyedSubtree(
                        key: ValueKey(_activeView),
                        child: _buildCalendarContent(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // My Deliverables
                    _buildMyDeliverables(),
                  ],
                ),
              ),
            );
          },
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  Widget _buildViewSwitcher() {
    // Make the view switcher span the same width as the calendar card below.
    return SizedBox(
      width: double.infinity,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(child: _buildViewButton('Month', Icons.calendar_view_month)),
            const SizedBox(width: 8),
            Expanded(child: _buildViewButton('Week', Icons.calendar_view_week)),
            const SizedBox(width: 8),
            Expanded(child: _buildViewButton('Day', Icons.calendar_today)),
            const SizedBox(width: 8),
            Expanded(child: _buildViewButton('Timeline', Icons.timeline)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskReminders() {
    final tasks = _getUpcomingTasksForToday();
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt, color: FlownetColors.crimsonRed, size: 20),
              const SizedBox(width: 8),
              Text(
                "Today's Task Reminders",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: FlownetColors.pureWhite,
                    ),
              ),
              const Spacer(),
              Text(
                '${tasks.length} upcoming',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FlownetColors.coolGray,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tasks.isEmpty)
            Text(
              'No upcoming tasks for today.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FlownetColors.coolGray,
                  ),
            )
          else
            ...tasks.take(6).map((task) {
              final start = _getEventStartDateTime(task);
              final timeLabel = _isAllDayEvent(task) ? 'All day' : DateFormat('HH:mm').format(start);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  borderRadius: 12.0,
                  child: Row(
                    children: [
                      Checkbox(
                        value: task.isCompleted,
                        onChanged: (v) => _toggleTaskCompleted(task, v ?? false),
                        activeColor: FlownetColors.emeraldGreen,
                        checkColor: FlownetColors.pureWhite,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: FlownetColors.pureWhite,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (task.description.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                task.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: FlownetColors.coolGray,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: FlownetColors.electricBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          timeLabel,
                          style: const TextStyle(
                            color: FlownetColors.electricBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildViewButton(String view, IconData icon) {
    final isActive = _activeView == view;
    final isHovered = _hoveredView == view;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredView = view),
      onExit: (_) => setState(() => _hoveredView = null),
      child: AnimatedScale(
        scale: isActive ? 1.02 : (isHovered ? 1.01 : 1.0),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: GlassContainer(
          onTap: () {
            if (_activeView == view) return;
            setState(() {
              _activeView = view;
              if (view == 'Month') {
                _calendarFormat = CalendarFormat.month;
              } else if (view == 'Week') {
                _calendarFormat = CalendarFormat.week;
              }
            });
          },
          borderRadius: 14.0,
          opacity: isActive
              ? 0.24
              : (isHovered ? 0.16 : 0.10),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? FlownetColors.crimsonRed
                    : (isHovered
                        ? FlownetColors.pureWhite
                        : FlownetColors.coolGray),
              ),
              const SizedBox(width: 8),
              Text(
                view,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                      color: isActive
                          ? FlownetColors.crimsonRed
                          : (isHovered
                              ? FlownetColors.pureWhite
                              : FlownetColors.coolGray),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarContent() {
    switch (_activeView) {
      case 'Week':
        return _buildWeekView();
      case 'Day':
        return _buildDayView();
      case 'Timeline':
        return _buildTimelineView();
      case 'Month':
      default:
        return _buildCalendarView();
    }
  }

  Widget _buildWeekView() {
    final weekStart = _getWeekStart(_focusedDay);
    final weekDays =
        List.generate(7, (index) => weekStart.add(Duration(days: index)));
    final weekEvents = _getEventsForWeek(weekStart);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Week Header with Navigation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: FlownetColors.slate.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: FlownetColors.pureWhite),
                  onPressed: () {
                    setState(() {
                      _focusedDay =
                          _focusedDay.subtract(const Duration(days: 7));
                    });
                  },
                ),
                Text(
                  '${DateFormat('d MMM').format(weekStart)} - ${app_date.DateUtils.formatDate(weekDays.last)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: FlownetColors.pureWhite,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right,
                      color: FlownetColors.pureWhite),
                  onPressed: () {
                    setState(() {
                      _focusedDay = _focusedDay.add(const Duration(days: 7));
                    });
                  },
                ),
              ],
            ),
          ),
          // Week Grid
          SizedBox(
            height: (_endHour - _startHour) * _hourHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Column
                Container(
                  width: 80,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                          color: FlownetColors.slate.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Column(
                    children: List.generate(
                      _endHour - _startHour,
                      (index) => Expanded(
                        child: Container(
                          padding: const EdgeInsets.only(right: 8, top: 4),
                          alignment: Alignment.topRight,
                          child: Text(
                            '${_startHour + index}:00',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: FlownetColors.coolGray,
                                      fontSize: 12,
                                    ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Days Columns
                Expanded(
                  child: Row(
                    children: weekDays.map((day) {
                      final dayEvents = weekEvents.where((event) {
                        DateTime? eventDate;

                        // For new events, use startTime date
                        if (event.startTime != null) {
                          eventDate = event.startTime;
                        }
                        // For legacy events, use date field
                        else if (event.date != null) {
                          eventDate = event.date;
                        }
                        // Fallback to dateTime
                        else {
                          eventDate = event.dateTime;
                        }

                        if (eventDate == null) return false;
                        return eventDate.year == day.year &&
                            eventDate.month == day.month &&
                            eventDate.day == day.day;
                      }).toList();

                      final isToday = day.year == DateTime.now().year &&
                          day.month == DateTime.now().month &&
                          day.day == DateTime.now().day;

                      return Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                  color: FlownetColors.slate
                                      .withValues(alpha: 0.3)),
                              bottom: BorderSide(
                                  color: FlownetColors.slate
                                      .withValues(alpha: 0.3)),
                            ),
                            color: isToday
                                ? FlownetColors.crimsonRed
                                    .withValues(alpha: 0.1)
                                : null,
                          ),
                          child: Stack(
                            children: [
                              // Hour Lines with clickable slots
                              Column(
                                children: List.generate(
                                  _endHour - _startHour,
                                  (index) {
                                    final slotStartHour = _startHour + index;
                                    final slotStart = DateTime(
                                      day.year,
                                      day.month,
                                      day.day,
                                      slotStartHour,
                                    );
                                    final isHovered =
                                        _hoveredSlotStart == slotStart;

                                    return Expanded(
                                      child: MouseRegion(
                                        onEnter: (_) => setState(
                                            () => _hoveredSlotStart = slotStart),
                                        onExit: (_) =>
                                            setState(() => _hoveredSlotStart = null),
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () =>
                                              _handleTimeSlotTap(day, slotStartHour),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 120),
                                            decoration: BoxDecoration(
                                              color: isHovered
                                                  ? FlownetColors.pureWhite
                                                      .withValues(alpha: 0.04)
                                                  : null,
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: FlownetColors.slate
                                                      .withValues(alpha: 0.2),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // Day Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: FlownetColors.graphiteGray
                                      .withValues(alpha: 0.3),
                                  border: Border(
                                    bottom: BorderSide(
                                        color: FlownetColors.slate
                                            .withValues(alpha: 0.3)),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      DateFormat('EEE').format(day),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: FlownetColors.coolGray,
                                            fontSize: 12,
                                          ),
                                    ),
                                    Text(
                                      '${day.day}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: isToday
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isToday
                                                ? FlownetColors.crimsonRed
                                                : FlownetColors.pureWhite,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              // Events
                              if (dayEvents.isNotEmpty)
                                Positioned.fill(
                                  top: 56,
                                  child: Stack(
                                    children: dayEvents.map((event) {
                                      final startTime =
                                          _getEventStartDateTime(event);
                                      final endTime =
                                          _getEventEndDateTime(event);
                                      final top = _getEventTopPosition(
                                          startTime,
                                          headerOffset: 56.0);
                                      final height =
                                          _getEventHeight(startTime, endTime);
                                      final color =
                                          _getColorForTag(event.colorTag);

                                      return Positioned(
                                        top: top,
                                        left: 4,
                                        right: 4,
                                        height:
                                            height.clamp(60.0, double.infinity),
                                        child:
                                            _buildWeekEventCard(event, color),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekEventCard(TimelineEvent event, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEventDetails(event),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Event title with better styling
              Flexible(
                child: Text(
                  event.title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: FlownetColors.pureWhite,
                        fontSize: 12,
                        height: 1.1,
                        letterSpacing: 0.2,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),
              if (_formatEventTime(event).isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: FlownetColors.pureWhite.withValues(alpha: 0.3),
                        width: 1),
                  ),
                  child: Text(
                    _formatEventTime(event),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FlownetColors.pureWhite,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayView() {
    final dayEvents = _getEventsForDay(_selectedDay);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Day Header with Navigation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: FlownetColors.slate.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: FlownetColors.pureWhite),
                  onPressed: () {
                    setState(() {
                      _selectedDay =
                          _selectedDay.subtract(const Duration(days: 1));
                      _focusedDay = _selectedDay;
                    });
                  },
                ),
                Column(
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: FlownetColors.pureWhite,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dayEvents.length} ${dayEvents.length == 1 ? 'event' : 'events'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: FlownetColors.coolGray,
                          ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right,
                      color: FlownetColors.pureWhite),
                  onPressed: () {
                    setState(() {
                      _selectedDay = _selectedDay.add(const Duration(days: 1));
                      _focusedDay = _selectedDay;
                    });
                  },
                ),
              ],
            ),
          ),
          // Professional Day Timeline
          Container(
            height: (_endHour - _startHour) *
                _hourHeight, // 16 hours × 90px = 1440px total
            constraints: const BoxConstraints(
              minHeight: 500, // Professional minimum height
              // maxHeight: 900, // REMOVED - This was causing visual scaling issues!
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Professional Time Column
                Container(
                  width: 80,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                          color: FlownetColors.slate.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Column(
                    children: List.generate(
                      _endHour - _startHour,
                      (index) => Expanded(
                        child: Container(
                          padding: const EdgeInsets.only(right: 8, top: 4),
                          alignment: Alignment.topRight,
                          child: Text(
                            '${_startHour + index}:00',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: FlownetColors.coolGray,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Professional Events Column
                Expanded(
                  child: Stack(
                    children: [
                      // Professional Hour Grid
                      Column(
                        children: List.generate(
                          _endHour - _startHour,
                          (index) {
                            final slotStartHour = _startHour + index;
                            final slotStart = DateTime(
                              _selectedDay.year,
                              _selectedDay.month,
                              _selectedDay.day,
                              slotStartHour,
                            );
                            final isHovered =
                                _hoveredSlotStart == slotStart;

                            return Expanded(
                              child: MouseRegion(
                                onEnter: (_) => setState(
                                    () => _hoveredSlotStart = slotStart),
                                onExit: (_) =>
                                    setState(() => _hoveredSlotStart = null),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _handleTimeSlotTap(
                                    _selectedDay,
                                    slotStartHour,
                                  ),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 120),
                                    decoration: BoxDecoration(
                                      color: isHovered
                                          ? FlownetColors.pureWhite
                                              .withValues(alpha: 0.04)
                                          : null,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: FlownetColors.slate
                                              .withValues(alpha: 0.15),
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Professional Overlapping Events
                      if (dayEvents.isNotEmpty)
                        ..._buildOverlappingEvents(dayEvents),
                      // No events message
                      if (dayEvents.isEmpty)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_available,
                                size: 48,
                                color: FlownetColors.coolGray
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No events scheduled for this day',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: FlownetColors.coolGray
                                          .withValues(alpha: 0.7),
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Click "New Event" button to add one',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: FlownetColors.coolGray
                                          .withValues(alpha: 0.5),
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOverlappingEvents(List<TimelineEvent> dayEvents) {
    // Simple approach - sort events and position them directly without nested Stacks
    final sortedEvents = List<TimelineEvent>.from(dayEvents)
      ..sort((a, b) =>
          _getEventStartDateTime(a).compareTo(_getEventStartDateTime(b)));

    return sortedEvents.map((event) {
      final startTime = _getEventStartDateTime(event);
      final endTime = _getEventEndDateTime(event);
      final top = _getEventTopPosition(startTime);
      final height = _getEventHeight(startTime, endTime);
      final color = _getColorForTag(event.colorTag);

      return Positioned(
        top: top,
        left: 8.0,
        right: 8.0,
        height: height,
        child: _buildProfessionalEventCard(event, color, 200.0),
      );
    }).toList();
  }

  Widget _buildProfessionalEventCard(
      TimelineEvent event, Color color, double availableWidth) {
    final startTime = _getEventStartDateTime(event);
    final endTime = _getEventEndDateTime(event);
    final duration = endTime.difference(startTime);
    final durationMinutes = duration.inMinutes;
    final isSmallEvent = durationMinutes < 30;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEventDetails(event),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: EdgeInsets.all(isSmallEvent ? 4 : 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: color.withValues(alpha: 0.7),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Professional time display
                if (!isSmallEvent) ...[
                  Text(
                    _formatEventTime(event),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FlownetColors.pureWhite,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                ],
                // Professional title display
                Flexible(
                  child: Text(
                    event.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: FlownetColors.pureWhite,
                          fontSize: isSmallEvent ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          letterSpacing: 0.2,
                        ),
                    maxLines: isSmallEvent ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ),
                // Priority indicator for larger events
                if (!isSmallEvent && event.priority != null) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(event.priority!),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      event.priority!.toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: FlownetColors.pureWhite,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return FlownetColors.crimsonRed;
      case 'medium':
        return FlownetColors.slate;
      case 'low':
        return FlownetColors.coolGray;
      default:
        return FlownetColors.coolGray;
    }
  }

  Widget _buildCalendarView() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Calendar Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left,
                    color: FlownetColors.pureWhite),
                onPressed: () {
                  setState(() {
                    if (_calendarFormat == CalendarFormat.month) {
                      _focusedDay =
                          DateTime(_focusedDay.year, _focusedDay.month - 1);
                    } else {
                      _focusedDay =
                          _focusedDay.subtract(const Duration(days: 7));
                    }
                  });
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedDay),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: FlownetColors.pureWhite,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                    color: FlownetColors.pureWhite),
                onPressed: () {
                  setState(() {
                    if (_calendarFormat == CalendarFormat.month) {
                      _focusedDay =
                          DateTime(_focusedDay.year, _focusedDay.month + 1);
                    } else {
                      _focusedDay = _focusedDay.add(const Duration(days: 7));
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Table Calendar
          TableCalendar<TimelineEvent>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              return day.year == _selectedDay.year &&
                  day.month == _selectedDay.month &&
                  day.day == _selectedDay.day;
            },
            calendarFormat: _calendarFormat,
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              // Slightly lighter date text for better contrast
              weekendTextStyle: const TextStyle(
                color: FlownetColors.pureWhite,
              ),
              defaultTextStyle: const TextStyle(
                color: FlownetColors.pureWhite,
                fontWeight: FontWeight.w500,
              ),
              selectedTextStyle: const TextStyle(
                color: FlownetColors.pureWhite,
                fontWeight: FontWeight.bold,
              ),
              todayTextStyle: const TextStyle(
                color: FlownetColors.crimsonRed,
                fontWeight: FontWeight.bold,
              ),
              // Extra breathing room between cells
              cellMargin: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              cellPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              todayDecoration: BoxDecoration(
                color: FlownetColors.crimsonRed.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: FlownetColors.crimsonRed,
                  width: 2,
                ),
              ),
              selectedDecoration: BoxDecoration(
                color: FlownetColors.crimsonRed.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: FlownetColors.crimsonRed,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                color: Colors.transparent, // Hide duplicate month header
                fontSize: 1,
              ),
              leftChevronVisible: false, // Hide duplicate navigation
              rightChevronVisible: false, // Hide duplicate navigation
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: FlownetColors.coolGray),
              weekendStyle: TextStyle(color: FlownetColors.coolGray),
            ),
            onDaySelected: _onDaySelected,
            onFormatChanged: _onFormatChanged,
            onPageChanged: _onPageChanged,
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: FlownetColors.crimsonRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Selected Day Events
          if (_getEventsForDay(_selectedDay).isNotEmpty) ...[
            const Divider(color: FlownetColors.slate),
            const SizedBox(height: 16),
            Text(
              'Events on ${DateFormat('MMMM d, yyyy').format(_selectedDay)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: FlownetColors.pureWhite,
                  ),
            ),
            const SizedBox(height: 12),
            ..._getEventsForDay(_selectedDay)
                .map((event) => _buildEventChip(event)),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineView() {
    final sortedEvents = List<TimelineEvent>.from(_events)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: FlownetColors.pureWhite,
                ),
          ),
          const SizedBox(height: 16),
          if (sortedEvents.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.event_busy,
                      size: 48,
                      color: FlownetColors.coolGray,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No events scheduled',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: FlownetColors.coolGray,
                          ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...sortedEvents.map((event) => _buildTimelineItem(event)),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(TimelineEvent event) {
    final color = _getColorForTag(event.colorTag);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEventDetails(event),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          app_date.DateUtils.formatDate(event.date ?? DateTime.now()),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: FlownetColors.coolGray,
                                  ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            (event.priority ?? '').toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: FlownetColors.pureWhite,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.time ?? ''} • ${event.project ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: FlownetColors.coolGray,
                          ),
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

  Widget _buildEventChip(TimelineEvent event) {
    final color = _getColorForTag(event.colorTag);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showEventDetails(event),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: FlownetColors.pureWhite,
                          ),
                    ),
                    Text(
                      '${event.time ?? ''} • ${event.project ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: FlownetColors.coolGray,
                          ),
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

  void _showEventDetails(TimelineEvent event) {
    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.graphiteGray,
        title: Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: _getColorForTag(event.colorTag),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                event.title,
                style: const TextStyle(
                  color: FlownetColors.pureWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: FlownetColors.coolGray),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Description',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: FlownetColors.coolGray,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                event.description,
                style: const TextStyle(color: FlownetColors.pureWhite),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close',
                style: TextStyle(color: FlownetColors.crimsonRed)),
          ),
        ],
      ),
    );
  }

  Widget _buildMyDeliverables() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.description,
                    color: FlownetColors.crimsonRed,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'My Deliverables',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: FlownetColors.pureWhite,
                        ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  context.go('/deliverables');
                },
                child: const Text(
                  'View All',
                  style: TextStyle(color: FlownetColors.crimsonRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'No deliverables to display.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: FlownetColors.coolGray,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Sync button
        FloatingActionButton.extended(
          onPressed: _isSyncing ? null : _refreshTimeline,
          backgroundColor: _isSyncing 
              ? FlownetColors.coolGray 
              : FlownetColors.electricBlue,
          foregroundColor: FlownetColors.pureWhite,
          icon: _isSyncing 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(FlownetColors.pureWhite),
                  ),
                )
              : const Icon(Icons.sync),
          label: Text(_isSyncing ? 'Syncing...' : 'Sync'),
          elevation: 4,
        ),
        const SizedBox(width: 12),
        // Add event button
        FloatingActionButton.extended(
          onPressed: () {
            showAppDialog(
              context: context,
              builder: (context) => AddEventModal(
                onEventAdded: _addEvent,
              ),
            );
          },
          backgroundColor: FlownetColors.crimsonRed,
          foregroundColor: FlownetColors.pureWhite,
          icon: const Icon(Icons.add),
          label: const Text('New Event'),
          elevation: 8,
        ),
      ],
    );
  }

  Color _getColorForTag(String? tag) {
    switch (tag) {
      case 'red':
        return FlownetColors.crimsonRed;
      case 'blue':
        return FlownetColors.electricBlue;
      case 'green':
        return FlownetColors.emeraldGreen;
      case 'orange':
        return FlownetColors.amberOrange;
      case 'purple':
        return FlownetColors.purple;
      default:
        return FlownetColors.crimsonRed;
    }
  }
}
