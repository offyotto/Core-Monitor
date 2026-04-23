# App Startup And Lifecycle

Startup is controlled by `Core_MonitorApp.swift`, `WelcomeGuideProgress.swift`, `StartupManager.swift`, `DashboardShortcutManager.swift`, and `AppCoordinator.swift`.

The app must satisfy two conflicting goals: behave like a quiet menu bar utility for returning users, and show a visible dashboard/onboarding surface for first launch or explicit dashboard requests. The current delegate disables automatic termination, handles duplicate launches, purges deprecated defaults, determines welcome-guide presentation, installs global shortcuts/observers, creates menu bar items, and opens the dashboard if needed.

Activation policy matters. The app can be accessory-style for menu bar operation, but it must temporarily promote visibility when the dashboard is shown so the window does not vanish behind other apps or launch invisibly.

Shutdown is also functional: fan modes that Core-Monitor owns should be returned to system automatic best-effort before process exit. That cleanup is part of the trust model.
