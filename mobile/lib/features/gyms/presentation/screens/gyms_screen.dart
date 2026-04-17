import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/api_service.dart';

class GymsScreen extends ConsumerStatefulWidget {
  const GymsScreen({super.key});

  @override
  ConsumerState<GymsScreen> createState() => _GymsScreenState();
}

class _GymsScreenState extends ConsumerState<GymsScreen> with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  final MapController _mapController = MapController();
  bool _isLoading = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _gyms = [];
  double? _lat;
  double? _lon;
  List<Marker> _cachedMarkers = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack('Location services disabled. Using default.');
        _useFallbackLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _snack('Location denied. Using default location.');
        _useFallbackLocation();
        return;
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Position? position;
        try {
          // Attempt a highly accurate GPS lock first (20 seconds max)
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 20),
            ),
          );
        } catch (_) {
          try {
            // If GPS times out (e.g., indoors), fallback to a medium-accuracy network trace
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 10),
              ),
            );
          } catch (_) {
            // If all live attempts fail, fetch last known cache or use fallback
            position = await Geolocator.getLastKnownPosition();
            if (position == null) {
              _useFallbackLocation();
              return;
            }
          }
        }

        _lat = position.latitude;
        _lon = position.longitude;
        await _fetchGyms(_lat!, _lon!);
        
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              _mapController.move(LatLng(_lat!, _lon!), 14);
            } catch (_) {}
          });
        }
      } else {
        _useFallbackLocation();
      }
    } catch (e) {
      _snack('Could not get location. Using default.');
      _useFallbackLocation();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _useFallbackLocation() async {
    _lat = 13.6285;
    _lon = 79.4192;
    await _fetchGyms(_lat!, _lon!);
    if (mounted) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
         try {
           _mapController.move(LatLng(_lat!, _lon!), 13);
         } catch (_) {}
       });
    }
  }

  Future<void> _fetchGyms(double lat, double lon, {String? query}) async {
    setState(() => _isLoading = true);
    
    final results = await ApiService.getNearbyGyms(lat, lon, query: query);

    if (mounted) {
      setState(() {
        _gyms = results;
        _lat = lat;
        _lon = lon;
        _isLoading = false;
      });
      _updateMarkers();
    }
  }

  void _updateMarkers() {
    if (_lat == null || _lon == null) return;

    final markerStyle = GoogleFonts.outfit(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w900,
    );

    _cachedMarkers = [
      Marker(
        point: LatLng(_lat!, _lon!),
        width: 50,
        height: 50,
        child: _buildUserPulseMarker(),
      ),
      ..._gyms.map((gym) => Marker(
        point: LatLng(gym['lat'], gym['lon']),
        width: 80,
        height: 60,
        child: _buildGymMarker(gym, markerStyle),
      )),
    ];

    if (mounted) setState(() {});
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _snack('Enter a city or area name');
      return;
    }
    
    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();
    
    try {
      final coords = await ApiService.geocodeLocation(query);
      
      if (coords != null) {
        final newLat = coords['lat']!;
        final newLon = coords['lon']!;
        
        await _fetchGyms(newLat, newLon);
        
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              _mapController.move(LatLng(newLat, newLon), 14);
            } catch (_) {}
          });
          _snack(_gyms.isNotEmpty 
              ? 'Found ${_gyms.length} gyms in $query' 
              : 'No gyms found in $query');
        }
      } else {
        _snack('Could not find "$query". Try another name.');
      }
    } catch (e) {
      _snack('Search failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _openDirections(Map<String, dynamic> gym) async {
    final gymLat = gym['lat'];
    final gymLon = gym['lon'];
    
    // Open Google Maps with directions
    final String googleMapsUrl;
    
    if (_lat != null && _lon != null) {
      // Open with current location as start
      googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&origin=$_lat,$_lon&destination=$gymLat,$gymLon&travelmode=driving';
    } else {
      // Open just the destination
      googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$gymLat,$gymLon';
    }
    
    final Uri url = Uri.parse(googleMapsUrl);
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _snack('Could not open Google Maps');
      }
    } catch (e) {
      _snack('Error opening maps: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)), 
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMapSection()),
          
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSearchBar(),
                ],
              ),
            ),
          ),

          _buildDraggableList(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 5))
                ],
              ),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, child) {
                  return TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _searchLocation(),
                    textInputAction: TextInputAction.search,
                    style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search city or area...',
                      prefixIcon: const Icon(Icons.location_on_rounded, color: AppColors.primary),
                      suffixIcon: value.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20, color: AppColors.textMuted), 
                              onPressed: () {
                                _searchController.clear();
                                // FocusScope.of(context).unfocus(); optional
                              }
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isSearching ? null : _searchLocation,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: _isSearching ? Colors.grey : AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
                ],
              ),
              child: _isSearching
                  ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isLoading ? null : _initLocation,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
                ],
              ),
              child: _isLoading
                  ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    if (_lat == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Getting your location...'),
          ],
        ),
      );
    }
    
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(_lat!, _lon!),
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.gymai.flutter',
        ),
        MarkerLayer(markers: _cachedMarkers),
      ],
    );
  }

  Widget _buildDraggableList() {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.18,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      _gyms.isEmpty ? 'No gyms found' : '${_gyms.length} gyms found',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    if (_isLoading)
                      const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildGymListSection(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGymListSection(ScrollController? scrollController) {
    if (_gyms.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('No gyms in this area', style: GoogleFonts.outfit(color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text('Try searching another location', style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      itemCount: _gyms.length,
      itemBuilder: (context, index) {
        final gym = _gyms[index];
        return _buildGymCard(gym);
      },
    );
  }

  Widget _buildGymCard(Map<String, dynamic> gym) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDirections(gym),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                _buildGymImage(gym['image']),
                const SizedBox(width: 16),
                Expanded(child: _buildGymInfo(gym)),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_rounded, color: AppColors.primary, size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserPulseMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(seconds: 2),
          builder: (context, value, child) {
            return Container(
              width: 50 * value,
              height: 50 * value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue.withValues(alpha: 1 - value), width: 1.5),
              ),
            );
          },
        ),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.5), blurRadius: 10)],
          ),
        ),
      ],
    );
  }

  Widget _buildGymMarker(Map<String, dynamic> gym, TextStyle style) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Text(
            gym['name'].toString().split(' ').first,
            maxLines: 1,
            style: style,
          ),
        ),
        const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 24),
      ],
    );
  }

  Widget _buildGymImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 32),
        ),
      ),
    );
  }

  Widget _buildGymInfo(Map<String, dynamic> gym) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(gym['name'], 
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(gym['address'], maxLines: 2, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 18),
            const SizedBox(width: 4),
            Text(gym['rating'] ?? '4.0', 
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(width: 10),
            Text('Tap for directions', 
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
