import 'package:flutter/material.dart';

class NavItem extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const NavItem({
    Key? key,
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? Colors.white : Colors.grey),
          SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : Colors.grey)),
        ],
      ),
    );
  }
}