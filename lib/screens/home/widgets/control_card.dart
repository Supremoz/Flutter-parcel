import 'package:flutter/material.dart';

class ControlCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData iconData;
  final bool isActive;
  final VoidCallback onTap;

  const ControlCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.iconData,
    required this.isActive,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(iconData,
                    color: isActive ? Colors.indigo : Colors.grey,
                    size: 24),
                Container(
                  width: 32,
                  height: 16,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isActive
                        ? Colors.indigo
                        : Colors.grey[300],
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        left: isActive ? 16 : 0,
                        top: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Spacer(),
            Text(title,
                style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}