from enum import Enum


# ==========================================================
# USER ROLES
# ==========================================================

class UserRole(str, Enum):
    ADMIN = "admin"
    OFFICER = "officer"
    LCR = "lcr"


# ==========================================================
# METER TYPES
# ==========================================================

class MeterType(str, Enum):
    DIGITAL = "digital"
    ELECTROMECHANICAL = "electromechanical"


# ==========================================================
# READING STATUS
# ==========================================================

class ReadingStatus(str, Enum):
    PENDING = "pending"
    COMPLETED = "completed"
    REVIEW = "review"
    REJECTED = "rejected"


# ==========================================================
# IMAGE QUALITY
# ==========================================================

class ImageQuality(str, Enum):
    OK = "ok"
    BLUR = "blur"
    REFLECTION = "reflection"
    IRRELEVANT = "irrelevant"


# ==========================================================
# OCR STATUS
# ==========================================================

class OCRStatus(str, Enum):
    SUCCESS = "success"
    FAILED = "failed"
    LOW_CONFIDENCE = "low_confidence"


# ==========================================================
# AI CLASSIFICATION
# ==========================================================

class AIClassification(str, Enum):

    IMAGE_OK_ELECTRO = "Image Okay Electro Mechanical Meter"

    BLUR_ELECTRO = "Blur Image Electro Mechanical Meter"

    BLUR_DIGITAL = "Blur Image Digital Meter"

    MISMATCH_ELECTRO = "Reading MisMatch Electro Mechanical Meter"

    MISMATCH_DIGITAL = "Reading Mis Match Digital Meter"

    REFLECTION_DIGITAL = "Reflection Digital Meter"

    IRRELEVANT_ELECTRO = "Irrelevant Image Electro Mechanical Meter"

    IRRELEVANT_DIGITAL = "Irrelevant Image Digital Meter"

    IMAGE_OK_DIGITAL = "Image Okay Digital Meter"


# ==========================================================
# LCR STATUS
# ==========================================================

class LCRStatus(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    REVISIT_REQUIRED = "revisit_required"


# ==========================================================
# ANOMALY STATUS
# ==========================================================

class AnomalyStatus(str, Enum):
    PENDING = "pending"
    RESOLVED = "resolved"


# ==========================================================
# SYNC STATUS
# ==========================================================

class SyncStatus(str, Enum):
    PENDING = "pending"
    SUCCESS = "success"
    FAILED = "failed"


# ==========================================================
# OCR SOURCE
# ==========================================================

class OCRSource(str, Enum):
    LOCAL = "local"
    SERVER = "server"


# ==========================================================
# AUDIT ACTION
# ==========================================================

class AuditAction(str, Enum):
    LOGIN = "login"
    LOGOUT = "logout"
    CREATE = "create"
    UPDATE = "update"
    DELETE = "delete"
    APPROVE = "approve"
    REJECT = "reject"
    SYNC = "sync"


# ==========================================================
# DEVICE TYPE
# ==========================================================

class DeviceType(str, Enum):
    MOBILE = "mobile"
    DASHBOARD = "dashboard"


# ==========================================================
# NETWORK STATUS
# ==========================================================

class NetworkStatus(str, Enum):
    ONLINE = "online"
    OFFLINE = "offline"

class SortOrder(str, Enum):
    ASC = "asc"
    DESC = "desc"

class NotificationType(str, Enum):
    ASSIGNMENT = "assignment"
    ANOMALY = "anomaly"
    LCR = "lcr"
    SYNC = "sync"
    SYSTEM = "system"
