# Việc của Mẹ

Ứng dụng Android ghi việc cần làm bằng tiếng Việt, làm cho Mẹ: chữ to, nút lớn, có cả lịch dương và lịch âm. Package cố định **vn.bannie.nhac_viec**, APK **nhac-viec.apk**.

## Tính năng

- **Hôm nay**: lời chào, ngày dương và âm (năm can chi), báo Rằm, mùng Một và ngày lễ, thanh tiến độ, việc quá hạn, việc hôm nay và 7 ngày tới. Chạm vòng tròn lớn để đánh dấu xong (có Hoàn tác).
- **Lịch âm dương**: xem theo tháng dương (ngày âm nhỏ bên dưới) hoặc theo tháng âm (kể cả tháng nhuận). Rằm và mùng Một được tô màu, ngày lễ Việt Nam được đánh dấu, chấm màu cho biết ngày đó có việc thuộc nhóm nào.
- **Nhóm việc bằng biểu tượng**: 7 nhóm có sẵn (Sức khỏe, Gia đình, Đi chợ & nhà cửa, Giỗ lễ & chùa, Hẹn & gặp gỡ, Tiền nong, Việc khác). Có thể tạo hoặc sửa nhóm: chọn 1 trong 48 biểu tượng (chia theo 6 nhóm chủ đề) và 10 màu.
- **Trợ lý AI tạo việc**: nói (giọng tiếng Việt) hoặc gõ tự nhiên, nhiều việc một lúc, ví dụ *"Giỗ ông nội 12/3 âm lịch"*, *"Mai 7 giờ sáng uống thuốc"*. Trợ lý dùng Claude (`claude-opus-5-5`, structured output). Mẹ xem lại, sửa hoặc bỏ chọn từng việc rồi mới lưu. Không có mã khóa hoặc không có mạng thì dùng bộ hiểu tiếng Việt đơn giản, chạy ngay trên máy.
- **Lặp lại**: mỗi ngày, tuần, tháng hoặc năm (dương lịch); mỗi tháng âm (Rằm, mùng Một) hoặc mỗi năm âm (ngày giỗ, không tính vào tháng nhuận). Ngày 30 âm rơi vào tháng thiếu thì chuyển sang ngày 29.
- **Nhắc trên điện thoại**: đúng giờ, trước 15 phút, trước 1 giờ hoặc trước 1 ngày. Lên lịch sẵn tối đa 60 lời nhắc gần nhất trong 45 ngày tới, làm mới mỗi lần mở app hoặc sửa việc.
- **Giao diện thay đổi theo cài đặt**: 6 bảng màu (Hoa sen, Trà xanh, Biển xanh, Nắng mai, Cà phê sữa, Hoa cà) hoặc tự chọn màu; chế độ sáng, tối hoặc theo máy; 4 cỡ chữ; chữ đậm; tương phản cao; bo góc hoặc góc vuông; nút to rộng rãi. Mọi thay đổi áp dụng ngay, có ô xem trước.

## Riêng tư

- Dữ liệu chỉ lưu trên điện thoại (SharedPreferences).
- Mã khóa Claude API lưu trong Android Keystore (flutter_secure_storage), không nằm trong repo.
- Chỉ câu Mẹ nói hoặc gõ khi bấm **Tạo việc** mới được gửi tới Anthropic. Danh sách việc và cài đặt không bao giờ được gửi đi.

## Cấu trúc mã

```
lib/
  core/       lunar.dart (âm lịch, can chi, ngày lễ), format.dart
  models/     task.dart (lặp lại dương/âm), category.dart (nhóm biểu tượng), settings.dart
  data/       store.dart (lưu trữ, truy vấn hôm nay/quá hạn/sắp tới)
  services/   ai_service.dart (Claude), local_parser.dart (không cần AI),
              notifications.dart, speech.dart
  theme/      app_theme.dart (dựng ThemeData từ cài đặt)
  ui/         home_shell, today_page, calendar_page, categories_page,
              task_editor, ai_sheet, settings_page, widgets
test/         logic_test (âm lịch, lặp lại, bộ hiểu câu), services_test (AI, kho, nhắc, giao diện),
              widget_test (luồng sử dụng chính)
```

## Phát triển

Cài Flutter **3.35.7**, Java 17 và Android SDK 36:

```sh
bash scripts/prepare.sh
flutter analyze --no-fatal-infos
flutter test
flutter run
```

`scripts/prepare.sh` tạo host Android, cấu hình package, quyền, tên app và font Be Vietnam Pro. Thư mục `android/` không được commit.

## Build tự động

Workflow `.github/workflows/android.yml`:

- **develop**: phân tích, test, build APK debug và tải lên artifact **viec-cua-me-thu-nghiem** (14 ngày). Bản thử có package `vn.bannie.nhac_viec.dev`, cài song song với bản chính, không đụng dữ liệu thật.
- **main**: như trên, rồi build release có chữ ký cố định, kiểm tra SHA-256 chứng chỉ và tải lên artifact **nhac-viec**. **Cần thiết lập Secrets một lần: [docs/SETUP.md](docs/SETUP.md).**

## Giới hạn

- Chỉ có Android, chưa thử trên điện thoại thật.
- Nhắc việc phụ thuộc quyền thông báo, quyền báo thức chính xác và chế độ tiết kiệm pin của từng hãng.
- Nhận giọng nói dùng dịch vụ của hệ thống và có thể cần mạng.
- Trợ lý AI cần mã khóa Claude API; phí tính theo tài khoản Anthropic của mã khóa đó.
- Chưa có sao lưu đám mây. Đừng gỡ app nếu cần giữ dữ liệu.
- Phiên bản này dùng kho dữ liệu mới, không đọc dữ liệu của bản "Nhắc việc" cũ.

## Tham khảo

- [vnlunar, BSD-3-Clause](https://pub.dev/packages/vnlunar), thuật toán âm lịch của Hồ Ngọc Đức
- [Be Vietnam Pro, OFL](https://github.com/google/fonts/tree/main/ofl/bevietnampro)
- [Claude API: structured outputs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)
- [Flutter Android signing](https://docs.flutter.dev/deployment/android)
