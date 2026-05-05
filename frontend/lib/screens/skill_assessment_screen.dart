import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/flownet_theme.dart';

class SkillAssessmentScreen extends ConsumerStatefulWidget {
  final String? selectedSkill;
  const SkillAssessmentScreen({super.key, this.selectedSkill});

  @override
  ConsumerState<SkillAssessmentScreen> createState() => _SkillAssessmentScreenState();
}

class _SkillAssessmentScreenState extends ConsumerState<SkillAssessmentScreen> {
  final List<Map<String, dynamic>> _skills = [
    {
      'name': 'Flutter Development',
      'level': 85,
      'category': 'Technical',
      'lastAssessed': '2024-01-15',
    },
    {
      'name': 'Dart Programming',
      'level': 90,
      'category': 'Technical',
      'lastAssessed': '2024-01-10',
    },
    {
      'name': 'UI/UX Design',
      'level': 75,
      'category': 'Design',
      'lastAssessed': '2024-01-08',
    },
    {
      'name': 'Project Management',
      'level': 80,
      'category': 'Management',
      'lastAssessed': '2024-01-12',
    },
    {
      'name': 'Team Collaboration',
      'level': 88,
      'category': 'Soft Skills',
      'lastAssessed': '2024-01-14',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedSkill;
    return Scaffold(
      backgroundColor: FlownetColors.charcoalBlack,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Skill Assessment',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: FlownetColors.pureWhite,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Evaluate and track your skill development progress',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: FlownetColors.coolGray,
                  ),
            ),
            const SizedBox(height: 24),
            
            if (selected != null)
              _AssessmentRunner(skillName: selected)
            else
            // Skill Assessment Cards
            Expanded(
              child: ListView.builder(
                itemCount: _skills.length,
                itemBuilder: (context, index) {
                  final skill = _skills[index];
                  return Card(
                    color: FlownetColors.graphiteGray,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                skill['name'],
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: FlownetColors.pureWhite,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Chip(
                                label: Text(
                                  skill['category'],
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: FlownetColors.crimsonRed.withAlpha(51),
                                labelStyle: const TextStyle(color: FlownetColors.crimsonRed),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Skill Level Progress
                          Text(
                            'Skill Level: ${skill['level']}%',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: FlownetColors.coolGray,
                                ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: skill['level'] / 100,
                            backgroundColor: FlownetColors.slate,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getProgressColor(skill['level']),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          Text(
                            'Last Assessed: ${skill['lastAssessed']}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: FlownetColors.coolGray,
                                ),
                          ),
                          const SizedBox(height: 12),
                          
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    final name = skill['name'] as String;
                                    _assessSkill(name);
                                    // ignore: deprecated_member_use
                                    Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => _AssessmentRunner(skillName: name),
                                    ),);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: FlownetColors.crimsonRed,
                                    foregroundColor: FlownetColors.pureWhite,
                                  ),
                                  child: const Text('Assess Now'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.visibility),
                                onPressed: () {
                                  _viewSkillDetails(skill['name']);
                                },
                                color: FlownetColors.coolGray,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Quick Assessment Button
            ElevatedButton(
              onPressed: () {
                _startQuickAssessment();
                // ignore: deprecated_member_use
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const _AssessmentRunner(skillName: 'Quick Assessment'),
                ),);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FlownetColors.amberOrange,
                foregroundColor: FlownetColors.charcoalBlack,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                'Start Quick Assessment',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getProgressColor(int level) {
    if (level >= 80) return Colors.green;
    if (level >= 60) return Colors.orange;
    return Colors.red;
  }
  
  void _assessSkill(String skillName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting assessment for $skillName')),
    );
  }
  
  void _viewSkillDetails(String skillName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing details for $skillName')),
    );
  }
  
  void _startQuickAssessment() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting quick skill assessment')),
    );
  }

}

class _AssessmentRunner extends StatelessWidget {
  final String skillName;
  const _AssessmentRunner({required this.skillName});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: FlownetColors.graphiteGray,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Assessment: $skillName',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: FlownetColors.pureWhite,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Loading $skillName questions')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlownetColors.electricBlue,
                    foregroundColor: FlownetColors.pureWhite,
                  ),
                  child: const Text('Start'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Includes multiple-choice questions and practical tasks',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FlownetColors.coolGray,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}