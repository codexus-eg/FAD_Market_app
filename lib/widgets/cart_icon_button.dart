import 'package:flutter/material.dart';

import '../services/cart_service.dart';

class CartIconButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color iconColor;
  final Color badgeColor;

  const CartIconButton({
    super.key,
    required this.onTap,
    this.iconColor = Colors.white,
    this.badgeColor = const Color(0xFFD4A02A),
  });

  @override
  State<CartIconButton> createState() => _CartIconButtonState();
}

class _CartIconButtonState extends State<CartIconButton> {
  late Future<int> _countFuture;

  @override
  void initState() {
    super.initState();
    _countFuture = CartService.getItemsCount();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _countFuture,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: widget.onTap,
              icon: Icon(
                Icons.shopping_cart_outlined,
                color: widget.iconColor,
              ),
            ),
            if (count > 0)
              Positioned(
                top: 4,
                right: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Container(
                    height: 18,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: widget.badgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
