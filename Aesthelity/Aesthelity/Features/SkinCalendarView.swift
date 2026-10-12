//
//  SkinCalendarView.swift
//  Aesthelity
//
//  Skin Calendar, Journal, and Daily Log Views for Aesthelity Skincare Routine Optimizer.
//

import SwiftUI

// MARK: - Skin Mood Model

public enum SkinMood: String, CaseIterable, Identifiable, Codable {
    case calm = "Calm"
    case dry = "Dry"
    case redness = "Redness"
    case breakout = "Breakout"
    case irritated = "Irritated"
    case glowy = "Glowy"
    
    public var id: String { rawValue }
    public var displayName: String { rawValue }
}

// MARK: - Skin Log Entry Model

public struct SkinLogEntry: Identifiable, Equatable, Codable {
    public let id: UUID
    public var dateString: String
    public var title: String
    public var subtitle: String
    public var mood: SkinMood?
    public var note: String
    public var conditions: [String]
    public var badgeText: String?
    public var hasDot: Bool
    public var isHighlighted: Bool
    
    public init(
        id: UUID = UUID(),
        dateString: String,
        title: String,
        subtitle: String,
        mood: SkinMood? = nil,
        note: String = "",
        conditions: [String] = [],
        badgeText: String? = nil,
        hasDot: Bool = false,
        isHighlighted: Bool = false
    ) {
        self.id = id
        self.dateString = dateString
        self.title = title
        self.subtitle = subtitle
        self.mood = mood
        self.note = note
        self.conditions = conditions
        self.badgeText = badgeText
        self.hasDot = hasDot
        self.isHighlighted = isHighlighted
    }
}

// MARK: - Calendar Day Item Model

public struct CalendarDayItem: Identifiable, Equatable {
    public let id = UUID()
    public let dayNumber: Int
    public let isCurrentMonth: Bool
    public let hasDot: Bool
    public let isSelected: Bool
    public let isSoftHighlighted: Bool
    
    public init(
        dayNumber: Int,
        isCurrentMonth: Bool = true,
        hasDot: Bool = false,
        isSelected: Bool = false,
        isSoftHighlighted: Bool = false
    ) {
        self.dayNumber = dayNumber
        self.isCurrentMonth = isCurrentMonth
        self.hasDot = hasDot
        self.isSelected = isSelected
        self.isSoftHighlighted = isSoftHighlighted
    }
}

// MARK: - Skin Journal Store

public class SkinJournalStore: ObservableObject {
    public static let shared = SkinJournalStore()
    
    @Published public var entries: [SkinLogEntry] = []
    @Published public var todayNote: String = "Low redness today. SPF layered well over serum."
    @Published public var todayMoodText: String = "Glowy / Calm"
    @Published public var todayConditions: [String] = ["Routine complete ✓"]
    
    public init() {
        loadDefaultEntries()
    }
    
    public func loadDefaultEntries() {
        let entrySep13 = SkinLogEntry(
            dateString: "September 13",
            title: "Glow day",
            subtitle: "Low redness · routine complete",
            mood: .calm,
            note: "Skin looked calm today. SPF layered well over vitamin C serum.",
            conditions: ["Low redness", "Routine complete", "SPF applied"],
            badgeText: "Good",
            hasDot: false,
            isHighlighted: true
        )
        
        let entrySep9 = SkinLogEntry(
            dateString: "September 9",
            title: "Dryness note",
            subtitle: "Cheeks felt tight after cleanser",
            mood: .dry,
            note: "Cheeks felt tight after cleanser. Layered extra barrier balm at night.",
            conditions: ["Routine complete"],
            badgeText: "Note",
            hasDot: true,
            isHighlighted: false
        )
        
        let entrySep6 = SkinLogEntry(
            dateString: "September 6",
            title: "Breakout note",
            subtitle: "Breakout near chin",
            mood: .breakout,
            note: "Breakout near chin after trying new sunscreen sample.",
            conditions: ["Low redness"],
            badgeText: "Note",
            hasDot: false,
            isHighlighted: false
        )
        
        self.entries = [entrySep13, entrySep9, entrySep6]
    }
    
    public func saveEntry(_ entry: SkinLogEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id || $0.dateString == entry.dateString }) {
            entries[idx] = entry
        } else {
            entries.insert(entry, at: 0)
        }
    }
}

// MARK: - Reusable Calendar Bottom Tab Bar

public struct CalendarTabBar: View {
    public var selectedIndex: Int
    public var onSelectTab: ((Int) -> Void)?
    
    public init(selectedIndex: Int = 4, onSelectTab: ((Int) -> Void)? = nil) {
        self.selectedIndex = selectedIndex
        self.onSelectTab = onSelectTab
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                // Tab 0: Home
                tabButton(title: "Home", systemImage: "house", index: 0)
                
                // Tab 1: Library
                tabButton(title: "Library", systemImage: "books.vertical", index: 1)
                
                // Tab 2: Scan (Center elevated)
                Button(action: { onSelectTab?(2) }) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#7C83BC"))
                                .frame(width: 56, height: 56)
                                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                            
                            Image(systemName: "viewfinder")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.white)
                        }
                        
                        Text("Scan")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "#6F4E37"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 88)
                    .padding(.bottom, 4)
                }
                .buttonStyle(.plain)
                
                // Tab 3: Explore
                tabButton(title: "Explore", systemImage: "magnifyingglass", index: 3)
                
                // Tab 4: Profile (Active)
                tabButton(title: "Profile", systemImage: "person", index: 4)
            }
            .frame(height: 72)
            
            // Safe Area spacer
            Color.clear
                .frame(height: 24)
        }
        .frame(height: 96)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#F7F3ED"))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color(hex: "#D8CFF0").opacity(0.8)),
            alignment: .top
        )
    }
    
    private func tabButton(title: String, systemImage: String, index: Int) -> some View {
        let isSelected = selectedIndex == index
        return Button(action: { onSelectTab?(index) }) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? "\(systemImage).fill" : systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color(hex: "#50578F") : Color(hex: "#6F4E37"))
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? Color(hex: "#50578F") : Color(hex: "#6F4E37"))
                
                if isSelected {
                    Capsule()
                        .fill(Color(hex: "#50578F"))
                        .frame(width: 16, height: 4)
                } else {
                    Color.clear
                        .frame(width: 16, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skin Calendar View (Image 1)

public struct SkinCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject public var store: SkinJournalStore
    
    public var backTitle: String
    public var showsTabBar: Bool
    public var onBack: (() -> Void)?
    public var onOpenLog: ((SkinLogEntry) -> Void)?
    public var onOpenJournal: (() -> Void)?
    public var onSelectTab: ((Int) -> Void)?
    
    @State private var selectedDay: Int = 13
    @State private var presentedLog: SkinLogEntry? = nil
    
    // Theme Colors
    private let brandBrown = Color(hex: "#6F4E37")
    private let inkSecondary = Color(hex: "#625478")
    private let inkPrimary = Color(hex: "#1A1628")
    private let surfaceBase = Color(hex: "#F7F3ED")
    private let selectedCircleColor = Color(hex: "#757CAE")
    private let softHighlightCircle = Color(hex: "#DFD8F5")
    private let lavenderIcon = Color(hex: "#E0DBF5")
    private let cardBorder = Color(hex: "#EAE5F4")
    
    public init(
        store: SkinJournalStore = .shared,
        backTitle: String = "Journal",
        showsTabBar: Bool = false,
        onBack: (() -> Void)? = nil,
        onOpenLog: ((SkinLogEntry) -> Void)? = nil,
        onOpenJournal: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.store = store
        self.backTitle = backTitle
        self.showsTabBar = showsTabBar
        self.onBack = onBack
        self.onOpenLog = onOpenLog
        self.onOpenJournal = onOpenJournal
        self.onSelectTab = onSelectTab
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // 1. Navigation Header (< Journal)
                    headerSection
                    
                    // 2. Calendar Card (September 2026 Grid)
                    calendarCard
                    
                    // 3. Recent Logs Section
                    recentLogsSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, showsTabBar ? 16 : 36)
            }
            
            // Bottom Tab Bar matching Image 1
            if showsTabBar {
                CalendarTabBar(selectedIndex: 4, onSelectTab: onSelectTab)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(surfaceBase)
        .sheet(item: $presentedLog) { log in
            SkinLogView(
                entry: log,
                backTitle: "Calendar",
                showsTabBar: showsTabBar,
                onDismiss: {
                    presentedLog = nil
                },
                onSave: { updatedLog in
                    store.saveEntry(updatedLog)
                    presentedLog = nil
                },
                onSelectTab: onSelectTab
            )
        }
    }
    
    // MARK: - 1. Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                if let onBack = onBack {
                    onBack()
                } else if let onOpenJournal = onOpenJournal {
                    onOpenJournal()
                } else {
                    dismiss()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text(backTitle)
                        .font(.system(size: 16, weight: .regular))
                }
                .foregroundStyle(inkSecondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Skin Calendar")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(brandBrown)
                
                Text("Track reactions, glow days, and routine consistency.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 2. Calendar Card
    private var calendarCard: some View {
        VStack(spacing: 20) {
            // Month Title
            HStack {
                Text("September 2026")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(inkPrimary)
                Spacer()
            }
            .padding(.horizontal, 6)
            
            // Weekday Headers: S M T W T F S
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(inkPrimary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Days Grid
            VStack(spacing: 12) {
                // Row 1: Aug 30, 31, Sep 1..5
                HStack(spacing: 0) {
                    dayCell(number: 30, isCurrentMonth: false)
                    dayCell(number: 31, isCurrentMonth: false)
                    dayCell(number: 1)
                    dayCell(number: 2)
                    dayCell(number: 3)
                    dayCell(number: 4)
                    dayCell(number: 5)
                }
                
                // Row 2: 6..12 (9 has a dot)
                HStack(spacing: 0) {
                    dayCell(number: 6)
                    dayCell(number: 7)
                    dayCell(number: 8)
                    dayCell(number: 9, hasDot: true)
                    dayCell(number: 10)
                    dayCell(number: 11)
                    dayCell(number: 12)
                }
                
                // Row 3: 13..19 (13 is selected, 16 is soft highlighted)
                HStack(spacing: 0) {
                    dayCell(number: 13, isSelected: selectedDay == 13)
                    dayCell(number: 14)
                    dayCell(number: 15)
                    dayCell(number: 16, isSoftHighlighted: true)
                    dayCell(number: 17)
                    dayCell(number: 18)
                    dayCell(number: 19)
                }
                
                // Row 4: 20..26 (22 has a dot)
                HStack(spacing: 0) {
                    dayCell(number: 20)
                    dayCell(number: 21)
                    dayCell(number: 22, hasDot: true)
                    dayCell(number: 23)
                    dayCell(number: 24)
                    dayCell(number: 25)
                    dayCell(number: 26)
                }
                
                // Row 5: 27..30, Oct 1..3
                HStack(spacing: 0) {
                    dayCell(number: 27)
                    dayCell(number: 28)
                    dayCell(number: 29)
                    dayCell(number: 30)
                    dayCell(number: 1, isCurrentMonth: false)
                    dayCell(number: 2, isCurrentMonth: false)
                    dayCell(number: 3, isCurrentMonth: false)
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(cardBorder, lineWidth: 1.2)
        )
    }
    
    private func dayCell(
        number: Int,
        isCurrentMonth: Bool = true,
        hasDot: Bool = false,
        isSelected: Bool = false,
        isSoftHighlighted: Bool = false
    ) -> some View {
        Button(action: {
            if isCurrentMonth {
                selectedDay = number
                if let entry = store.entries.first(where: { $0.dateString == "September \(number)" }) {
                    if let onOpenLog = onOpenLog {
                        onOpenLog(entry)
                    } else {
                        presentedLog = entry
                    }
                } else if number == 13 {
                    let sep13 = store.entries.first(where: { $0.dateString.contains("13") }) ?? SkinLogEntry(
                        dateString: "September 13",
                        title: "September 13 Log",
                        subtitle: "Track how your skin felt today.",
                        mood: .calm,
                        note: "Skin looked calm today. SPF layered well over vitamin C serum.",
                        conditions: ["Low redness", "Routine complete", "SPF applied"],
                        badgeText: "Good"
                    )
                    if let onOpenLog = onOpenLog {
                        onOpenLog(sep13)
                    } else {
                        presentedLog = sep13
                    }
                } else {
                    let newLog = SkinLogEntry(
                        dateString: "September \(number)",
                        title: "September \(number) Log",
                        subtitle: "Track how your skin felt today.",
                        mood: nil,
                        note: "",
                        conditions: ["Routine complete"]
                    )
                    if let onOpenLog = onOpenLog {
                        onOpenLog(newLog)
                    } else {
                        presentedLog = newLog
                    }
                }
            }
        }) {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(selectedCircleColor)
                            .frame(width: 40, height: 40)
                    } else if isSoftHighlighted {
                        Circle()
                            .fill(softHighlightCircle)
                            .frame(width: 40, height: 40)
                    }
                    
                    Text("\(number)")
                        .font(.system(size: 16, weight: isSelected ? .bold : (isSoftHighlighted ? .semibold : .regular)))
                        .foregroundStyle(
                            !isCurrentMonth ? Color(hex: "#BDB8C7") :
                                (isSelected ? Color.white : inkPrimary)
                        )
                }
                .frame(width: 40, height: 40)
                
                if hasDot {
                    Circle()
                        .fill(brandBrown)
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 3. Recent Logs Section
    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent logs")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(brandBrown)
            
            VStack(spacing: 12) {
                // Card 1: Glow day
                logRowCard(
                    title: "Glow day",
                    subtitle: "Low redness · routine complete",
                    badgeText: "Good",
                    onTap: {
                        let sep13 = store.entries.first(where: { $0.dateString.contains("13") }) ?? SkinLogEntry(
                            dateString: "September 13",
                            title: "September 13 Log",
                            subtitle: "Track how your skin felt today.",
                            mood: .calm,
                            note: "Skin looked calm today. SPF layered well over vitamin C serum.",
                            conditions: ["Low redness", "Routine complete", "SPF applied"],
                            badgeText: "Good"
                        )
                        if let onOpenLog = onOpenLog {
                            onOpenLog(sep13)
                        } else {
                            presentedLog = sep13
                        }
                    }
                )
                
                // Card 2: Dryness note
                logRowCard(
                    title: "Dryness note",
                    subtitle: "Cheeks felt tight after cleanser",
                    badgeText: "Note",
                    onTap: {
                        let sep9 = store.entries.first(where: { $0.dateString.contains("9") }) ?? SkinLogEntry(
                            dateString: "September 9",
                            title: "Dryness note",
                            subtitle: "Cheeks felt tight after cleanser",
                            mood: .dry,
                            note: "Cheeks felt tight after cleanser. Layered extra barrier balm at night.",
                            conditions: ["Routine complete"],
                            badgeText: "Note"
                        )
                        if let onOpenLog = onOpenLog {
                            onOpenLog(sep9)
                        } else {
                            presentedLog = sep9
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func logRowCard(
        title: String,
        subtitle: String,
        badgeText: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(lavenderIcon)
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(brandBrown)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(inkSecondary)
                }
                
                Spacer()
                
                Text(badgeText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(inkSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(softHighlightCircle)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skin Log View (Images 2 & 3)

public struct SkinLogView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State public var entry: SkinLogEntry
    public var backTitle: String
    public var showsTabBar: Bool
    public var showsValidationButton: Bool
    public var onDismiss: (() -> Void)?
    public var onSave: ((SkinLogEntry) -> Void)?
    public var onSelectTab: ((Int) -> Void)?
    
    @State private var selectedMood: SkinMood?
    @State private var noteText: String
    @State private var selectedConditions: Set<String>
    @State private var showSavedAlert: Bool = false
    
    // Theme Colors
    private let brandBrown = Color(hex: "#6F4E37")
    private let inkSecondary = Color(hex: "#625478")
    private let inkAccent = Color(hex: "#50578F")
    private let surfaceBase = Color(hex: "#F7F3ED")
    private let sageGreen = Color(hex: "#9EBA8F")
    private let sageGreenText = Color(hex: "#2E4826")
    private let borderPurple = Color(hex: "#7C83BC")
    private let unselectedBorder = Color(hex: "#DFD8F5")
    private let validationPeach = Color(hex: "#FDC89F")
    
    public init(
        entry: SkinLogEntry,
        backTitle: String = "Calendar",
        showsTabBar: Bool = false,
        showsValidationButton: Bool = true,
        onDismiss: (() -> Void)? = nil,
        onSave: ((SkinLogEntry) -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self._entry = State(initialValue: entry)
        self.backTitle = backTitle
        self.showsTabBar = showsTabBar
        self.showsValidationButton = showsValidationButton
        self.onDismiss = onDismiss
        self.onSave = onSave
        self.onSelectTab = onSelectTab
        self._selectedMood = State(initialValue: entry.mood ?? .calm)
        self._noteText = State(initialValue: entry.note.isEmpty ? "Skin looked calm today. SPF layered well over vitamin C serum." : entry.note)
        let initialConditions = entry.conditions.isEmpty ? ["Low redness", "Routine complete", "SPF applied"] : entry.conditions
        self._selectedConditions = State(initialValue: Set(initialConditions))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    // Header (< Calendar / < Journal)
                    headerSection
                    
                    // 1. Skin Mood Section
                    skinMoodSection
                    
                    // 2. Journal Note Section
                    journalNoteSection
                    
                    // 3. Skin Conditions Section
                    skinConditionsSection
                    
                    // 4. Action Buttons (Save skin log / Continue without mood / Validation)
                    actionButtonsSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, showsTabBar ? 16 : 36)
            }
            
            // Bottom Tab Bar matching Image 2 & 3
            if showsTabBar {
                CalendarTabBar(selectedIndex: 4, onSelectTab: onSelectTab)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(surfaceBase)
        .alert("Log Saved", isPresented: $showSavedAlert) {
            Button("OK") {
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            }
        } message: {
            Text("Your skin log for \(entry.dateString) has been updated.")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text(backTitle)
                        .font(.system(size: 16, weight: .regular))
                }
                .foregroundStyle(inkSecondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title.contains("Log") ? entry.title : "\(entry.dateString) Log")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(brandBrown)
                
                Text("Track how your skin felt today.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 1. Skin Mood Section
    private var skinMoodSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Skin mood")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(brandBrown)
            
            // Mood Pills Row 1 & Row 2
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    moodPill(.calm)
                    moodPill(.dry)
                    moodPill(.redness)
                }
                HStack(spacing: 12) {
                    moodPill(.breakout)
                    moodPill(.glowy)
                }
            }
        }
    }
    
    private func moodPill(_ mood: SkinMood) -> some View {
        let isSelected = selectedMood == mood
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                if selectedMood == mood {
                    selectedMood = nil
                } else {
                    selectedMood = mood
                }
            }
        }) {
            Text(mood.displayName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : brandBrown)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(isSelected ? brandBrown : Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : unselectedBorder, lineWidth: 1.2)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 2. Journal Note Section
    private var journalNoteSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Journal note")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(brandBrown)
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                
                TextEditor(text: $noteText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(inkAccent)
                    .scrollContentBackground(.hidden)
                    .padding(14)
            }
            .frame(height: 140)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderPurple, lineWidth: 1.5)
            )
        }
    }
    
    // MARK: - 3. Skin Conditions Section
    private var skinConditionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Skin conditions")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(brandBrown)
            
            HStack(spacing: 10) {
                conditionChip("Low redness")
                conditionChip("Routine complete")
                conditionChip("SPF applied")
            }
        }
    }
    
    private func conditionChip(_ text: String) -> some View {
        let isSelected = selectedConditions.contains(text)
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                if selectedConditions.contains(text) {
                    selectedConditions.remove(text)
                } else {
                    selectedConditions.insert(text)
                }
            }
        }) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? sageGreenText : inkSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isSelected ? sageGreen : Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : unselectedBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 4. Action Buttons Section (Images 2 & 3)
    private var actionButtonsSection: some View {
        VStack(spacing: 14) {
            // Save skin log (Primary Brown Capsule Button)
            Button(action: saveLogAction) {
                Text("Save skin log")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(brandBrown)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            // Image 3: Peach button "Save without mood (validation)"
            if showsValidationButton {
                Button(action: {
                    selectedMood = nil
                    saveLogAction()
                }) {
                    Text("Save without mood (validation)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(brandBrown)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(validationPeach)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                // Image 2: Text link "Continue without mood"
                Button(action: {
                    selectedMood = nil
                    saveLogAction()
                }) {
                    Text("Continue without mood")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(inkAccent)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
    }
    
    private func saveLogAction() {
        var updated = entry
        updated.mood = selectedMood
        updated.note = noteText
        updated.conditions = Array(selectedConditions)
        onSave?(updated)
        showSavedAlert = true
    }
}

// MARK: - Skin Journal View (Image 4)

public struct SkinJournalView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject public var store: SkinJournalStore
    
    public var backTitle: String
    public var showsTabBar: Bool
    public var onBack: (() -> Void)?
    public var onOpenCalendar: (() -> Void)?
    public var onSelectTab: ((Int) -> Void)?
    
    @State private var selectedMood: SkinMood = .calm
    @State private var presentedLog: SkinLogEntry? = nil
    @State private var showCalendarView: Bool = false
    
    // Theme Colors
    private let brandBrown = Color(hex: "#6F4E37")
    private let inkSecondary = Color(hex: "#625478")
    private let inkAccent = Color(hex: "#50578F")
    private let surfaceBase = Color(hex: "#F7F3ED")
    private let entryIconColor = Color(hex: "#7C83BC")
    private let cardBorder = Color(hex: "#EFEAF6")
    private let unselectedBorder = Color(hex: "#DFD8F5")
    
    public init(
        store: SkinJournalStore = .shared,
        backTitle: String = "Home",
        showsTabBar: Bool = false,
        onBack: (() -> Void)? = nil,
        onOpenCalendar: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.store = store
        self.backTitle = backTitle
        self.showsTabBar = showsTabBar
        self.onBack = onBack
        self.onOpenCalendar = onOpenCalendar
        self.onSelectTab = onSelectTab
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    // Header (< Home / Calendar Shortcut)
                    headerSection
                    
                    // Today Highlight Card (Pink Gradient)
                    todayHighlightCard
                    
                    // "How did your skin feel?" Section
                    howSkinFeltSection
                    
                    // "Recent entries" Section
                    recentEntriesSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, showsTabBar ? 16 : 36)
            }
            
            if showsTabBar {
                CalendarTabBar(selectedIndex: 4, onSelectTab: onSelectTab)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(surfaceBase)
        .sheet(item: $presentedLog) { log in
            SkinLogView(
                entry: log,
                backTitle: "Journal",
                showsTabBar: showsTabBar,
                onDismiss: {
                    presentedLog = nil
                },
                onSave: { updated in
                    store.saveEntry(updated)
                    presentedLog = nil
                },
                onSelectTab: onSelectTab
            )
        }
        .sheet(isPresented: $showCalendarView) {
            SkinCalendarView(
                store: store,
                backTitle: "Journal",
                showsTabBar: showsTabBar,
                onBack: {
                    showCalendarView = false
                },
                onSelectTab: onSelectTab
            )
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: {
                    if let onBack = onBack {
                        onBack()
                    } else {
                        dismiss()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text(backTitle)
                            .font(.system(size: 16, weight: .regular))
                    }
                    .foregroundStyle(inkSecondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Calendar Shortcut Button
                Button(action: {
                    if let onOpenCalendar = onOpenCalendar {
                        onOpenCalendar()
                    } else {
                        showCalendarView = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Calendar")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(inkAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(unselectedBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Skin Journal")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(brandBrown)
                
                Text("Your recent skin notes and condition history.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Today Highlight Card (Pink/Peach Gradient)
    private var todayHighlightCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top Row: Today + Badge
            HStack {
                Text("Today")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(brandBrown)
                
                Spacer()
                
                Text(store.todayMoodText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(brandBrown)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.35))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1)
                    )
            }
            
            // Middle: Note text
            Text(store.todayNote)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(brandBrown)
                .lineSpacing(4)
            
            // Bottom: Routine complete
            Text("Routine complete ✓")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(brandBrown)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#F9B8BE"),
                    Color(hex: "#FAD8DC")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - "How did your skin feel?" Section
    private var howSkinFeltSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How did your skin feel?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(brandBrown)
            
            // Pills: Calm, Dry, Redness, Breakout, Irritated, Glowy
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    moodChip(.calm)
                    moodChip(.dry)
                    moodChip(.redness)
                }
                HStack(spacing: 12) {
                    moodChip(.breakout)
                    moodChip(.irritated)
                    moodChip(.glowy)
                }
            }
        }
    }
    
    private func moodChip(_ mood: SkinMood) -> some View {
        let isSelected = selectedMood == mood
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedMood = mood
                store.todayMoodText = mood.displayName
            }
        }) {
            Text(mood.displayName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : brandBrown)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(isSelected ? brandBrown : Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : unselectedBorder, lineWidth: 1.2)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - "Recent entries" Section
    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent entries")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(brandBrown)
            
            VStack(spacing: 12) {
                ForEach(store.entries) { entry in
                    entryRow(entry)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func entryRow(_ entry: SkinLogEntry) -> some View {
        Button(action: {
            presentedLog = entry
        }) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(entryIconColor)
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.dateString)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(brandBrown)
                    
                    Text(entry.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(inkSecondary)
                }
                
                Spacer()
                
                Circle()
                    .fill(entryIconColor)
                    .frame(width: 14, height: 14)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Skin Calendar (Image 1)") {
    SkinCalendarView(showsTabBar: true)
}

#Preview("September 13 Log - Standard (Image 2)") {
    SkinLogView(
        entry: SkinLogEntry(
            dateString: "September 13",
            title: "September 13 Log",
            subtitle: "Track how your skin felt today.",
            mood: .calm,
            note: "Skin looked calm today. SPF layered well over vitamin C serum.",
            conditions: ["Low redness", "Routine complete", "SPF applied"],
            badgeText: "Good"
        ),
        backTitle: "Calendar",
        showsTabBar: true,
        showsValidationButton: false
    )
}

#Preview("September 13 Log - Validation (Image 3)") {
    SkinLogView(
        entry: SkinLogEntry(
            dateString: "September 13",
            title: "September 13 Log",
            subtitle: "Track how your skin felt today.",
            mood: .calm,
            note: "Skin looked calm today. SPF layered well over vitamin C serum.",
            conditions: ["Low redness", "Routine complete", "SPF applied"],
            badgeText: "Good"
        ),
        backTitle: "Journal",
        showsTabBar: true,
        showsValidationButton: true
    )
}

#Preview("Skin Journal (Image 4)") {
    SkinJournalView()
}
