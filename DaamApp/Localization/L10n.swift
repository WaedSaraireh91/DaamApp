import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case arabic = "ar", english = "en"
    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue == "ar" ? "ar_JO" : "en_JO") }
}

/// Typed keys are the only entry point for user-facing copy.
enum L10n: String, CaseIterable {
    case browseTeachers, registerOrLogin, findYourTeacher, learningStartsHere, discoveryHeadline, discoverySubtitle, localTeachers, flexibleTimes, directoryUnavailable, directoryEmptyBody, joinDaam, teachersComingSoon, howDaamWorks, chooseYourTeacher, chooseYourTime, learnAndPayCash, browseFreely, reviewedTeacher, viewTeacher, welcomeBack, authNewSubtitle, loginMethod, localPhoneTitle, localPhoneBody, localCodeLabel, codeExpiry, changePhone, sendPhoneCode, verifyAndContinue, invalidPhone, invalidPhoneCode, phoneCooldown, phoneRegistrationRequired, phoneAlreadyRegistered, phoneVerificationCode, resendPhoneCode, invalidPersonName
    case approveTeacher, replyTitle, loadMore
    case firstName, lastName, phoneNumber, forgotPasswordTitle, resetPasswordTitle, sendResetLink, resetEmailSent, passwordResetDone, emailVerifiedDone, linkExpired, emailAlreadyUsed, checkDetails, backendConfigurationRequired, subjectsTitle, teacherReviewPending, addAvailability, completeLesson, completed, cancelled, supportTitle, supportMessage, sendMessage, supportPending
    case notifications, noNotifications, notificationNewRequest, notificationRequestPending, notificationLessonAccepted, notificationLessonDeclined, notificationLessonCancelled, notificationLessonCompleted, notificationTransferWaiting, notificationTransferVerified, notificationTransferRejected
    case selectOnMap, tapMapToChoose, findingAddress, confirmLocation, openDirections, payAcceptanceFee
    case latestLesson, noUpcomingLessons
    case teacherPhoto, teacherPhotoHint, addTeacherPhoto, changeTeacherPhoto, profilePhotoError
    case forceUpdateTitle, forceUpdateBody, updateNow, checkAgain
    case messages, inbox, newMessage, sent, supportIntro, messageText, messageSent
    case noInboxMessages, noSentMessages, supportRecipient, supportAnswered
    case authNameRequired, authEmailRequired, authPasswordRequired, authPasswordMismatch, authEmailResent
    case authWelcome, authPhaseNotice, signOut, verifyEmail, verificationInstructions, verificationCode
    case fullName, confirmPassword, passwordRule, resendCode, backToLogin, authTryAgain, authThrottled, authRejected
    case registrationTitle
    case experienceBrief
    case experienceHint
    case teachingAreas
    case studentArea
    case areaMatchingNote
    case privateCertificate
    case certificateNotice
    case certificateStored
    case chooseCertificate
    case certificateError
    case declarationTitle
    case termsTitle
    case agreeContinue
    case dismissAction
    case acceptDeclaration
    case teacherDeclaration
    case parentDeclaration
    case registrationRequired
    case nearbyTeachers
    case nearbyOnly
    case noAreaMatches
    case area_jubeiha
    case area_khalda
    case area_shmeisani
    case area_amman
    case area_irbid
    case area_zarqa
    case area_balqa
    case area_madaba
    case area_jerash
    case area_ajloun
    case area_mafraq
    case area_karak
    case area_tafilah
    case area_maan
    case area_aqaba

    case splashMessage, skipIntro
    case rateSetupTitle
    case rateSetupBody
    case hourlyRate
    case rateHint
    case saveRate
    case invalidRate
    case cliqTitle
    case cliqBody
    case cliqRecipient
    case cliqAlias
    case cliqNotConfigured
    case transferReference
    case referenceHint
    case submitTransfer
    case awaitingVerification
    case verificationBody
    case paymentRequired
    case paymentVerified
    case demoNoTransfers
    case ownerReview
    case ownerDemo
    case approveTransfer
    case approveTransferMessage
    case rejectTransfer
    case transferRejected
    case transferRejectedBody
    case noTransfers
    case duplicateReference
    case bookingDetailsIntro
    case scheduleIntro
    case reviewIntro
    case quickActions
    case studentDetails
    case yourLesson
    case paymentSummary
    case brand
    case tagline
    case welcome
    case parent
    case teacher
    case chooseRole
    case parentRole
    case teacherRole
    case continueAction
    case next
    case start
    case login
    case createAccount
    case email
    case password
    case emailHint
    case passwordHint
    case demoEntry
    case demoNotice
    case onboardTitle1
    case onboardBody1
    case onboardTitle2
    case onboardBody2
    case home
    case bookings
    case favorites
    case account
    case search
    case searchHint
    case parentGreeting
    case parentSubtitle
    case featured
    case seeAll
    case noBookingFee
    case cashPolicy
    case all
    case online
    case inPerson
    case math
    case english
    case science
    case amman
    case results
    case teachersCount
    case perHour
    case money
    case teacherBio
    case about
    case experience
    case bookLesson
    case save
    case saved
    case bookingDetails
    case studentName
    case studentHint
    case grade
    case gradeFormat
    case dateTime
    case date
    case time
    case duration
    case oneHour
    case location
    case city
    case address
    case addressHint
    case notes
    case notesHint
    case review
    case confirmBooking
    case lessonPrice
    case bookingFee
    case dueNow
    case successTitle
    case successBody
    case viewBookings
    case pending
    case accepted
    case declined
    case emptyBookings
    case emptyBookingsBody
    case emptyFavorites
    case emptyFavoritesBody
    case teacherDashboard
    case teacherGreeting
    case teacherSubtitle
    case requests
    case schedule
    case students
    case newRequests
    case confirmedLessons
    case feeTotal
    case firstFreeTitle
    case firstFreeBody
    case nextFee
    case requestDetails
    case acceptLesson
    case declineLesson
    case confirmAccept
    case acceptFree
    case acceptPaid
    case feeRecorded
    case cancel
    case done
    case emptyRequests
    case emptyRequestsBody
    case emptySchedule
    case emptyScheduleBody
    case emptyStudents
    case emptyStudentsBody
    case profile
    case language
    case arabic
    case englishLanguage
    case switchRole
    case localData
    case errorTitle
    case retry
    case invalidBooking
    case alreadyHandled
    case storageError
    case timeUnavailable
    case emptySearch
    case emptySearchBody
    case availabilityNote
    case cashBadge
    case lesson
    case free
    case teacherNameAhmad
    case teacherNameSarah
    case teacherNameMohammad
    case stepDetails
    case stepTime
    case stepReview
    case declineConfirmation
    case bookingReference
    case acceptedCount
    case feeLedger
    case teacherLocation
    case studentLocation
    case jubeiha
    case khalda
    case shmeisani
    case noFeesYet
    func text(_ language: AppLanguage) -> String {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return rawValue }
        return bundle.localizedString(forKey: rawValue, value: nil, table: "Localizable")
    }
    func format(_ language: AppLanguage, _ arguments: CVarArg...) -> String {
        String(format: text(language), locale: language.locale, arguments: arguments)
    }
}
