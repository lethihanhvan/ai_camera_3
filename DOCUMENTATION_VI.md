# Tài Liệu Hướng Dẫn Sử Dụng Ứng Dụng Nhận Dạng Khuôn Mặt AI

## Giới thiệu

Đây là ứng dụng nhận dạng khuôn mặt thông minh, cho phép người dùng chọn ảnh, tự động phát hiện các khuôn mặt, nhận dạng những người đã có trong cơ sở dữ liệu, và quản lý danh sách người dùng một cách hiệu quả.

---

## 1. Màn Hình Chính

Màn hình chính là nơi bắt đầu mọi thao tác. Giao diện được thiết kế hiện đại và trực quan.

*   **Thanh trên cùng (App Bar):** Hiển thị tên ứng dụng và nút **Cài đặt** (biểu tượng bánh răng).
*   **Thẻ Thống Kê:** Khi có ảnh được chọn, một thẻ thống kê sẽ xuất hiện, cung cấp thông tin nhanh về:
    *   **Số lượng ảnh** đã chọn.
    *   **Tổng số khuôn mặt** được phát hiện.
    *   **Tổng số người** đã có trong cơ sở dữ liệu.
*   **Khu vực hiển thị ảnh:** Liệt kê các ảnh đã được chọn cùng với các khuôn mặt được đánh dấu.
*   **Nút chức năng (dưới cùng):**
    *   **Chọn Ảnh:** Mở thư viện để chọn một hoặc nhiều ảnh cần xử lý.
    *   **Hiển Thị Người Đã Tìm Thấy:** Sau khi xử lý, nút này sẽ dẫn đến trang danh sách những người đã được nhận dạng.

*Ảnh chụp màn hình chính:*
> **[Chèn ảnh chụp màn hình chính ở đây]**

### 1.1. Menu Cài Đặt

Khi nhấn vào biểu tượng bánh răng, một menu sẽ trượt lên từ dưới cùng với các tùy chọn:

*   **Quản lý Người Dùng:** Mở trang quản lý tất cả người dùng trong cơ sở dữ liệu.
*   **Nhập/Xuất Dữ Liệu:** Mở trang để sao lưu hoặc phục hồi dữ liệu người dùng.
*   **File Báo Cáo:** Mở trang xem các file Excel đã được xuất.

*Ảnh chụp menu cài đặt:*
> **[Chèn ảnh chụp màn-hình-menu-cài-đặt.png]**

---

## 2. Xem và Tương Tác Với Ảnh

Mỗi ảnh được chọn sẽ hiển thị trong một thẻ riêng.

*   **Đánh dấu khuôn mặt:** Các khuôn mặt được phát hiện sẽ được bao quanh bởi một khung màu đỏ.
*   **Tương tác:**
    *   **Chạm vào khuôn mặt:** Mở hộp thoại để thêm thông tin cho người mới hoặc liên kết với người đã có.
    *   **Chạm đúp (Double Tap):** Phóng to/thu nhỏ ảnh.
    *   **Nhấn giữ (Long Press):** Mở hộp thoại xác nhận để xóa ảnh khỏi danh sách.

*Ảnh chụp một thẻ xem ảnh với các khuôn mặt được đánh dấu:*
> **[Chèn ảnh chụp màn-hình-xem-ảnh.png]**

### 2.1. Hộp Thoại Thêm/Sửa Thông Tin

Khi chạm vào một khuôn mặt, bạn có thể:

*   **Lưu người mới:** Nhập thông tin (Tên, Mã sinh viên, Email, Phân loại) và lưu vào cơ sở dữ liệu.
*   **Chọn người đã có:** Chọn một người từ danh sách thả xuống để liên kết khuôn mặt này với h�� sơ đã tồn tại. Thao tác này sẽ thêm ảnh khuôn mặt và vector embedding mới vào hồ sơ của họ.

*Ảnh chụp hộp thoại thêm thông tin:*
> **[Chèn ảnh chụp màn-hình-thêm-thông-tin.png]**

---

## 3. Trang "Người Đã Tìm Thấy"

Trang này liệt kê tất cả những người đã được nhận dạng từ các ảnh bạn đã chọn.

*   **Thẻ Thống Kê:** Tóm tắt số lượng người, tổng số ảnh và tổng số vector embedding.
*   **Danh sách người dùng:** Mỗi người được hiển thị trong một thẻ riêng với các thông tin:
    *   Tên và Mã sinh viên.
    *   Huy hiệu "Đã nhận dạng".
    *   Danh sách các ảnh khuôn mặt được tìm thấy (cuộn ngang).
    *   Thông tin chi tiết (Email, Phân loại).
    *   Thống kê số lượng vector embedding và ảnh.
*   **Xuất Báo Cáo:** Nút "Export Report" ở góc trên bên phải cho phép xuất danh sách này ra file Excel.

*Ảnh chụp trang Người Đã Tìm Thấy:*
> **[Chèn ảnh chụp màn-hình-người-đã-tìm-thấy.png]**

---

## 4. Trang "Quản Lý Người Dùng"

Đây là nơi bạn có thể xem, tìm kiếm, sửa và xóa tất cả người dùng trong cơ sở dữ liệu.

*   **Thanh tìm kiếm:** Cho phép tìm kiếm nhanh theo tên, mã sinh viên, email, hoặc phân loại.
*   **Danh sách người dùng:** Hiển thị thông tin tóm tắt của mỗi người.
*   **Menu tùy chọn (dấu ba chấm):**
    *   **Xem Chi Tiết:** Mở hộp thoại hiển thị toàn bộ thông tin, bao gồm cả thư viện ảnh khuôn mặt của người đó.
    *   **Sửa:** Mở hộp thoại để chỉnh sửa thông tin.
    *   **Xóa:** Xóa người dùng khỏi cơ sở dữ liệu (có yêu cầu xác nhận).

*Ảnh chụp trang Quản Lý Người Dùng:*
> **[Chèn ảnh chụp màn-hình-quản-lý-người-dùng.png]**

---

## 5. Trang "Nhập/Xuất Dữ Liệu"

Tính năng này giúp bạn sao lưu (export) và phục hồi (import) toàn bộ cơ sở dữ liệu người dùng.

*   **Export to JSON:** Tạo một file backup (`.json`) chứa tất cả thông tin người dùng, bao gồm cả ảnh và vector embedding. File sẽ được lưu vào thư mục Downloads.
*   **Import from JSON:** Chọn một file `.json` để phục hồi dữ liệu.
    *   Nếu ID người dùng chưa tồn tại, một hồ sơ mới sẽ được tạo.
    *   Nếu ID người dùng đã tồn tại, ứng dụng sẽ tự động **hợp nhất** dữ liệu: thêm các ảnh và vector embedding mới vào hồ sơ hiện có mà không tạo ra bản sao.

*Ảnh chụp trang Nhập/Xuất Dữ Liệu:*
> **[Chèn ảnh chụp màn-hình-nhập-xuất.png]**

---

## 6. Trang "File Báo Cáo"

Trang này liệt kê tất cả các file Excel đã được xuất từ trang "Người Đã Tìm Thấy".

*   **Bộ lọc ngày:** Cho phép bạn lọc danh sách file theo một khoảng thời gian cụ thể.
*   **Danh sách file:** Mỗi file được hiển thị trong một thẻ với các thông tin:
    *   Tên file.
    *   Ngày giờ sửa đổi.
    *   Kích thước file.
*   **Mở file:** Chạm vào một thẻ để mở file Excel tương ứng bằng ứng dụng mặc định trên điện thoại.

*Ảnh chụp trang File Báo Cáo:*
> **[Chèn ảnh chụp màn-hình-file-báo-cáo.png]**

