# Legacy Alerts

Alert models, evaluation, and manager code remain in the repository, but the old Alerts screen surface was removed. That makes the current alert stack legacy or dormant, not a primary product surface.

`AlertEngine.swift`, `AlertModels.swift`, and `AlertManager.swift` still matter because tests and helper/service status concepts reference alert-style evaluation. However, current architecture docs warn not to extend this path unless alerts are intentionally reintroduced.

Removed alert UI files are documented in the Removed Parts section.
