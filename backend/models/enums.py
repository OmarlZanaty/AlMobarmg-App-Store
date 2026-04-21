import enum


class UserRole(str, enum.Enum):
    developer = "developer"
    user = "user"
    admin = "admin"


class SubscriptionPlan(str, enum.Enum):
    free = "free"
    pro = "pro"
    studio = "studio"


class AppStatus(str, enum.Enum):
    pending = "pending"
    scanning = "scanning"
    review = "review"
    approved = "approved"
    rejected = "rejected"
    removed = "removed"


class RiskLevel(str, enum.Enum):
    safe = "safe"
    low = "low"
    medium = "medium"
    high = "high"
    critical = "critical"


class Platform(str, enum.Enum):
    android = "android"
    ios = "ios"
    windows = "windows"
    mac = "mac"
    linux = "linux"
    web = "web"


class InstallSource(str, enum.Enum):
    store = "store"
    api = "api"
    direct = "direct"


class SubscriptionStatus(str, enum.Enum):
    active = "active"
    cancelled = "cancelled"
    past_due = "past_due"


class FixRejectionStatus(str, enum.Enum):
    pending_payment = "pending_payment"
    processing = "processing"
    completed = "completed"
    failed = "failed"
