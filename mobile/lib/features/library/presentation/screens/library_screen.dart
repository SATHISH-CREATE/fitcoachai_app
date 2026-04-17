import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/exercise_data_service.dart';
import '../../../../shared/widgets/app_background.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Category> _categories = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await ExerciseDataService.loadCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
        _loading = false;
      });
    }
  }

  List<Category> get _filteredCategories {
    if (_searchQuery.isEmpty && _selectedCategory == 'All') return _categories;
    
    return _categories.where((cat) {
      final matchesSearch = cat.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          cat.allExercises.any((ex) => ex.name.toLowerCase().contains(_searchQuery.toLowerCase()));
      
      final matchesCategory = _selectedCategory == 'All' || cat.name == _selectedCategory;
      
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        useBlobs: true,
        isInternal: true,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModernHeader(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _buildExerciseGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DISCOVER', 
                    style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  Text(
                    'Exercise Library',
                    style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary, height: 1.1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1, end: 0);
  }



  Widget _buildExerciseGrid() {
    final filtered = _filteredCategories;
    
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
             const SizedBox(height: 16),
             Text('No results for "$_searchQuery"', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final cat = filtered[index];
        return _ModernLibraryCard(
          category: cat,
          index: index,
          onTap: () => context.push('/exercises?category=${cat.name}'),
        ).animate().fadeIn(delay: (index * 50).ms).scale(begin: const Offset(0.9, 0.9));
      },
    );
  }
}

class _ModernLibraryCard extends StatelessWidget {
  final Category category;
  final int index;
  final VoidCallback onTap;

  const _ModernLibraryCard({required this.category, required this.index, required this.onTap});

  String get _imageUrl {
    switch (category.name) {
      case 'Chest': return 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400';
      case 'Back': return 'https://images.unsplash.com/photo-1605296867304-46d5465a13f1?w=400';
      case 'Shoulders': return 'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?w=400';
      case 'Legs': return 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=400';
      case 'Arms': return 'https://images.unsplash.com/photo-1581009146145-b5ef050c149a?w=400';
      case 'Core': return 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400';
      default: return 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(_imageUrl, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${category.allExercises.length}', 
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 8),
                  Text(category.name, 
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  Text('Level Up', 
                    style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
