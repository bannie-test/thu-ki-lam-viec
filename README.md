# Nhắc việc

Flutter Android app cá nhân bằng tiếng Việt, chữ lớn, nhân vật đồng hồ. Tên app **Nhắc việc**, package cố định **vn.bannie.nhac_viec**, APK **nhac-viec.apk**.

- Công việc, biểu tượng theo loại, ghi chú, nhắc trước và lặp theo ngày/tuần/năm dương/năm âm.
- Lịch dương có ngày âm nhỏ bên dưới; lịch âm theo tháng âm Việt Nam (UTC+7), có tháng nhuận.
- Nhập giọng nói hoặc văn bản → xem lại → tùy chọn gửi OpenAI → xác nhận bản nháp → lưu.
- Khóa API lưu trong Android Keystore qua flutter_secure_storage, không ghi vào repo hoặc nhật ký. Bản cá nhân gọi trực tiếp OpenAI bằng khóa riêng của người dùng, không nhúng khóa dùng chung.
- Báo thức theo thứ; nhắc uống nước, ghi lượng đã uống; hỏi lại và tổng kết.
- Chọn màu chủ đạo, màu nền, ảnh nền, độ hiện ảnh, cỡ chữ. Font Be Vietnam Pro đóng gói vào APK.
- Lưu dữ liệu trên máy; cài bản cập nhật cùng chữ ký giữ dữ liệu.

## Phát triển

Cài Flutter **3.35.7**, Java 17 và Android SDK 36:

```sh
bash scripts/prepare.sh
flutter analyze --no-fatal-infos
flutter test
flutter run
```

Host Android được tạo có thể lặp lại bằng `scripts/prepare.sh`, sau đó cấu hình package, quyền và chữ ký bằng script Python được version-control. Không tự thay package hoặc khóa ký khi nâng cấp.

## Build tự động

Workflow `.github/workflows/android.yml`: push main hoặc Run workflow → phân tích, test, build Android debug kiểm tra → build release có chữ ký cố định → kiểm tra SHA-256 chứng chỉ → upload artifact **nhac-viec** (bên trong có **nhac-viec.apk**).

**Cần thiết lập Secrets một lần trước khi có APK release: [docs/SETUP.md](docs/SETUP.md).** Không dùng debug keystore ngẫu nhiên từ runner CI làm chữ ký release.

## Giới hạn cần biết

- Android trước; chưa có host iOS. Chưa kiểm thử trên điện thoại thật.
- Banner không luôn phủ trên mọi ứng dụng. Báo thức dùng thông báo ưu tiên cao, cờ lặp âm báo và màn hình Tắt / Nhắc lại. Toàn màn hình cần bật quyền riêng và vẫn phụ thuộc chính sách Android/nhà sản xuất. Các nút hành động mở app để cập nhật dữ liệu rõ ràng.
- Việc và tổng kết: lên lịch trước 21 ngày, làm mới khi mở/resume app, sửa dữ liệu hoặc xác nhận thông báo. Hãy mở app định kỳ; năm âm lên lịch lần tồn tại kế tiếp trong tối đa 8 năm. Báo thức/uống nước lặp bằng Android. Máy bị force-stop/tiết kiệm pin có thể chặn nhắc; bật quyền đúng giờ và thông báo.
- Nội dung tổng kết trên thông báo là ảnh chụp dữ liệu ở lần cập nhật lịch gần nhất; mở app để xem dữ liệu hiện tại. Các nút chỉ cập nhật khi người dùng bấm, không tự suy đoán đã quên.
- Không tự điểm danh trên ứng dụng khác; nhắc người dùng tự thực hiện.
- Chiều cao/cân nặng được nhập và lưu, nhưng không tạo một công thức y tế giả để suy ra chính xác nước uống. Mục tiêu điều chỉnh được, có chế độ mức dịch riêng theo bác sĩ. Mức tham khảo 1.600 ml cần người dùng xác nhận. Không thay hướng dẫn chuyên môn.
- Giọng nói tùy dịch vụ hệ thống, có thể cần mạng. AI tùy chọn, API tính phí riêng; không gửi âm thanh/hồ sơ sức khỏe/danh sách việc cho OpenAI.
- Chưa có sao lưu/đồng bộ đám mây. Không gỡ app nếu cần giữ dữ liệu.

## Tham khảo triển khai

- [Flutter Android signing](https://docs.flutter.dev/deployment/android)
- [flutter_local_notifications 19.5.0](https://pub.dev/packages/flutter_local_notifications/versions/19.5.0)
- [vnlunar, BSD-3-Clause](https://pub.dev/packages/vnlunar)
- [Be Vietnam Pro, OFL](https://github.com/google/fonts/tree/main/ofl/bevietnampro)
- [OpenAI: API và ChatGPT thanh toán riêng](https://help.openai.com/en/articles/9039756-managing-billing-for-chatgpt-and-the-api-platform)
- [NHS: nước và đồ uống](https://www.nhs.uk/live-well/eat-well/food-guidelines-and-food-labels/water-drinks-nutrition/)
