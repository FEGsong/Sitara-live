import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int selectedIndex = 0;

  final List<_StoreCategory> categories = const [
    _StoreCategory(
      title: 'Frames',
      icon: Icons.circle_outlined,
    ),
    _StoreCategory(
      title: 'VIP',
      icon: Icons.workspace_premium,
    ),
    _StoreCategory(
      title: 'Vehicles',
      icon: Icons.directions_car,
    ),
    _StoreCategory(
      title: 'Chat Bubble',
      icon: Icons.chat_bubble,
    ),
    _StoreCategory(
      title: 'Room Lock',
      icon: Icons.lock,
    ),
    _StoreCategory(
      title: 'Theme',
      icon: Icons.public,
    ),
    _StoreCategory(
      title: 'Personal Page',
      icon: Icons.badge,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = categories[selectedIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Store',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: CustomPaint(
              painter: _StoreBackgroundPainter(),
            ),
          ),

          Column(
            children: [
              const SizedBox(height: 18),

              // CATEGORY LIST
              SizedBox(
                height: 145,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final item = categories[index];
                    final isSelected = selectedIndex == index;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedIndex = index;
                        });
                      },
                      child: Container(
                        width: 112,
                        margin: const EdgeInsets.only(right: 14),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 108,
                              height: 96,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.black
                                    : const Color(0xFF5B5B5B),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.gold
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.gold.withOpacity(.25),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: _categoryIcon(
                                  item,
                                  isSelected,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFFE8D7A2),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 55),

              // LARGE SELECTED ITEM
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _largeItem(selected),
                  ),
                ),
              ),

              // BOTTOM INFORMATION / BUTTON
              Container(
                margin: const EdgeInsets.fromLTRB(18, 0, 18, 25),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF17120B).withOpacity(.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.gold.withOpacity(.45),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _showStoreMessage(selected.title);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'View',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryIcon(
    _StoreCategory item,
    bool selected,
  ) {
    IconData icon = item.icon;

    // Better icons for the Store categories
    switch (item.title) {
      case 'Frames':
        icon = Icons.all_inclusive;
        break;
      case 'VIP':
        icon = Icons.workspace_premium;
        break;
      case 'Vehicles':
        icon = Icons.directions_car;
        break;
      case 'Chat Bubble':
        icon = Icons.chat_bubble;
        break;
      case 'Room Lock':
        icon = Icons.lock;
        break;
      case 'Theme':
        icon = Icons.public;
        break;
      case 'Personal Page':
        icon = Icons.badge;
        break;
    }

    return Icon(
      icon,
      size: 45,
      color: selected
          ? AppColors.gold
          : const Color(0xFFFFD76A),
    );
  }

  Widget _largeItem(_StoreCategory item) {
    IconData icon = item.icon;

    switch (item.title) {
      case 'Frames':
        icon = Icons.all_inclusive;
        break;
      case 'VIP':
        icon = Icons.workspace_premium;
        break;
      case 'Vehicles':
        icon = Icons.directions_car;
        break;
      case 'Chat Bubble':
        icon = Icons.chat_bubble;
        break;
      case 'Room Lock':
        icon = Icons.lock;
        break;
      case 'Theme':
        icon = Icons.public;
        break;
      case 'Personal Page':
        icon = Icons.badge;
        break;
    }

    return Container(
      key: ValueKey(item.title),
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.gold.withOpacity(.22),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 125,
          color: AppColors.gold,
        ),
      ),
    );
  }

  void _showStoreMessage(String item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF17120B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium,
                size: 55,
                color: AppColors.gold,
              ),
              const SizedBox(height: 12),
              Text(
                item,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Store item details will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// STORE CATEGORY MODEL
// ============================================================

class _StoreCategory {
  final String title;
  final IconData icon;

  const _StoreCategory({
    required this.title,
    required this.icon,
  });
}

// ============================================================
// GOLD / BLACK STORE BACKGROUND
// ============================================================

class _StoreBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Black background
    paint.color = Colors.black;
    canvas.drawRect(
      Offset.zero & size,
      paint,
    );

    // Golden side glow
    final gradient = RadialGradient(
      center: Alignment.topCenter,
      radius: 1.1,
      colors: [
        const Color(0xFF5C421B).withOpacity(.30),
        Colors.transparent,
      ],
    );

    paint.shader = gradient.createShader(
      Rect.fromLTWH(
        0,
        0,
        size.width,
        size.height * .7,
      ),
    );

    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        size.width,
        size.height * .7,
      ),
      paint,
    );

    paint.shader = null;

    // Small particles
    paint.color = const Color(0xFFB18A48).withOpacity(.18);

    for (int i = 0; i < 55; i++) {
      final x = (i * 83.0) % size.width;
      final y = 150 + ((i * 97.0) % (size.height * .65));

      canvas.drawCircle(
        Offset(x, y),
        i % 3 == 0 ? 1.6 : 1,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}
