import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../shared/widgets/app_background.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/utils/auth_utils.dart';
import '../../../../shared/providers/notifications_provider.dart';

class CalculatorsScreen extends ConsumerStatefulWidget {
  const CalculatorsScreen({super.key});
  @override
  ConsumerState<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends ConsumerState<CalculatorsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabs;
  final _bfHeight = TextEditingController();
  final _bfWeight = TextEditingController();
  final _bfWaist = TextEditingController();
  String _gender = 'male';
  Map<String, dynamic>? _bfResult;

  final _dietHeight = TextEditingController();
  final _dietWeight = TextEditingController();
  final _dietTargetWeight = TextEditingController();
  final _dietAge = TextEditingController();
  final _proteinPerScoop = TextEditingController();
  final _proteinScoops = TextEditingController();
  String _dietGender = 'male';
  String _dietGoal = 'Fat Loss';
  bool _includeWhey = false;
  double _activityLevel = 1.55;
  Map<String, dynamic>? _dietResult;
  String? _mealPlanResponse;
  bool _dietLoading = false;
  bool _showDietInput = true;

  final _foodInput = TextEditingController();
  final _foodQty = TextEditingController();
  String _foodUnit = 'g';
  List<Map<String, dynamic>> _addedFoods = [];
  Map<String, dynamic>? _nutritionResult;

  static const _nutritionDb = {
    // Protein Sources
    'chicken breast': {'cal': 165, 'p': 31.0, 'c': 0.0, 'f': 3.6, 'iron': 1.0, 'calcium': 15, 'fiber': 0, 'type': 'Protein', 'isVeg': false},
    'egg whites': {'cal': 52, 'p': 11.0, 'c': 0.7, 'f': 0.2, 'iron': 0.0, 'calcium': 7, 'fiber': 0, 'type': 'Protein', 'isVeg': false},
    'egg (whole)': {'cal': 155, 'p': 13.0, 'c': 1.1, 'f': 11.0, 'iron': 1.2, 'calcium': 50, 'fiber': 0, 'type': 'Protein/Fat', 'isVeg': false},
    'paneer (low fat)': {'cal': 180, 'p': 20.0, 'c': 4.0, 'f': 10.0, 'iron': 0.1, 'calcium': 480, 'fiber': 0, 'type': 'Protein/Fat', 'isVeg': true},
    'salmon': {'cal': 208, 'p': 20.0, 'c': 0.0, 'f': 13.0, 'iron': 0.3, 'calcium': 9, 'fiber': 0, 'type': 'Protein/Fat', 'isVeg': false},
    'tofu': {'cal': 76, 'p': 8.0, 'c': 1.9, 'f': 4.8, 'iron': 5.4, 'calcium': 350, 'fiber': 1, 'type': 'Protein', 'isVeg': true},
    'whey protein': {'cal': 400, 'p': 80.0, 'c': 5.0, 'f': 4.0, 'iron': 0.5, 'calcium': 500, 'fiber': 0, 'type': 'Protein', 'isVeg': true},
    
    // Carb Sources
    'oats': {'cal': 389, 'p': 16.9, 'c': 66.0, 'f': 6.9, 'iron': 4.7, 'calcium': 54, 'fiber': 10, 'type': 'Carb', 'isVeg': true},
    'rice (brown)': {'cal': 111, 'p': 2.6, 'c': 23.0, 'f': 0.9, 'iron': 0.4, 'calcium': 10, 'fiber': 1.8, 'type': 'Carb', 'isVeg': true},
    'sweet potato': {'cal': 86, 'p': 1.6, 'c': 20.0, 'f': 0.1, 'iron': 0.6, 'calcium': 30, 'fiber': 3, 'type': 'Carb', 'isVeg': true},
    'quinoa': {'cal': 120, 'p': 4.4, 'c': 21.0, 'f': 1.9, 'iron': 1.5, 'calcium': 17, 'fiber': 2.8, 'type': 'Carb', 'isVeg': true},
    'banana': {'cal': 89, 'p': 1.1, 'c': 23.0, 'f': 0.3, 'iron': 0.3, 'calcium': 5, 'fiber': 2.6, 'type': 'Carb', 'isVeg': true},
    
    // Fat Sources
    'almonds': {'cal': 579, 'p': 21.0, 'c': 22.0, 'f': 50.0, 'iron': 3.7, 'calcium': 264, 'fiber': 12, 'type': 'Fat', 'isVeg': true},
    'peanut butter': {'cal': 588, 'p': 25.0, 'c': 20.0, 'f': 50.0, 'iron': 1.9, 'calcium': 43, 'fiber': 6, 'type': 'Fat', 'isVeg': true},
    'walnuts': {'cal': 654, 'p': 15.0, 'c': 14.0, 'f': 65.0, 'iron': 2.9, 'calcium': 98, 'fiber': 6.7, 'type': 'Fat', 'isVeg': true},
    'avocado': {'cal': 160, 'p': 2.0, 'c': 8.5, 'f': 15.0, 'iron': 0.6, 'calcium': 12, 'fiber': 6.7, 'type': 'Fat', 'isVeg': true},
    
    // Others
    'spinach': {'cal': 23, 'p': 2.9, 'c': 3.6, 'f': 0.4, 'iron': 2.7, 'calcium': 99, 'fiber': 2.2, 'type': 'Veggie', 'isVeg': true},
    'broccoli': {'cal': 34, 'p': 2.8, 'c': 6.6, 'f': 0.4, 'iron': 0.7, 'calcium': 47, 'fiber': 2.6, 'type': 'Veggie', 'isVeg': true},
    'curd / yogurt': {'cal': 63, 'p': 5.0, 'c': 7.0, 'f': 1.5, 'iron': 0.1, 'calcium': 121, 'fiber': 0, 'type': 'Others', 'isVeg': true},
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final p = StorageService.getProfile();
    if (p['height'] != null) {
      _bfHeight.text = '${p['height']}';
      _dietHeight.text = '${p['height']}';
    }
    if (p['weight'] != null) {
      _bfWeight.text = '${p['weight']}';
      _dietWeight.text = '${p['weight']}';
    }
    if (p['age'] != null) _dietAge.text = '${p['age']}';
    if (p['gender'] != null) {
      _gender = p['gender'].toString().toLowerCase();
      _dietGender = _gender;
    }
    if (p['target_weight'] != null) {
      _dietTargetWeight.text = '${p['target_weight']}';
    }
    if (p['goal'] != null) _dietGoal = p['goal'];
    if (p['activity_level'] != null) {
      final alStr = p['activity_level'].toString().toLowerCase();
      if (alStr.contains('sed')) _activityLevel = 1.2;
      else if (alStr.contains('light')) _activityLevel = 1.375;
      else if (alStr.contains('mod')) _activityLevel = 1.55;
      else if (alStr.contains('very')) _activityLevel = 1.725;
      else if (alStr.contains('extra')) _activityLevel = 1.9;
    }

    final savedMacro = StorageService.getMacroPlan();
    final savedMeal = StorageService.getMealPlanResponse();
    
    if (savedMacro.isNotEmpty && savedMacro.containsKey('calories')) {
      _dietResult = savedMacro;
      _showDietInput = false;
        if (savedMeal != null && savedMeal.trim().isNotEmpty) {
        _mealPlanResponse = savedMeal;
        _showDietInput = false;
      }
    }

    if (_showDietInput == false) _tabs.index = 1;
  }

  @override
  bool get wantKeepAlive => true;

  void _calcBodyFat() {
    if (AuthUtils.requireLogin(context: context, ref: ref)) return;
    final h = double.tryParse(_bfHeight.text) ?? 0;
    final w = double.tryParse(_bfWeight.text) ?? 0;
    final waist = double.tryParse(_bfWaist.text) ?? 0;
    if (h == 0 || w == 0 || waist == 0) {
      _snack('Please fill in all fields');
      return;
    }
    final totalInches = h / 2.54;
    final ratio = waist / totalInches;
    final heightM = totalInches * 0.0254;
    final bmi = w / (heightM * heightM);

    String bfRange, recommend, reason;
    if (_gender == 'male') {
      if (ratio < 0.43) {
        bfRange = '8–12%'; recommend = 'Aggressive Cut'; reason = 'Low body fat but focused on intensive definition.';
      } else if (ratio < 0.52) {
        bfRange = '15–20%'; recommend = 'Recomp'; reason = 'Healthy mid-range. Focus on building muscle.';
      } else if (ratio < 0.58) {
        bfRange = '23–26%+'; recommend = 'Aggressive Cut'; reason = 'Higher body fat detected. Intensive deficit suggested.';
      } else {
        bfRange = '30%+'; recommend = 'Medical Action'; reason = 'High obesity risk detected.';
      }
    } else {
      if (ratio < 0.45) {
        bfRange = '15–18%'; recommend = 'Normal'; reason = 'Healthy athletic range.';
      } else if (ratio < 0.55) {
        bfRange = '22–28%'; recommend = 'Tone'; reason = 'Standard healthy range.';
      } else {
        bfRange = '32%+'; recommend = 'Weight Loss'; reason = 'Fat storage above optimal levels.';
      }
    }

    final idealBMI = 22.5;
    final maintWeight = (idealBMI * heightM * heightM).toStringAsFixed(1);
    final fatLossTarget = (w * 0.9).toStringAsFixed(1);

    setState(() {
      _bfResult = {
        'bfRange': bfRange,
        'bmi': bmi.toStringAsFixed(1),
        'recommend': recommend,
        'reason': reason,
        'maintWeight': '$maintWeight kg',
        'fatLossTarget': '$fatLossTarget kg',
      };
    });
  }

  Future<void> _calcDiet() async {
    if (AuthUtils.requireLogin(context: context, ref: ref)) return;
    final w = double.tryParse(_dietWeight.text) ?? 0;
    final tw = double.tryParse(_dietTargetWeight.text) ?? 0;
    final a = double.tryParse(_dietAge.text) ?? 0;
    final h = double.tryParse(_dietHeight.text) ?? 0;
    if (w == 0 || tw == 0 || a == 0 || h == 0 || (_includeWhey && (_proteinPerScoop.text.isEmpty || _proteinScoops.text.isEmpty))) {
      _snack('Please fill all required fields');
      return;
    }

    setState(() {
      _dietLoading = true;
    });

    try {
      double bmr = (10 * w) + (6.25 * h) - (5 * a);
      bmr += (_gender == 'male') ? 5 : -161;
      
      // Calculate Maintenance Calories (TDEE)
      double tdee = bmr * _activityLevel;
      if (tdee < bmr) tdee = bmr * 1.2; // Absolute safety floor

      double targetCals = tdee;

      // Map goals to calorie offsets
      if (_dietGoal == 'Fat Loss') targetCals = tdee - 500;
      else if (_dietGoal == 'Aggressive Cut') targetCals = tdee - 850;
      else if (_dietGoal == 'Lean Bulk') targetCals = tdee + 250;
      else if (_dietGoal == 'Aggressive Bulk') targetCals = tdee + 500;
      
      // Ensure we don't starve the user
      if (targetCals < bmr * 0.8) targetCals = bmr * 0.8;

      // 1.5g Protein per kg, 0.8g Fat per kg as per formula
      final totalProtein = (w * 1.5).round();
      final totalFats = (w * 0.8).round();
      
      final proteinCals = totalProtein * 4;
      final fatCals = totalFats * 9;
      
      // Carbs = (Total - (P + F)) / 4 (Ensure non-negative)
      int totalCarbs = ((targetCals - proteinCals - fatCals) / 4).round();
      if (totalCarbs < 0) totalCarbs = 0;

      final planData = {
        'calories': targetCals.round(),
        'protein': totalProtein,
        'carbs': totalCarbs,
        'fat': totalFats,
        'goal': _dietGoal,
      };

      // Calculate Water Goal: 35ml per kg
      final waterGoal = (w * 35).round();
      StorageService.setItem('water_goal', waterGoal);

      final profile = Map<String, dynamic>.from(StorageService.getProfile());
      profile['weight'] = w;
      profile['height'] = h;
      profile['age'] = a;
      profile['target_weight'] = tw;
      profile['gender'] = _dietGender; // Ensure profile has latest selected (though taken from profile)
      
      final aiResult = await ApiService.generateDiet(
        profile, 
        targetCals.round(), 
        {'p': totalProtein, 'c': totalCarbs, 'f': totalFats},
        dietType: 'Standard',
        includeWhey: _includeWhey,
        targetWeight: tw,
      );

      if (aiResult['plan'] == null || aiResult['plan'].toString().isEmpty) {
        // Fallback to Inbuilt Plan if Server Times out
        final fallbackPlan = _generateInbuiltPlan(profile, targetCals, totalProtein, totalCarbs, totalFats);
        await StorageService.saveMacroPlan(planData);
        await StorageService.saveMealPlanResponse(fallbackPlan);
        setState(() {
          _dietResult = planData;
          _mealPlanResponse = fallbackPlan;
          _dietLoading = false;
          _showDietInput = false;
        });
        _snack('AI was busy, used Premium Inbuilt Plan instead!');
        return;
      }

      await StorageService.saveMacroPlan(planData);
      await StorageService.saveMealPlanResponse(aiResult['plan']);
      await ref.read(authProvider.notifier).syncUserData();
      
      setState(() {
        _dietResult = planData;
        _mealPlanResponse = aiResult['plan'];
        _dietLoading = false;
        _showDietInput = false;
      });

      ref.read(notificationsProvider.notifier).addNotification(
        title: 'Diet Architect',
        description: 'Your premium 7-day meal plan is ready!',
        icon: Icons.restaurant_rounded,
        color: Colors.green,
      );
      _snack('Premium Diet Plan Generated!');
    } catch (e) {
      setState(() => _dietLoading = false);
      _snack('Generation failed. Please try again.');
    }
  }

  void _addFood() {
    if (AuthUtils.requireLogin(context: context, ref: ref)) return;
    final name = _foodInput.text.trim().toLowerCase();
    final qty = double.tryParse(_foodQty.text) ?? 0;
    if (name.isEmpty || qty <= 0) { _snack('Enter food name and quantity'); return; }

    Map<String, dynamic>? data;
    _nutritionDb.forEach((key, val) {
      if (key.contains(name) || name.contains(key)) data = Map<String, dynamic>.from(val);
    });
    
    // Smart Fallback
    data ??= {'cal': 100.0, 'p': 2.0, 'c': 15.0, 'f': 2.0, 'iron': 0.5, 'calcium': 10, 'fiber': 1, 'type': 'Unclassified'};

    double factor = 1.0;
    if (_foodUnit == 'pcs') {
      // Smart weight mapping per piece
      if (name.contains('egg')) factor = 50; // 50g per egg
      else if (name.contains('banana')) factor = 110;
      else if (name.contains('apple')) factor = 150;
      else if (name.contains('scoop') || name.contains('whey')) factor = 30;
      else factor = 100; // Default 100g for others
    } else if (_foodUnit == 'cup') {
      factor = 240; // Standard 240ml/g
    }
    final mult = (qty * factor) / 100;

    setState(() {
      _addedFoods.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'name': name,
        'display': '$qty $_foodUnit',
        'type': data!['type'],
        'cal': ((data!['cal'] as num) * mult).round(),
        'p': (((data!['p'] as num) * mult) * 10).round() / 10,
        'c': (((data!['c'] as num) * mult) * 10).round() / 10,
        'f': (((data!['f'] as num) * mult) * 10).round() / 10,
        'iron': (((data!['iron'] as num) * mult) * 10).round() / 10,
        'calcium': ((data!['calcium'] as num) * mult).round(),
        'fiber': (((data!['fiber'] as num?) ?? 0) * mult).round(),
      });
    });
    _foodInput.clear();
    _foodQty.clear();
  }

  String _generateInbuiltPlan(Map profile, double cals, int p, int c, int f) {
    String s = "--- AI INBUILT FALLBACK: 7-DAY ELITE PLAN ---\n";
    s += "Goal: $_dietGoal | Target: ${cals.round()} kcal\n\n";
    
    final days = ["DAY 1", "DAY 2", "DAY 3", "DAY 4", "DAY 5", "DAY 6", "DAY 7"];
    
    final vegMeals = [
      {"b": "Oats with Peanut Butter & Banana", "l": "Paneer Bhurji with 2 Rotis & Salad", "s": "Greek Yogurt with Almonds", "d": "Dal Tadka with Brown Rice & Veggies"},
      {"b": "Moong Dal Chilla with Mint Chutney", "l": "Chickpea (Chana) Salad with Quinoa", "s": "Roasted Makhana (Foxnuts)", "d": "Palak Paneer with 1 Bajra Roti"},
      {"b": "Tofu Scramble with Whole Wheat Toast", "l": "Mixed Vegetable Khichdi with Curd", "s": "1 Apple + 10 Walnuts", "d": "Soya Chunks Stir-fry with Brown Rice"},
      {"b": "Multi-grain Thalipeeth with Yogurt", "l": "Rajma (Red Kidney Beans) with Steamed Rice", "s": "Boiled Chickpeas (Chat)", "d": "Stuffed Capsicum with Cottage Cheese"},
      {"b": "Smoothie Bowl: Spinach, Banana, Protein", "l": "Lentil Soup with Roasted Veggies", "s": "Sprouted Moong Salad", "d": "Vegetable Dalia (Broken Wheat)"},
      {"b": "Upma with plenty of Mixed Veggies", "l": "Mushroom & Green Pea Curry + 2 Rotis", "s": "Pumpkin Seeds & Sunflower Seeds", "d": "Lauki (Bottle Gourd) Kofta with Quinoa"},
      {"b": "Peanut Butter Toast with Sliced Apple", "l": "Black Eyed Peas (Lobhia) with Brown Rice", "s": "Fruit Salad with Chia Seeds", "d": "Grilled Tofu with Sautéed Broccoli"},
    ];

    final nonVegMeals = [
      {"b": "4 Egg Whites + 1 Whole Egg & Oats", "l": "Grilled Chicken (200g) with Sweet Potato", "s": "Protein Shake / Boiled Eggs", "d": "Soya Chunks or Chicken with 1 Roti"},
      {"b": "3 Egg Omelette with Spinach & Mushrooms", "l": "Baked Fish (200g) with Brown Rice & Asparagus", "s": "Handful of Salted Almonds", "d": "Turkey or Lean Beef Mince with Salad"},
      {"b": "Chicken Sausage with Scrambled Eggs", "l": "Tuna Salad with Olive Oil & Lemon", "s": "Greek Yogurt + 1 Banana", "d": "Grilled Chicken Tikka with Steamed Veggies"},
      {"b": "Pancakes Made with Oats & Egg Whites", "l": "Lean Mutton Curry (Portion Ctrl) with 1 Roti", "s": "2 Hard Boiled Eggs", "d": "Grilled Prawns with Quinoa & Peppers"},
      {"b": "Smoothie: Whey Protein, Oats, Blueberries", "l": "Chicken Breast with Sautéed Zucchini", "s": "Peanut Butter & Celery Sticks", "d": "White Fish in Tomato Garlic Sauce + Veg"},
      {"b": "Boiled Eggs with Avocado Toast", "l": "Stir-fried Chicken with Bell Peppers & Rice", "s": "Cottage Cheese with Pineapple", "d": "Lemon Herb Chicken with Cauliflower Rice"},
      {"b": "Turkey Bacon with 3 Egg Whites & Toast", "l": "Grilled Salmon with Steamed Broccoli", "s": "1 Pear + String Cheese", "d": "Slow Cooked Chicken Stew with Carrots"},
    ];

    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final m = nonVegMeals[i]; // Defaulting to one variety as we removed choice
      s += "--- $day ---\n";
      s += "Breakfast: ${m['b']}\n";
      s += "Lunch: ${m['l']}\n";
      s += "Snack: ${m['s']}\n";
      s += "Dinner: ${m['d']}\n";
      s += "Drink 4.2 Liters of Water minimum!\n\n";
    }
    return s;
  }

  void _calcNutrition() {
    if (AuthUtils.requireLogin(context: context, ref: ref)) return;
    if (_addedFoods.isEmpty) { _snack('Add food items first'); return; }
    double cal = 0, p = 0, c = 0, f = 0, iron = 0, calcium = 0, fiber = 0;
    for (final item in _addedFoods) {
      cal += item['cal'];
      p += item['p'];
      c += item['c'];
      f += item['f'];
      iron += item['iron'] ?? 0;
      calcium += item['calcium'] ?? 0;
      fiber += item['fiber'] ?? 0;
    }
    setState(() => _nutritionResult = {
      'cal': cal.round(), 
      'p': p.toStringAsFixed(1),
      'c': c.toStringAsFixed(1), 
      'f': f.toStringAsFixed(1),
      'iron': iron.toStringAsFixed(1),
      'calcium': calcium.round(),
      'fiber': fiber.round(),
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)), 
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ));
  }

  Future<void> _downloadPdf() async {
    if (AuthUtils.requireLogin(context: context, ref: ref)) return;
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (pw.Context context) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Header(level: 0, child: pw.Text('FITCOACH AI - PREMIUM REPORT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 20),
        if (_dietResult != null) ...[
          pw.Text('DIET BLUEPRINT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text('Goal: ${_dietResult!['goal']}'),
          pw.Text('Target: ${_dietResult!['calories']} kcal | P: ${_dietResult!['protein']}g | C: ${_dietResult!['carbs']}g | F: ${_dietResult!['fat']}g'),
          pw.SizedBox(height: 10),
          if (_mealPlanResponse != null) pw.Text(_mealPlanResponse!, style: const pw.TextStyle(fontSize: 10)),
        ],
      ]);
    }));
    final bytes = await pdf.save();
    
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        // Try to get the public downloads directory on Android
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final fileName = 'FitCoachAI_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir!.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      _snack('PDF Saved To: ${dir.path}');
    } catch (e) {
      // Fallback if direct file access fails due to permissions
      await Printing.sharePdf(bytes: bytes, filename: 'FitCoachAI_Premium_Plan.pdf');
      _snack('Saved via Share due to permission restriction');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 90,
        title: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Text('Health Tools', 
            style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 22)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 28),
              onPressed: _downloadPdf,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.bgSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabs,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
              unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 11),
              tabs: const [
                Tab(child: Center(child: Text('BODY FAT', textAlign: TextAlign.center))),
                Tab(child: Center(child: Text('DIET PLAN', textAlign: TextAlign.center))),
                Tab(child: Center(child: Text('NUTRITION', textAlign: TextAlign.center))),
              ],
            ),
          ),
        ),
      ),
      body: AppBackground(
        isInternal: true,
        child: SafeArea(
          bottom: false,
          child: TabBarView(
            controller: _tabs,
            children: [
              _bodyFatTab(),
              _dietPlanTab(),
              _nutritionTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bodyFatTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          _buildToolHeader('Composition Analyzer', 'Biometric tracking system'),
          const SizedBox(height: 12),
          _inputCard(
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: _modernField('Height (cm)', _bfHeight, Icons.height_rounded)),
                  const SizedBox(width: 16),
                  Expanded(child: _modernField('Weight (kg)', _bfWeight, Icons.monitor_weight_rounded)),
                ]),
                const SizedBox(height: 16),
                _modernField('Waist (inches)', _bfWaist, Icons.square_foot_rounded),
                const SizedBox(height: 24),
                _genderSelector(),
                const SizedBox(height: 32),
                _primaryBtn('CALCULATE NOW', _calcBodyFat),
              ],
            ),
          ),
          if (_bfResult != null) _buildBfResult(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildBfResult() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.cardBorder, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('BODY FAT ZONE', 
                    style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  Text(_bfResult!['bfRange'], 
                    style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.primary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(_bfResult!['recommend'].toUpperCase(), 
                  style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
          _resultRow('1. BMI Status', _bfResult!['bmi'], AppColors.textPrimary),
          _resultRow('2. Ideal Weight', _bfResult!['maintWeight'], AppColors.textPrimary),
          _resultRow('3. Cut Target', _bfResult!['fatLossTarget'], Colors.redAccent),
          const SizedBox(height: 16),
          Text(_bfResult!['reason'], 
            style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500, height: 1.5)),
        ],
      ),
    );
  }

  Widget _dietPlanTab() {
    final goals = ['Fat Loss', 'Body Recomposition', 'Aggressive Cut', 'Maintenance', 'Lean Bulk', 'Aggressive Bulk'];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          _buildToolHeader('Diet Architect', 'AI-generated precision macros'),
          const SizedBox(height: 12),
          if (_showDietInput)
            _inputCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: _modernField('Height', _dietHeight, Icons.straighten_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _modernField('Weight', _dietWeight, Icons.scale_rounded)),
                  ]),
                  const SizedBox(height: 16),
                  _modernField('Age', _dietAge, Icons.cake_rounded),
                  const SizedBox(height: 28),
                  Text('PRIMARY GOAL', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: goals.map((g) => ChoiceChip(
                      label: Text(g),
                      selected: _dietGoal == g,
                      onSelected: (s) => setState(() => _dietGoal = g),
                      selectedColor: AppColors.primary,
                      labelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: _dietGoal == g ? Colors.white : AppColors.textSecondary),
                      backgroundColor: AppColors.bgSoft,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    )).toList(),
                  ),
                  const SizedBox(height: 28),
                  Text('ACTIVITY LEVEL', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _activityChip('Sedentary', 1.2),
                      _activityChip('Light', 1.375),
                      _activityChip('Moderate', 1.55),
                      _activityChip('Active', 1.725),
                      _activityChip('Extreme', 1.9),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(children: [
                    Expanded(child: _modernField('Target Weight', _dietTargetWeight, Icons.track_changes_rounded)),
                  ]),
                  const SizedBox(height: 16),
                  _dietGenderSelector(),
                  const SizedBox(height: 32),
                  _primaryBtn(_dietLoading ? 'GENERATING...' : 'GENERATE AI PLAN', _dietLoading ? () {} : _calcDiet),
                ],
              ),
            ),
          if (!_showDietInput && _dietResult != null) _buildDietResult(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildDietResult() {
    return Column(
      children: [
        _buildResultCard(
          title: 'Macro Blueprint',
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TARGET CALORIES PER DAY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1)),
                  GestureDetector(
                    onTap: () => setState(() => _showDietInput = true),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${_dietResult!['calories']}', 
                    style: GoogleFonts.outfit(fontSize: 56, fontWeight: FontWeight.w900, color: AppColors.textPrimary, height: 1)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 8),
                    child: Text('KCAL', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _macroItem('1. P', '${_dietResult!['protein']}g', Colors.orange),
                  _macroItem('2. C', '${_dietResult!['carbs']}g', Colors.blue),
                  _macroItem('3. F', '${_dietResult!['fat']}g', Colors.teal),
                ],
              ),
            ],
          ),
        ),
        if (_mealPlanResponse != null) ...[
          const SizedBox(height: 24),
          _inputCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('7-DAY SCHEDULE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 12, letterSpacing: 1)),
                const SizedBox(height: 16),
                Text(_mealPlanResponse!, 
                  style: GoogleFonts.outfit(fontSize: 14, height: 1.6, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _nutritionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          _buildToolHeader('Nutrition Tracker', 'Calorie precision tool'),
          const SizedBox(height: 12),
          _inputCard(
            child: Column(
              children: [
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                    return _nutritionDb.keys.where((String option) {
                      return option.contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    _foodInput.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return _modernField('Food Item', controller, Icons.fastfood_rounded, focusNode: focusNode);
                  },
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _modernField('Quantity', _foodQty, Icons.scale_rounded)),
                  const SizedBox(width: 12),
                  _unitDropdown(),
                ]),
                const SizedBox(height: 24),
                _primaryBtn('ADD TO INVENTORY', _addFood),
              ],
            ),
          ),
          if (_addedFoods.isNotEmpty) ...[
            const SizedBox(height: 24),
            ..._addedFoods.map((f) => _foodListTile(f)),
            const SizedBox(height: 24),
            _primaryBtn('CALCULATE TOTALS', _calcNutrition),
          ],
          if (_nutritionResult != null) _buildNutritionResult(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildNutritionResult() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface, 
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('DAILY TOTALS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.primary, letterSpacing: 1.5)),
              const Icon(Icons.analytics_rounded, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 20),
          _tableRow('Item', 'Prote', 'Carbs', 'Fats', 'Cals', isHeader: true),
          const Divider(),
          ..._addedFoods.map((f) => _tableRow(
            f['name'].split(' ').first, 
            '${f['p']}g', '${f['c']}g', '${f['f']}g', '${f['cal']}'
          )),
          const Divider(thickness: 2),
          _tableRow('TOTAL', '${_nutritionResult!['p']}g', '${_nutritionResult!['c']}g', '${_nutritionResult!['f']}g', '${_nutritionResult!['cal']}'),
          const SizedBox(height: 24),
          Text('MICRONUTRIENTS & FIBER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _microTag('Iron: ${_nutritionResult!['iron']} mg'),
              _microTag('Calcium: ${_nutritionResult!['calcium']} mg'),
              _microTag('Fiber: ${_nutritionResult!['fiber']} g'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableRow(String c1, String c2, String c3, String c4, String c5, {bool isHeader = false}) {
    final style = GoogleFonts.outfit(
      fontSize: isHeader ? 11 : 13,
      fontWeight: isHeader ? FontWeight.w900 : FontWeight.w600,
      color: isHeader ? AppColors.textMuted : AppColors.textPrimary
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(c1.toUpperCase(), style: style, maxLines: 1)),
          Expanded(child: Text(c2, style: style, textAlign: TextAlign.center)),
          Expanded(child: Text(c3, style: style, textAlign: TextAlign.center)),
          Expanded(child: Text(c4, style: style, textAlign: TextAlign.center)),
          Expanded(child: Text(c5, style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _microTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.bgSoft, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
    );
  }

  Widget _dietGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('GENDER', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _typeBtn('♂️ MALE', _dietGender == 'male', () => setState(() => _dietGender = 'male'))),
            const SizedBox(width: 12),
            Expanded(child: _typeBtn('♀️ FEMALE', _dietGender == 'female', () => setState(() => _dietGender = 'female'))),
          ],
        ),
      ],
    );
  }

  Widget _buildToolHeader(String title, String sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.cardBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(sub, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _inputCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.cardBorder, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }

  Widget _modernField(String label, TextEditingController c, IconData icon, {TextInputType type = TextInputType.number, FocusNode? focusNode}) {
    return TextField(
      controller: c,
      keyboardType: type,
      focusNode: focusNode,
      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.bgSoft.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _primaryBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 4,
          shadowColor: AppColors.primary.withOpacity(0.4),
        ),
        child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
      ),
    );
  }

  Widget _genderSelector() {
    return Row(
      children: [
        Expanded(child: _typeBtn('♂️ MALE', _gender == 'male', () => setState(() => _gender = 'male'))),
        const SizedBox(width: 12),
        Expanded(child: _typeBtn('♀️ FEMALE', _gender == 'female', () => setState(() => _gender = 'female'))),
      ],
    );
  }

  Widget _typeBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.bgSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? AppColors.primary : AppColors.cardBorder, width: 2),
        ),
        child: Center(
          child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: active ? Colors.white : AppColors.textSecondary, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _resultRow(String l, String v, Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          Text(v, style: GoogleFonts.outfit(color: c, fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _macroItem(String l, String v, Color c) {
    return Column(
      children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.withOpacity(0.1), border: Border.all(color: c, width: 2)),
          child: Center(child: Text(v, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: c, fontSize: 14))),
        ),
        const SizedBox(height: 8),
        Text(l, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _whiteStat(String l, String v) {
    return Column(
      children: [
        Text(v, style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        Text(l.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _foodListTile(Map<String, dynamic> f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f['name'].toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Text(f['display'], style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12)),
          ]),
          Row(children: [
            Text('${f['cal']} kcal', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w900)),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20), onPressed: () => setState(() => _addedFoods.remove(f))),
          ]),
        ],
      ),
    );
  }

  Widget _unitDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.bgSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _foodUnit,
          onChanged: (v) => setState(() => _foodUnit = v!),
          items: ['g', 'pcs', 'cup'].map((u) => DropdownMenuItem(value: u, child: Text(u, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)))).toList(),
        ),
      ),
    );
  }

  Widget _activityChip(String l, double v) {
    final bool active = _activityLevel == v;
    return ChoiceChip(
      label: Text(l),
      selected: active,
      onSelected: (s) => setState(() => _activityLevel = v),
      selectedColor: AppColors.primary,
      labelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.textSecondary),
      backgroundColor: AppColors.bgSoft,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildResultCard({required String title, required Widget child}) {
    return _inputCard(child: child);
  }
}
