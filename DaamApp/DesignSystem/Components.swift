import SwiftUI

enum Artwork: String { case logo = "DaamMark", learning = "LearningArt", teaching = "TeachingArt", schedule = "ScheduleArt" }

struct AnimatedArtwork: View {
    let artwork: Artwork
    var height: CGFloat = 190
    var body: some View {
        Image(artwork.rawValue).resizable().scaledToFit()
            .frame(maxWidth: .infinity).frame(height: height)
            .background(Color("Canvas"))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .accessibilityHidden(true)
    }
}

struct Page<Content: View>: View {
    var framed = true
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { content }
                .padding(16).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.daamScreen(framed: framed)
    }
}

struct BrandHeader: View {
    @EnvironmentObject private var app: AppModel
    var body: some View {
        HStack(spacing: 10) {
            Image(Artwork.logo.rawValue).resizable().scaledToFit().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.text(.brand)).font(.title2.bold())
                Text(app.text(.tagline)).font(.caption).foregroundStyle(DaamTheme.secondary)
            }
            Spacer()
        }
    }
}

struct NoticeCard: View {
    let title: L10n
    let bodyKey: L10n
    var symbol = "checkmark.shield.fill"
    @EnvironmentObject private var app: AppModel
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundStyle(DaamTheme.primary)
            VStack(alignment: .leading, spacing: 8) {
                Text(app.text(title)).font(.subheadline.bold())
                Text(app.text(bodyKey)).font(.footnote).foregroundStyle(DaamTheme.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("Mint"), in: RoundedRectangle(cornerRadius: 20))
    }
}

struct EmptyState: View {
    let title: L10n
    let message: L10n
    var artwork: Artwork = .schedule
    @EnvironmentObject private var app: AppModel
    var body: some View {
        VStack(spacing: 18) {
            AnimatedArtwork(artwork: artwork, height: 170)
            Text(app.text(title)).font(.title3.bold())
            Text(app.text(message)).font(.subheadline).foregroundStyle(DaamTheme.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}

struct SummaryRow: View {
    let title: L10n
    let value: String
    @EnvironmentObject private var app: AppModel
    var body: some View {
        HStack(alignment: .top) {
            Text(app.text(title)).foregroundStyle(DaamTheme.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
        }.font(.subheadline).padding(.vertical, 5)
    }
}

struct TeacherTile: View {
    let teacher: Teacher
    @EnvironmentObject private var app: AppModel
    var body: some View {
        HStack(spacing: 14) {
            Image(teacher.id == "sarah" ? Artwork.learning.rawValue : Artwork.teaching.rawValue)
                .resizable().scaledToFill().frame(width: 76, height: 88).clipped().clipShape(RoundedRectangle(cornerRadius: 16)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(app.teacherName(teacher)).font(.subheadline.bold()).foregroundStyle(DaamTheme.text)
                Text(app.subject(teacher)).font(.footnote).foregroundStyle(DaamTheme.secondary)
                Label(app.teacherLocation(teacher), systemImage: "mappin.and.ellipse")
                    .font(.caption).foregroundStyle(DaamTheme.secondary)
                Text(L10n.perHour.format(app.language, app.money(app.hourlyRate(teacher)))).font(.footnote.bold()).foregroundStyle(DaamTheme.primary)
            }
            Spacer(minLength: 0)
            Label(teacher.rating, systemImage: "star.fill").font(.caption.bold()).foregroundStyle(DaamTheme.gold)
        }.padding(14).daamCard(radius: 20)
    }
}

struct LessonTile: View {
    let lesson: Lesson
    @EnvironmentObject private var app: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(lesson.student).font(.headline)
                Spacer()
                Text(app.status(lesson.status)).font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color("Mint"), in: Capsule()).foregroundStyle(DaamTheme.primary)
            }
            Text(app.teacherName(app.teacher(lesson.teacherID))).font(.subheadline)
            VStack(alignment: .leading, spacing: 8) {
                Label(app.text(.teacherLocation) + ": " + app.teacherLocation(app.teacher(lesson.teacherID)), systemImage: "mappin.and.ellipse")
                Label(app.text(.studentLocation) + ": " + lesson.address, systemImage: "house.fill")
            }.font(.footnote).foregroundStyle(DaamTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Label { Text(lesson.date, format: .dateTime.day().month().hour().minute().locale(app.language.locale)) } icon: { Image(systemName: "calendar") }
                .font(.footnote).foregroundStyle(DaamTheme.secondary)
            HStack {
                Text(app.money(lesson.price)).font(.subheadline.bold())
                Spacer()
                Text(app.text(.cashBadge)).font(.caption).foregroundStyle(DaamTheme.secondary)
            }
        }.padding(18).daamCard(radius: 20)
    }
}

/// Consistent, clearly bounded dashboard sections.
struct DashboardPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(DaamTheme.primary.opacity(0.15), lineWidth: 1))
    }
}

struct DashboardHero: View {
    let title: L10n
    let subtitle: L10n
    let artwork: Artwork
    @EnvironmentObject private var app: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        DashboardPanel {
            if typeSize.isAccessibilitySize {
                copy
                AnimatedArtwork(artwork: artwork, height: 150)
            } else {
                HStack(spacing: 10) {
                    copy
                    AnimatedArtwork(artwork: artwork, height: 140).frame(width: 135)
                }
            }
        }
    }
    private var copy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(app.text(title)).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
            Text(app.text(subtitle)).font(.subheadline).foregroundStyle(DaamTheme.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
