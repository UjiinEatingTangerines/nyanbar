import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case japanese = "ja"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .korean: "한국어"
        case .japanese: "日本語"
        case .english: "English"
        }
    }

    var flag: String {
        switch self {
        case .korean: "🇰🇷"
        case .japanese: "🇯🇵"
        case .english: "🇺🇸"
        }
    }

    // MARK: - Tab Titles

    var sessionsTab: String {
        switch self { case .korean: "세션"; case .japanese: "セッション"; case .english: "Sessions" }
    }
    var historyTab: String {
        switch self { case .korean: "히스토리"; case .japanese: "履歴"; case .english: "History" }
    }
    var settingsTab: String {
        switch self { case .korean: "설정"; case .japanese: "設定"; case .english: "Settings" }
    }

    // MARK: - Session Dashboard

    var noActiveSessions: String {
        switch self { case .korean: "활성 세션 없음"; case .japanese: "アクティブセッションなし"; case .english: "No active sessions" }
    }
    var startSessionHint: String {
        switch self { case .korean: "Claude Code 세션을 시작하면\n여기에 표시됩니다"; case .japanese: "Claude Codeセッションを開始すると\nここに表示されます"; case .english: "Start a Claude Code session\nto see it here" }
    }
    var workingGroup: String {
        switch self { case .korean: "작업 중"; case .japanese: "作業中"; case .english: "Working" }
    }
    var waitingGroup: String {
        switch self { case .korean: "입력 대기"; case .japanese: "入力待ち"; case .english: "Waiting for Input" }
    }
    var completedGroup: String {
        switch self { case .korean: "완료"; case .japanese: "完了"; case .english: "Completed" }
    }
    var idleGroup: String {
        switch self { case .korean: "유휴"; case .japanese: "アイドル"; case .english: "Idle" }
    }
    var crashedGroup: String {
        switch self { case .korean: "충돌"; case .japanese: "クラッシュ"; case .english: "Crashed" }
    }

    // MARK: - History

    var noHistory: String {
        switch self { case .korean: "히스토리 없음"; case .japanese: "履歴なし"; case .english: "No history yet" }
    }
    var historyHint: String {
        switch self { case .korean: "완료된 세션이\n여기에 표시됩니다"; case .japanese: "完了したセッションが\nここに表示されます"; case .english: "Completed sessions will\nappear here" }
    }
    var autoDeleteNote: String {
        switch self { case .korean: "24시간 후 자동 삭제"; case .japanese: "24時間後に自動削除"; case .english: "Auto-deleted after 24h" }
    }
    var clearAll: String {
        switch self { case .korean: "전체 삭제"; case .japanese: "すべて削除"; case .english: "Clear All" }
    }

    // MARK: - Settings

    var languageTitle: String { "Language" }
    var healthCheckSectionTitle: String { "Health Check" }
    var healthCheckDesc: String {
        switch self { case .korean: "세션이 살아있는지 확인하는 주기"; case .japanese: "セッションの生存確認間隔"; case .english: "How often to check if sessions are still alive" }
    }
    var aboutTitle: String { "About" }

    var sleepModeTitle: String {
        switch self { case .korean: "수면 모드"; case .japanese: "スリープモード"; case .english: "Sleep Mode" }
    }
    var sleepModeDesc: String {
        switch self { case .korean: "고양이가 자는 동안 알림을 받지 않아요"; case .japanese: "猫が寝ている間は通知を受けません"; case .english: "No notifications while cat is sleeping" }
    }
    var soundTitle: String {
        switch self { case .korean: "완료 사운드"; case .japanese: "完了サウンド"; case .english: "Completion Sound" }
    }
    var soundDesc: String {
        switch self { case .korean: "작업 완료 시 소리로 알려줘요"; case .japanese: "タスク完了時にサウンドで通知"; case .english: "Play sound when task completes" }
    }
    var customSpinnerTitle: String {
        switch self { case .korean: "커스텀 문구"; case .japanese: "カスタムメッセージ"; case .english: "Custom Messages" }
    }
    var customSpinnerDesc: String {
        switch self { case .korean: "나만의 스피너 문구를 추가해요"; case .japanese: "オリジナルのスピナーメッセージを追加"; case .english: "Add your own spinner messages" }
    }
    var addMessage: String {
        switch self { case .korean: "추가"; case .japanese: "追加"; case .english: "Add" }
    }
    var appearanceTitle: String {
        switch self { case .korean: "화면 모드"; case .japanese: "外観モード"; case .english: "Appearance" }
    }
    var catColorTitle: String {
        switch self { case .korean: "고양이 색상"; case .japanese: "猫の色"; case .english: "Cat Color" }
    }
    var catColorReset: String {
        switch self { case .korean: "초기화"; case .japanese: "リセット"; case .english: "Reset" }
    }
    var catColorSystemDesc: String {
        switch self { case .korean: "시스템 설정에 따라 자동 변경"; case .japanese: "システム設定に合わせて自動変更"; case .english: "Auto-adapts to system theme" }
    }

    // MARK: - UI Strings

    var healthCheckTitle: String {
        switch self {
        case .korean: "✅ 헬스체크 완료"
        case .japanese: "✅ ヘルスチェック完了"
        case .english: "✅ health check"
        }
    }

    var pendingPrefix: String {
        switch self {
        case .korean: "🙋 입력 대기"
        case .japanese: "🙋 入力待ち"
        case .english: "🙋 input needed"
        }
    }

    var doneText: String {
        switch self {
        case .korean: "done!"
        case .japanese: "完了!"
        case .english: "done!"
        }
    }

    var waitingForInput: String {
        switch self {
        case .korean: "🙋 입력 대기 중"
        case .japanese: "🙋 入力待ち"
        case .english: "🙋 waiting for input"
        }
    }

    // MARK: - Spinner Messages (30 each)

    var spinnerMessages: [String] {
        switch self {
        case .korean: Self.koreanMessages
        case .japanese: Self.japaneseMessages
        case .english: Self.englishMessages
        }
    }

    private static let koreanMessages: [String] = [
        "🍞 빵 굽는 중..",
        "🐾 꾹꾹이 하는 중..",
        "😴 골골골..",
        "👊 냥냥펀치 충전 중",
        "🐟 츄르 대기 중..",
        "📦 박스 탐색 중..",
        "✨ 그루밍 타임..",
        "💤 낮잠 모드..",
        "👀 집사 감시 중..",
        "🐾 발바닥 젤리..",
        "🌿 캣닢 충전 완료",
        "🐦 창밖 새 관찰 중",
        "🛌 이불 점령 완료",
        "⌨️ 키보드 점령 준비",
        "💅 도도함 유지 중..",
        "☀️ 햇살 충전 중..",
        "💧 고양이는 액체..",
        "🔴 레이저 추적 중!",
        "⬆️ 높은 곳 탐색 중",
        "💕 심장 도둑 활동중",
        "😾 야옹 안 할거다냥",
        "🐱 나 지금 삐졌다냥",
        "🏃 3초후 미친듯이 뜀",
        "🙄 집사 꼴보기 싫다냥",
        "😏 츄르없으면 대화끝",
        "👂 비닐봉지 바스락!",
        "🤨 왜 쳐다보는 거냥",
        "😼 내가 제일 귀여움",
        "🐈 꼬리는 기분탓이냥",
        "😸 집사 교육 95%",
    ]

    private static let japaneseMessages: [String] = [
        "🍞 食パン焼き中..",
        "🐾 ふみふみ中..",
        "😴 ゴロゴロ..",
        "👊 猫パンチ充電中",
        "🐟 ちゅーる待機中..",
        "📦 箱探索中..",
        "✨ グルーミング中..",
        "💤 お昼寝モード..",
        "👀 下僕を監視中..",
        "🐾 肉球ぷにぷに..",
        "🌿 またたび充電完了",
        "🐦 窓の外の鳥観察中",
        "🛌 布団占領完了",
        "⌨️ キーボード占領準備",
        "💅 ツンデレ維持中..",
        "☀️ 日向ぼっこ中..",
        "💧 猫は液体..",
        "🔴 レーザー追跡中!",
        "⬆️ 高い場所探索中",
        "💕 ハート泥棒活動中",
        "😾 にゃーしないもん",
        "🐱 今すねてるにゃ",
        "🏃 3秒後に全力疾走",
        "🙄 下僕の顔見たくない",
        "😏 ちゅーる無しなら話終わり",
        "👂 ビニール袋発見!",
        "🤨 なに見てるにゃ",
        "😼 世界で一番かわいい",
        "🐈 しっぽは気のせいにゃ",
        "😸 下僕の教育 95%",
    ]

    private static let englishMessages: [String] = [
        "🍞 Baking bread..",
        "🐾 Making biscuits..",
        "😴 Purring away..",
        "👊 Charging cat slap",
        "🐟 Waiting for treats..",
        "📦 Exploring boxes..",
        "✨ Grooming time..",
        "💤 Nap mode..",
        "👀 Watching hooman..",
        "🐾 Toe bean check..",
        "🌿 Catnip charged",
        "🐦 Bird watching..",
        "🛌 Bed conquered",
        "⌨️ Keyboard takeover",
        "💅 Being fabulous..",
        "☀️ Sunbathing..",
        "💧 Cat is liquid..",
        "🔴 Chasing laser!",
        "⬆️ Seeking high ground",
        "💕 Stealing hearts",
        "😾 Not meowing today",
        "🐱 Currently offended",
        "🏃 Zoomies in 3..2..",
        "🙄 Don't look at me",
        "😏 No treats no talk",
        "👂 Plastic bag detected!",
        "🤨 Why are you staring",
        "😼 I'm the cutest",
        "🐈 Tail? What tail?",
        "😸 Hooman training 95%",
    ]
}
