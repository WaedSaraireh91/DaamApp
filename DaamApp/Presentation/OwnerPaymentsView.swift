import SwiftUI

/// Available in this local UI prototype only; production access requires owner authorization.
struct OwnerPaymentsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var approvalID: UUID?
    private var pending: [Lesson] {
        app.snapshot.lessons.filter { app.transfer(for: $0.id)?.status == .submitted }
    }
    var body: some View {
        Page {
            NoticeCard(title: .ownerReview, bodyKey: .ownerDemo, symbol: "person.badge.key.fill")
            if pending.isEmpty { Text(app.text(.noTransfers)).foregroundStyle(DaamTheme.secondary) }
            ForEach(pending) { lesson in
                DashboardPanel {
                    Text(app.teacherName(app.teacher(lesson.teacherID))).font(.headline)
                    SummaryRow(title: .studentName, value: lesson.student)
                    SummaryRow(title: .feeTotal, value: app.money(app.transfer(for: lesson.id)?.amount ?? 1))
                    SummaryRow(title: .cliqAlias, value: app.transfer(for: lesson.id)?.recipientAlias ?? "")
                    SummaryRow(title: .transferReference, value: app.transfer(for: lesson.id)?.reference ?? "")
                    Button(app.text(.approveTransfer)) { approvalID = lesson.id }.buttonStyle(DaamButtonStyle())
                    Button(app.text(.rejectTransfer), role: .destructive) { app.reviewTransfer(for: lesson.id, approved: false) }
                }
            }
        }.navigationTitle(app.text(.ownerReview))
            .confirmationDialog(app.text(.approveTransfer), isPresented: Binding(get: { approvalID != nil }, set: { if !$0 { approvalID = nil } }), titleVisibility: .visible) {
                Button(app.text(.approveTransfer)) {
                    if let id = approvalID { app.reviewTransfer(for: id, approved: true) }
                    approvalID = nil
                }
                Button(app.text(.cancel), role: .cancel) { approvalID = nil }
            } message: { Text(app.text(.approveTransferMessage)) }
    }
}
