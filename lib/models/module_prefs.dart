library;

import 'package:shared_preferences/shared_preferences.dart';

class SeedPodModule {
  final String id;
  final String title;
  final String description;
  final String category;
  final String suggestedFrom;
  final bool isCore;

  const SeedPodModule({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.suggestedFrom = 'Birth',
    this.isCore = false,
  });
}

class ModulePrefs {
  final Set<String> _enabled;

  const ModulePrefs._(this._enabled);

  static const List<SeedPodModule> allModules = [
    // Core — always on
    SeedPodModule(
      id: 'feeding',
      title: 'Feeding',
      description: 'Breast, bottle, formula and solids with side and duration tracking.',
      category: 'core',
      isCore: true,
    ),
    SeedPodModule(
      id: 'sleep',
      title: 'Sleep',
      description: 'Sleep and wake times with session duration.',
      category: 'core',
      isCore: true,
    ),
    SeedPodModule(
      id: 'growth',
      title: 'Growth',
      description: 'Weight and height plotted against WHO percentile bands.',
      category: 'core',
      isCore: true,
    ),
    SeedPodModule(
      id: 'vaccines',
      title: 'Vaccines',
      description: 'ACT NIP schedule with interactive checkboxes and ACT-funded MenB.',
      category: 'core',
      isCore: true,
    ),
    SeedPodModule(
      id: 'milestone',
      title: 'Milestones',
      description: 'First smile, first steps, and any developmental moments.',
      category: 'core',
      isCore: true,
    ),
    // Daily Care
    SeedPodModule(
      id: 'nappy',
      title: 'Nappy Log',
      description: 'Track wet, dirty and mixed changes. Key for monitoring newborn hydration and feeding.',
      category: 'Daily Care',
    ),
    SeedPodModule(
      id: 'medication',
      title: 'Medication',
      description: 'Record medications, dosages and schedules — paracetamol, antibiotics, vitamin D.',
      category: 'Daily Care',
    ),
    SeedPodModule(
      id: 'appointment',
      title: 'Doctor Visits',
      description: 'Log GP, paediatrician and specialist visits with diagnoses and follow-ups.',
      category: 'Daily Care',
    ),
    SeedPodModule(
      id: 'health',
      title: 'Health & Symptoms',
      description: 'Record temperatures, illnesses and symptoms for chronic condition tracking.',
      category: 'Daily Care',
    ),
    // Development
    SeedPodModule(
      id: 'food',
      title: 'Food Introduction',
      description: 'Log first foods and reactions. Helpful from around 4 months.',
      category: 'Development',
      suggestedFrom: '4+ months',
    ),
    SeedPodModule(
      id: 'development',
      title: 'Development Checklist',
      description: 'Structured screening based on Ages & Stages Questionnaires (ASQ) per age group.',
      category: 'Development',
    ),
    SeedPodModule(
      id: 'teeth',
      title: 'Baby Teeth',
      description: 'Record each tooth eruption date. First tooth typically around 4–6 months.',
      category: 'Development',
      suggestedFrom: '4+ months',
    ),
    SeedPodModule(
      id: 'sleep_training',
      title: 'Sleep Training',
      description: 'Track your chosen method and nightly progress.',
      category: 'Development',
    ),
    // Life Admin
    SeedPodModule(
      id: 'childcare',
      title: 'Childcare & Schools',
      description: 'Waitlist tracker for childcare and schools. Canberra queues can start before birth.',
      category: 'Life Admin',
    ),
    SeedPodModule(
      id: 'benefits',
      title: 'Government Benefits',
      description: 'Track CCS, Family Tax Benefit and Parenting Payment applications.',
      category: 'Life Admin',
    ),
    SeedPodModule(
      id: 'birth_admin',
      title: 'Birth Admin',
      description: 'Checklist for birth certificate, Medicare, myGov, passport and Centrelink.',
      category: 'Life Admin',
    ),
    SeedPodModule(
      id: 'contacts',
      title: 'Contacts & Carers',
      description: 'Authorised carers, emergency contacts and healthcare providers.',
      category: 'Life Admin',
    ),
    // Memories
    SeedPodModule(
      id: 'memory',
      title: 'Memories & Journal',
      description: 'Free-form journal entries and photo links stored privately in your Solid POD.',
      category: 'Memories',
    ),
    SeedPodModule(
      id: 'environment',
      title: 'Environment',
      description: 'Log room temperature, humidity and air quality.',
      category: 'Memories',
    ),
  ];

  static const Set<String> _coreIds = {
    'feeding', 'sleep', 'growth', 'vaccines', 'milestone',
  };

  static const Set<String> _defaultEnabled = {
    'nappy', 'childcare', 'birth_admin', 'health',
  };

  static ModulePrefs get defaults => ModulePrefs._(Set<String>.from(_defaultEnabled));

  bool isEnabled(String id) => _coreIds.contains(id) || _enabled.contains(id);

  ModulePrefs toggle(String id) {
    if (_coreIds.contains(id)) return this;
    final next = Set<String>.from(_enabled);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    return ModulePrefs._(next);
  }

  static Future<ModulePrefs> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('module_enabled');
    if (saved == null) return defaults;
    return ModulePrefs._(Set<String>.from(saved));
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('module_enabled', _enabled.toList());
  }
}
