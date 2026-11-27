import 'package:flutter/material.dart';

/// One selectable icon. The [key] is what gets stored, so icons survive
/// app updates even if the list order changes.
class AppIcon {
  final String key;
  final IconData icon;
  final String label;
  const AppIcon(this.key, this.icon, this.label);
}

/// Icons are grouped by life area so Mẹ can find one quickly.
class IconGroup {
  final String name;
  final List<AppIcon> icons;
  const IconGroup(this.name, this.icons);
}

const iconGroups = <IconGroup>[
  IconGroup('Sức khỏe', [
    AppIcon('medication', Icons.medication_rounded, 'Uống thuốc'),
    AppIcon('hospital', Icons.local_hospital_rounded, 'Khám bệnh'),
    AppIcon('heart', Icons.monitor_heart_rounded, 'Đo huyết áp'),
    AppIcon('walk', Icons.directions_walk_rounded, 'Đi bộ'),
    AppIcon('yoga', Icons.self_improvement_rounded, 'Tập dưỡng sinh'),
    AppIcon('water', Icons.water_drop_rounded, 'Uống nước'),
    AppIcon('spa', Icons.spa_rounded, 'Thư giãn'),
    AppIcon('bed', Icons.bedtime_rounded, 'Ngủ nghỉ'),
  ]),
  IconGroup('Gia đình', [
    AppIcon('family', Icons.family_restroom_rounded, 'Gia đình'),
    AppIcon('child', Icons.child_care_rounded, 'Con cháu'),
    AppIcon('cake', Icons.cake_rounded, 'Sinh nhật'),
    AppIcon('party', Icons.celebration_rounded, 'Tiệc tùng'),
    AppIcon('elderly', Icons.elderly_rounded, 'Ông bà'),
    AppIcon('call', Icons.call_rounded, 'Gọi điện'),
    AppIcon('pets', Icons.pets_rounded, 'Thú cưng'),
    AppIcon('gift', Icons.card_giftcard_rounded, 'Quà tặng'),
  ]),
  IconGroup('Nhà cửa & chợ', [
    AppIcon('cart', Icons.shopping_cart_rounded, 'Đi chợ'),
    AppIcon('basket', Icons.shopping_basket_rounded, 'Mua sắm'),
    AppIcon('cook', Icons.soup_kitchen_rounded, 'Nấu ăn'),
    AppIcon('clean', Icons.cleaning_services_rounded, 'Dọn dẹp'),
    AppIcon('laundry', Icons.local_laundry_service_rounded, 'Giặt giũ'),
    AppIcon('bill', Icons.receipt_long_rounded, 'Hóa đơn'),
    AppIcon('repair', Icons.handyman_rounded, 'Sửa chữa'),
    AppIcon('garden', Icons.yard_rounded, 'Vườn tược'),
  ]),
  IconGroup('Lễ & tâm linh', [
    AppIcon('temple', Icons.temple_buddhist_rounded, 'Đi chùa'),
    AppIcon('flower', Icons.local_florist_rounded, 'Cúng giỗ'),
    AppIcon('moon', Icons.nightlight_round, 'Rằm, mùng một'),
    AppIcon('incense', Icons.whatshot_rounded, 'Thắp hương'),
    AppIcon('pray', Icons.volunteer_activism_rounded, 'Làm phúc'),
    AppIcon('lantern', Icons.light_rounded, 'Lễ Tết'),
    AppIcon('sparkle', Icons.auto_awesome_rounded, 'Ngày đặc biệt'),
    AppIcon('wedding', Icons.favorite_rounded, 'Đám cưới'),
  ]),
  IconGroup('Hẹn & công việc', [
    AppIcon('people', Icons.groups_rounded, 'Gặp gỡ'),
    AppIcon('event', Icons.event_rounded, 'Cuộc hẹn'),
    AppIcon('work', Icons.work_rounded, 'Công việc'),
    AppIcon('school', Icons.school_rounded, 'Học hành'),
    AppIcon('book', Icons.menu_book_rounded, 'Đọc sách'),
    AppIcon('note', Icons.edit_note_rounded, 'Ghi chép'),
    AppIcon('money', Icons.payments_rounded, 'Tiền nong'),
    AppIcon('bank', Icons.account_balance_rounded, 'Ngân hàng'),
  ]),
  IconGroup('Đi lại & khác', [
    AppIcon('bus', Icons.directions_bus_rounded, 'Đi xe'),
    AppIcon('travel', Icons.luggage_rounded, 'Du lịch'),
    AppIcon('place', Icons.place_rounded, 'Địa điểm'),
    AppIcon('star', Icons.star_rounded, 'Quan trọng'),
    AppIcon('alarm', Icons.alarm_rounded, 'Báo thức'),
    AppIcon('tv', Icons.tv_rounded, 'Xem TV'),
    AppIcon('phone', Icons.smartphone_rounded, 'Điện thoại'),
    AppIcon('check', Icons.checklist_rounded, 'Việc chung'),
  ]),
];

final Map<String, AppIcon> _iconByKey = {
  for (final g in iconGroups)
    for (final i in g.icons) i.key: i,
};

IconData iconFor(String key) =>
    _iconByKey[key]?.icon ?? Icons.checklist_rounded;

/// Soft, clearly distinct colours (good contrast with white icons).
const categoryColors = <int>[
  0xFFE53935, // đỏ
  0xFFF4511E, // cam
  0xFFF9A825, // vàng đậm
  0xFF43A047, // xanh lá
  0xFF00897B, // xanh ngọc
  0xFF1E88E5, // xanh dương
  0xFF5E35B1, // tím
  0xFFD81B60, // hồng
  0xFF6D4C41, // nâu
  0xFF546E7A, // xám xanh
];

class Category {
  final String id;
  String name;
  String icon;
  int color;
  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  IconData get iconData => iconFor(icon);
  Color get colorValue => Color(color);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
  };
  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Nhóm',
    icon: j['icon'] as String? ?? 'check',
    color: j['color'] as int? ?? categoryColors.last,
  );
}

const otherCategoryId = 'khac';

List<Category> defaultCategories() => [
  Category(
    id: 'suc-khoe',
    name: 'Sức khỏe',
    icon: 'medication',
    color: 0xFFE53935,
  ),
  Category(id: 'gia-dinh', name: 'Gia đình', icon: 'family', color: 0xFFF4511E),
  Category(
    id: 'nha-cua',
    name: 'Đi chợ & nhà cửa',
    icon: 'cart',
    color: 0xFF43A047,
  ),
  Category(
    id: 'le-gio',
    name: 'Giỗ, lễ & chùa',
    icon: 'temple',
    color: 0xFF5E35B1,
  ),
  Category(
    id: 'hen-gap',
    name: 'Hẹn & gặp gỡ',
    icon: 'people',
    color: 0xFF1E88E5,
  ),
  Category(
    id: 'tien-nong',
    name: 'Tiền nong',
    icon: 'money',
    color: 0xFF00897B,
  ),
  Category(
    id: otherCategoryId,
    name: 'Việc khác',
    icon: 'check',
    color: 0xFF546E7A,
  ),
];
